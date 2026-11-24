$ErrorActionPreference = 'Stop'

$python = Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1
$duckdb = Get-Command duckdb -CommandType Application -ErrorAction Stop | Select-Object -First 1

$requiredFiles = @(
    'THOR_Vietnam_Bombing_Operations.parquet',
    'THOR_Vietnam_Weapons_Glossary.csv',
    'THOR_Vietnam_Aircraft_Glossary.csv',
    'scripts\reverse_geocode.py',
    'sql\thor_etl.sql',
    'sql\thor_modelupdate.sql',
    'scripts\predict_hochiminhtrail.py',
    'THOR-31 - Nearest neighbour.ipynb'
)
foreach ($file in $requiredFiles) {
    $path = Join-Path $PSScriptRoot $file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required file not found: $path"
    }
}

Push-Location $PSScriptRoot
try {
    Write-Host 'Reverse-geocoding source data...'
    & $python.Source (Join-Path $PSScriptRoot 'scripts\reverse_geocode.py')
    if ($LASTEXITCODE -ne 0) {
        throw "Reverse geocoding failed with exit code $LASTEXITCODE."
    }

    Write-Host 'Running DuckDB ETL...'
    Get-Content -LiteralPath (Join-Path $PSScriptRoot 'sql\thor_etl.sql') |
        & $duckdb.Source -bail
    if ($LASTEXITCODE -ne 0) {
        throw "DuckDB ETL failed with exit code $LASTEXITCODE."
    }

    $modelDirectory = Join-Path $PSScriptRoot 'model'
    $modelPath = Join-Path $modelDirectory 'hochiminhtrail-imint-knn.joblib'
    New-Item -ItemType Directory -Path $modelDirectory -Force | Out-Null
    $previousModelTime = $null
    if (Test-Path -LiteralPath $modelPath -PathType Leaf) {
        $previousModelTime = (Get-Item -LiteralPath $modelPath).LastWriteTimeUtc
    }

    Write-Host 'Training and exporting the IMINT model...'
    & $python.Source -m jupyter nbconvert --to notebook --execute --stdout `
        --ExecutePreprocessor.timeout=-1 --ExecutePreprocessor.kernel_name=python3 `
        (Join-Path $PSScriptRoot 'THOR-31 - Nearest neighbour.ipynb') | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Notebook execution failed with exit code $LASTEXITCODE."
    }
    if (-not (Test-Path -LiteralPath $modelPath -PathType Leaf)) {
        throw "Notebook did not export the model: $modelPath"
    }
    if ($null -ne $previousModelTime -and
        (Get-Item -LiteralPath $modelPath).LastWriteTimeUtc -eq $previousModelTime) {
        throw "Notebook did not update the model: $modelPath"
    }

    Write-Host 'Predicting IMINT operation labels...'
    & $python.Source (Join-Path $PSScriptRoot 'scripts\predict_hochiminhtrail.py')
    if ($LASTEXITCODE -ne 0) {
        throw "IMINT prediction failed with exit code $LASTEXITCODE."
    }

    Write-Host 'Updating analysis data with predictions...'
    Get-Content -LiteralPath (Join-Path $PSScriptRoot 'sql\thor_modelupdate.sql') |
        & $duckdb.Source -bail
    if ($LASTEXITCODE -ne 0) {
        throw "Analysis prediction update failed with exit code $LASTEXITCODE."
    }

    Write-Host 'Build complete.'
}
finally {
    Pop-Location
}

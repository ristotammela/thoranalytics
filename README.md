# thoranalytics
Cleansing THOR Vietnam dataset, feature extraction and data analytics

Data manipulation is carried out by DuckDB.
Data analytics are carried out by Python.

# Prerequisites

## Python environment

Create and activate a virtual environment from the repository root in PowerShell:

```powershell
python -m venv .venv --prompt THOR
.\.venv\Scripts\Activate.ps1
```

Install the project dependencies:

```powershell
python -m pip install -r requirements.txt
```

When finished, deactivate the virtual environment with:

```powershell
deactivate
```

## DuckDB command-line tool

Install the DuckDB CLI with Windows Package Manager (`winget`) in PowerShell:

```powershell
winget install --id DuckDB.cli --exact
```

Open a new PowerShell window, then verify the installation:

```powershell
duckdb --version
```

# Operating instructions

## Running the ETL

```powershell
Get-Content .\sql\thor_etl.sql | duckdb
```

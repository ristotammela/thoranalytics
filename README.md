# thoranalytics
Cleansing THOR Vietnam dataset, feature extraction and data analytics.


# Dataflow

Data manipulation is carried out by DuckDB.
Data analytics are carried out by Python.
Data visualizations in PowerBI.
Excel can be used for random spreadsheet modeling.


```mermaid
flowchart LR
    original("Original csv <br/> generates parquet using makeparquet.py")
    raw["THOR_Vietnam_Bombing_Operations.parquet"]
    glossary["THOR_Vietnam_Weapons_Glossary.csv"]
    etl["DuckDB ETL<br/> using thor_etl.sql"]
    output["Wrangled data in <br/>THOR_Analysis.parquet"]
    powerbi["Visualization in <br/>Power BI"]
    model["Models built in <br/>Python <br/> using Jupyter"]
    spreadsheet["Spreadsheet in <br/> Excel"]

    original --> raw
    raw --> etl
    glossary --> etl
    etl --> output
    output --> powerbi
    output --> model
    output--> spreadsheet

```

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

## Updating the Power BI Parquet path

If you move or clone the repository to a different location, update the Power BI
`PathParquet` parameter to point to this repository's `THOR_Analysis.parquet`:

```powershell
python .\scripts\update_pbi_parquet_path.py
```

## Running Jupyter notebooks

Jupyter notebooks contain data analytics.  You can run them on your favorite
editor.  Project prefers VS Code extension.


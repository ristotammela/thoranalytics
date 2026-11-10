## Helper script to convert the THOR CSV file to Parquet format

from pathlib import Path

import pandas as pd


INPUT_CSV = Path(
    r"C:\TEMP\THOR_Vietnam_Bombing_Operations.csv"
)
OUTPUT_PARQUET = INPUT_CSV.with_suffix(".parquet")


def main() -> None:
    df = pd.read_csv(INPUT_CSV, low_memory=False)
    df.to_parquet(OUTPUT_PARQUET, index=False)
    print(f"Saved {len(df):,} rows to {OUTPUT_PARQUET}")


if __name__ == "__main__":
    main()
"""Add nearest populated places to THOR target coordinates in a new Parquet file."""

import argparse
import os
import tempfile
from pathlib import Path

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import reverse_geocoder as rg


ROOT = Path(__file__).resolve().parent.parent
LATITUDE = "TGTLATDD_DDD_WGS84"
LONGITUDE = "TGTLONDDD_DDD_WGS84"
RESULT_COLUMNS = {
    "name": "GEOCODE_NAME",
    "admin1": "GEOCODE_ADMIN1",
    "admin2": "GEOCODE_ADMIN2",
    "cc": "GEOCODE_COUNTRY_CODE",
}
BATCH_SIZE = 100_000


def geocode_batch(batch: pa.RecordBatch) -> pa.Table:
    coordinates = batch.select([LATITUDE, LONGITUDE]).to_pandas()
    valid = (
        coordinates[LATITUDE].between(-90, 90)
        & coordinates[LONGITUDE].between(-180, 180)
    )
    output = pd.DataFrame(
        None, index=coordinates.index, columns=list(RESULT_COLUMNS.values())
    )
    if valid.any():
        codes, unique_coordinates = pd.factorize(
            pd.MultiIndex.from_frame(coordinates.loc[valid])
        )
        results = rg.search(unique_coordinates.tolist(), mode=1)
        matches = pd.DataFrame(results).rename(columns=RESULT_COLUMNS)
        output.loc[valid, :] = matches.iloc[codes][list(RESULT_COLUMNS.values())].to_numpy()

    table = pa.Table.from_batches([batch])
    for column in RESULT_COLUMNS.values():
        table = table.append_column(column, pa.array(output[column], type=pa.string()))
    return table


def geocode_parquet(input_path: Path, output_path: Path) -> None:
    if input_path.resolve() == output_path.resolve() or (
        output_path.exists() and os.path.samefile(input_path, output_path)
    ):
        raise ValueError("Input and output must be different files")

    source = pq.ParquetFile(input_path)
    schema = source.schema_arrow
    missing = {LATITUDE, LONGITUDE} - set(schema.names)
    if missing:
        raise ValueError(f"Missing coordinate columns: {', '.join(sorted(missing))}")
    existing = set(RESULT_COLUMNS.values()) & set(schema.names)
    if existing:
        raise ValueError(f"Output columns already exist: {', '.join(sorted(existing))}")
    for column in RESULT_COLUMNS.values():
        schema = schema.append(pa.field(column, pa.string()))

    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(
            suffix=".parquet", dir=output_path.parent, delete=False
        ) as temporary:
            temporary_path = Path(temporary.name)
        count = 0
        with pq.ParquetWriter(temporary_path, schema) as writer:
            for batch in source.iter_batches(batch_size=BATCH_SIZE):
                writer.write_table(geocode_batch(batch))
                count += batch.num_rows
        os.replace(temporary_path, output_path)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)
    print(f"Saved {count:,} rows to {output_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input", type=Path, default=ROOT / "THOR_Vietnam_Bombing_Operations.parquet"
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "THOR_Vietnam_Bombing_Operations_geocoded.parquet",
    )
    args = parser.parse_args()
    geocode_parquet(args.input, args.output)


if __name__ == "__main__":
    main()

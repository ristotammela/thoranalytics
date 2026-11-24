"""Predict Ho Chi Minh Trail operation labels for IMINT observations."""

import argparse
import os
import tempfile
from pathlib import Path

import joblib
import pandas as pd


ROOT = Path(__file__).resolve().parent.parent
KEY = "THOR_DATA_VIET_ID"
FEATURES = ["missiondate_day", "TGTLATDD_DDD_WGS84", "TGTLONDDD_DDD_WGS84"]
PREDICTION = "predicted_ishochiminhtrailoperation"


def predict(input_path: Path, model_path: Path, output_path: Path) -> None:
    for source in (input_path, model_path):
        if source.resolve() == output_path.resolve() or (
            output_path.exists() and os.path.samefile(source, output_path)
        ):
            raise ValueError(f"Output must not overwrite input: {source}")

    data = pd.read_parquet(
        input_path, columns=[KEY, *FEATURES], filters=[("IMINT", "=", True)]
    )
    missing = data[[KEY, *FEATURES]].isna().sum()
    if missing.any():
        raise ValueError(f"IMINT rows have missing required values:\n{missing[missing > 0]}")

    model = joblib.load(model_path)
    results = data[[KEY]].copy()
    if not data.empty:
        results[PREDICTION] = model.predict(data[FEATURES])
    else:
        results[PREDICTION] = pd.Series(dtype="int64")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(
            suffix=".csv", dir=output_path.parent, delete=False
        ) as temporary:
            temporary_path = Path(temporary.name)
        results.to_csv(temporary_path, index=False)
        os.replace(temporary_path, output_path)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)
    print(f"Saved {len(results):,} IMINT predictions to {output_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=ROOT / "THOR_Analysis.parquet")
    parser.add_argument(
        "--model", type=Path, default=ROOT / "model" / "hochiminhtrail-imint-knn.joblib"
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "predictions" / "THOR_IMINT_hochiminhtrail_predictions.csv",
    )
    args = parser.parse_args()
    predict(args.input, args.model, args.output)


if __name__ == "__main__":
    main()

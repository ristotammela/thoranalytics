"""Tests for exporting IMINT model predictions."""

import tempfile
import unittest
from pathlib import Path

import joblib
import pandas as pd
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

import predict_hochiminhtrail


class PredictionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.source = self.root / "source.parquet"
        self.output = self.root / "predictions.csv"
        self.model = self.root / "model.joblib"
        training = pd.DataFrame(
            [[0, 10.0, 100.0], [100, 20.0, 110.0]],
            columns=predict_hochiminhtrail.FEATURES,
        )
        model = make_pipeline(StandardScaler(), KNeighborsClassifier(n_neighbors=1))
        model.fit(training, [0, 1])
        joblib.dump(model, self.model)

    def test_predicts_only_imint_rows_and_preserves_keys(self) -> None:
        self.output = self.root / "predictions" / "predictions.csv"
        pd.DataFrame(
            {
                "THOR_DATA_VIET_ID": [101, 102, 103],
                "IMINT": [True, False, True],
                "missiondate_day": [0, 0, 100],
                "TGTLATDD_DDD_WGS84": [10.0, 10.0, 20.0],
                "TGTLONDDD_DDD_WGS84": [100.0, 100.0, 110.0],
            }
        ).to_parquet(self.source, index=False)
        predict_hochiminhtrail.predict(self.source, self.model, self.output)
        actual = pd.read_csv(self.output)
        self.assertEqual(list(actual.columns), ["THOR_DATA_VIET_ID", predict_hochiminhtrail.PREDICTION])
        self.assertEqual(actual["THOR_DATA_VIET_ID"].tolist(), [101, 103])
        self.assertEqual(actual[predict_hochiminhtrail.PREDICTION].tolist(), [0, 1])

    def test_missing_features_fail_without_replacing_output(self) -> None:
        pd.DataFrame(
            {
                "THOR_DATA_VIET_ID": [101],
                "IMINT": [True],
                "missiondate_day": [None],
                "TGTLATDD_DDD_WGS84": [10.0],
                "TGTLONDDD_DDD_WGS84": [100.0],
            }
        ).to_parquet(self.source, index=False)
        self.output.write_text("existing output", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "missiondate_day"):
            predict_hochiminhtrail.predict(self.source, self.model, self.output)
        self.assertEqual(self.output.read_text(encoding="utf-8"), "existing output")

    def test_empty_imint_and_input_overwrite(self) -> None:
        pd.DataFrame(
            {
                "THOR_DATA_VIET_ID": [101],
                "IMINT": [False],
                "missiondate_day": [0],
                "TGTLATDD_DDD_WGS84": [10.0],
                "TGTLONDDD_DDD_WGS84": [100.0],
            }
        ).to_parquet(self.source, index=False)
        predict_hochiminhtrail.predict(self.source, self.model, self.output)
        actual = pd.read_csv(self.output)
        self.assertTrue(actual.empty)
        self.assertEqual(list(actual.columns), ["THOR_DATA_VIET_ID", predict_hochiminhtrail.PREDICTION])
        with self.assertRaisesRegex(ValueError, "must not overwrite"):
            predict_hochiminhtrail.predict(self.source, self.model, self.source)


if __name__ == "__main__":
    unittest.main()

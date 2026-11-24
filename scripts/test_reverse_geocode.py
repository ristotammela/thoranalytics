"""Focused tests for reverse geocoding the THOR Parquet data."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import pyarrow as pa
import pyarrow.parquet as pq

import reverse_geocode


class ReverseGeocodeTests(unittest.TestCase):
    def test_geocodes_valid_rows_and_preserves_invalid_rows(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.parquet"
            output = Path(directory) / "output.parquet"
            original = pa.table(
                {
                    "id": [1, 2, 3, 4, 5, 6],
                    reverse_geocode.LATITUDE: [21.0245, None, 91.0, 21.0245, 0.0, 21.0245],
                    reverse_geocode.LONGITUDE: [105.8412, 105.0, 105.0, 105.8412, 181.0, float("inf")],
                }
            )
            pq.write_table(original, source)
            with patch.object(reverse_geocode, "BATCH_SIZE", 2):
                reverse_geocode.geocode_parquet(source, output)

            actual = pq.read_table(output)
            self.assertTrue(actual.select(original.column_names).equals(original))
            self.assertEqual(
                actual["GEOCODE_NAME"].to_pylist(),
                ["Hanoi", None, None, "Hanoi", None, None],
            )
            self.assertEqual(
                actual["GEOCODE_COUNTRY_CODE"].to_pylist(),
                ["VN", None, None, "VN", None, None],
            )
            self.assertTrue(pq.read_table(source).equals(original))

    def test_refuses_to_overwrite_input_and_rejects_missing_columns(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.parquet"
            pq.write_table(pa.table({"id": [1]}), source)
            with self.assertRaisesRegex(ValueError, "different files"):
                reverse_geocode.geocode_parquet(source, source)
            with self.assertRaisesRegex(ValueError, "Missing coordinate columns"):
                reverse_geocode.geocode_parquet(source, Path(directory) / "output.parquet")
            self.assertEqual(pq.read_table(source)["id"].to_pylist(), [1])

    def test_empty_input_produces_empty_output_with_geocoding_columns(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.parquet"
            output = Path(directory) / "output.parquet"
            pq.write_table(
                pa.table(
                    {
                        reverse_geocode.LATITUDE: pa.array([], type=pa.float64()),
                        reverse_geocode.LONGITUDE: pa.array([], type=pa.float64()),
                    }
                ),
                source,
            )
            reverse_geocode.geocode_parquet(source, output)
            actual = pq.read_table(output)
            self.assertEqual(actual.num_rows, 0)
            self.assertIn("GEOCODE_NAME", actual.column_names)


if __name__ == "__main__":
    unittest.main()

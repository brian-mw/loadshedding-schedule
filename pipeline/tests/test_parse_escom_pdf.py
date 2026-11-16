import csv
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import parse_escom_pdf


ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "data"


class ParserRegressionTests(unittest.TestCase):
    def test_parse_header_date_ignores_trailing_forecast_notice(self) -> None:
        self.assertEqual(
            parse_escom_pdf.parse_header_date_to_iso(
                "Saturday, 21 November 2026 forecasts, random fluctuations in intensity of sunshine may affect solar power"
            ),
            "2026-11-21",
        )

    def test_outputs_match_all_checked_in_pdfs(self) -> None:
        week_dirs = sorted(path.parent for path in DATA_DIR.glob("*/source.pdf"))
        self.assertTrue(week_dirs, "no checked-in source PDFs found")

        for week_dir in week_dirs:
            with self.subTest(week=week_dir.name):
                with parse_escom_pdf.fitz.open(week_dir / "source.pdf") as doc:
                    metadata = parse_escom_pdf.extract_metadata(doc)
                    schedule = parse_escom_pdf.extract_schedule(doc)
                    windows = parse_escom_pdf.derive_power_windows(schedule)
                    locations = parse_escom_pdf.extract_locations(doc)

                with (week_dir / "metadata.json").open() as file:
                    self.assertEqual(metadata.model_dump(), json.load(file))

                for filename, rows in (
                    ("schedule_cells.csv", schedule),
                    ("power_windows.csv", windows),
                    ("locations.csv", locations),
                ):
                    with (week_dir / filename).open(newline="") as file:
                        expected = list(csv.DictReader(file))
                    actual = [
                        {
                            key: "" if value is None else str(value)
                            for key, value in row.model_dump(mode="json").items()
                        }
                        for row in rows
                    ]
                    self.assertEqual(actual, expected, filename)


if __name__ == "__main__":
    unittest.main()

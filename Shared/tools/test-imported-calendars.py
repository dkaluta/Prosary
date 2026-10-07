#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["requests"]
# ///
"""Check source-bounded calendars, imported citation choices and native data parity.

No network or source PDF is needed: the reviewed, hash-pinned snapshots are inputs.
"""
from __future__ import annotations

import datetime as dt
import importlib.util
import json
from pathlib import Path
import sys
import unittest
import tempfile
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parents[1]
DATA = ROOT / "Shared/data"
sys.path.insert(0, str(TOOLS))


def module(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, TOOLS / filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


IMPORTER = module("stjames_import_test", "import-stjames-calendar.py")
READINGS = module("calendar_readings_test", "fetch-readings.py")


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def dates(start: str, end: str) -> list[str]:
    first, last = dt.date.fromisoformat(start), dt.date.fromisoformat(end)
    return [(first + dt.timedelta(days=i)).isoformat() for i in range((last - first).days + 1)]


class ImportedCalendarTests(unittest.TestCase):
    def test_feast_only_calendars_do_not_borrow_a_readings_table_during_localization(self):
        with tempfile.TemporaryDirectory() as directory:
            data = Path(directory)
            (data / "calendars.json").write_text(json.dumps({"calendars": [
                {"id": "roman", "readingsFile": "readings-roman"},
                {"id": "mission-provisional", "file": "feasts-mission-provisional"},
                {"id": "no-reading-table", "readingsFile": None},
                {"id": "ugcc", "readingsFile": "readings-ugcc", "paschaVariants": {
                    "feasts-only": {}, "gregorian": {"readingsFile": "readings-ugcc-gregorian"}}},
            ]}))
            with patch.object(READINGS, "DATA", data):
                self.assertEqual([path.name for path in READINGS.citation_dataset_paths()],
                                 ["readings-roman.json", "readings-ugcc.json", "readings-ugcc-gregorian.json"])

    @classmethod
    def setUpClass(cls):
        cls.source = load(IMPORTER.SNAPSHOT)
        cls.feasts = load(DATA / "feasts-stjames.json")
        cls.readings = load(DATA / "readings-stjames.json")

    def appointment(self, day: str) -> list[dict]:
        return self.readings["days"][day]["readings"]

    def parse(self, text: str) -> list[dict]:
        return IMPORTER.appointments(text, READINGS)

    def test_stjames_exact_source_coverage_and_hash(self):
        expected = dates("2026-10-04", "2027-10-24")
        self.assertEqual(list(self.source["days"]), expected)
        self.assertEqual(list(self.readings["days"]), expected)
        self.assertEqual(self.source["sha256"], "b7d2eabf9181913379c2de2f5279bd9a8ad9ed3f9804089c38fc6ea59de45960")
        self.assertEqual(self.readings["sourceSha256"], self.source["sha256"])
        self.assertEqual(self.feasts["sourceSha256"], self.source["sha256"])
        self.assertEqual(sorted({row["pdfPage"] for row in self.source["days"].values()}), list(range(3, 59)))
        self.assertEqual(len(self.feasts["days"]), 196)
        self.assertEqual(sum(len(row["readings"]) for row in self.readings["days"].values()), 1290)

    def test_each_citation_retains_a_printed_span_and_parser_output(self):
        for day, row in self.source["days"].items():
            with self.subTest(day=day):
                parsed = self.parse(row["english"])
                shipped = self.appointment(day)
                self.assertEqual([(r["full"], r.get("sourceGroup"), r["sourceText"]) for r in shipped],
                                 [(r["full"], r.get("sourceGroup"), r["sourceText"]) for r in parsed])
                for citation in shipped:
                    self.assertEqual(set(citation.get("fullByLanguage", {})), {"he", "ar", "ru", "tl", "fr", "it", "uk"})
                    self.assertIn(citation["sourceText"], row["english"])
                self.assertTrue(any(r["type"] == "gospel" for r in shipped))

    def test_source_defined_book_aliases_and_compact_numbered_books(self):
        self.assertEqual(self.appointment("2026-11-09")[1]["full"], "1 Corinthians 3:9–11,16–17")
        self.assertEqual(self.appointment("2026-11-09")[1]["sourceText"], "1Cor 3:9-11.16-17")
        self.assertEqual([r["full"] for r in self.appointment("2026-12-21")[:2]],
                         ["Song of Songs 2:8–14", "Zephaniah 3:14–18"])
        self.assertEqual(self.appointment("2027-05-31")[0]["full"], "Zephaniah 3:14–18")
        for source, full in [("Nm 6:22-27", "Numbers 6:22–27"), ("Jgs 5:1-3", "Judges 5:1–3"),
                             ("Ru 2:1-3", "Ruth 2:1–3"), ("Zec 3:1-4", "Zechariah 3:1–4"),
                             ("Hbr 1:1-6", "Hebrews 1:1–6")]:
            self.assertEqual(self.parse(source + "; Jn 1:1-2")[0]["full"], full)

    def test_single_chapter_books_chapter_only_psalms_and_inherited_choice(self):
        self.assertEqual(self.appointment("2026-11-12")[0]["full"], "Philemon 1:7–20")
        self.assertEqual(self.appointment("2026-11-14")[0]["full"], "3 John 1:5–8")
        self.assertEqual(self.parse("Jude 17-25; Ps 117; Jn 1:1-2")[0]["full"], "Jude 1:17–25")
        self.assertEqual(self.parse("Jude 17-25; Ps 117; Jn 1:1-2")[1]["full"], "Psalm 117")
        self.assertEqual([r["full"] for r in self.appointment("2027-09-08")[-2:]],
                         ["Matthew 1:1–23", "Matthew 1:18–23"])
        self.assertEqual(self.appointment("2027-09-08")[-1]["sourceGroup"], "or")
        self.assertEqual(self.appointment("2027-09-07")[1]["full"], "Psalm 145:1–2,8–11")
        self.assertIn("8--11", self.appointment("2027-09-07")[1]["sourceText"])
        self.assertEqual(self.appointment("2027-06-13")[2]["full"], "2 Corinthians 5:6–10")
        self.assertEqual(self.appointment("2027-08-06")[0]["full"], "Daniel 7:9–10,13–14")
        for day in ["2027-01-25", "2027-04-16", "2027-07-03"]:
            psalm = next(r for r in self.appointment(day) if r["full"] == "Psalm 117")
            self.assertEqual(psalm["fullByLanguage"]["he"], "תהלים קי״ז")

    def test_unknown_or_partially_consumed_references_fail_closed(self):
        for text in ["Unknown 1:2; Jn 1:1-2", "Unknown 117; Jn 1:1-2", "Is 1:2-; Jn 1:1-2",
                     "Is 1:2; or 2:3; Jn 1:1-2; Bad 4:5"]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                self.parse(text)

    def test_christmas_and_holy_week_keep_printed_mass_and_choice_groups(self):
        christmas = self.appointment("2026-12-25")
        self.assertEqual(len(christmas), 16)
        self.assertEqual([christmas[i]["sourceGroup"] for i in [0, 4, 8, 12]], [
            "Solemnity of the Nativity of the Lord (Vigil Mass)",
            "Solemnity of the Nativity of the Lord (Mass During the Night)",
            "Solemnity of the Nativity of the Lord (Mass at Dawn)",
            "Solemnity of the Nativity of the Lord (Mass in the Evening)"])
        thursday = self.appointment("2027-03-25")
        self.assertEqual(len(thursday), 8)
        self.assertEqual(thursday[0]["sourceGroup"], "Holy Thursday Chrism Mass")
        self.assertEqual(thursday[4]["sourceGroup"], "Holy Thursday of the Lord’s Supper")
        self.assertEqual(len(self.appointment("2027-03-27")), 10)
        easter = self.appointment("2027-03-28")
        self.assertEqual(len(easter), 11)
        self.assertEqual(easter[3]["full"], "1 Corinthians 5:6–8")
        self.assertEqual(easter[3]["sourceGroup"], "or")
        self.assertIn("Evening", easter[-1]["sourceGroup"])
        self.assertEqual(self.appointment("2026-10-04")[-1]["sourceGroup"], "Additional reading of the Great Advent (Year B)")

    def test_bilingual_optional_memorials_retain_exact_source_alignment(self):
        count = 0
        for day, row in self.source["days"].items():
            expected = [r for r in IMPORTER.titles(row) if r[2] == "Optional Memorial"]
            actual = [r for r in self.feasts["days"].get(day, {}).get("observances", [])
                      if r.get("rank") == "Optional Memorial"]
            with self.subTest(day=day):
                self.assertEqual([(r["title"], r["titleByLanguage"]["he"]) for r in actual],
                                 [(english, hebrew) for english, hebrew, _ in expected])
                self.assertTrue(all(hebrew and hebrew in row["hebrew"].replace("\n", " ")
                                    for _, hebrew, _ in expected))
            count += len(actual)
        self.assertEqual(count, 60)
        self.assertIn("First Sunday of Advent (Year B)", self.feasts["days"]["2026-10-04"]["title"])

    def test_anniversaries_are_excluded_without_excluding_revelation(self):
        for row in self.source["days"].values():
            self.assertFalse(any(IMPORTER.PERSONAL_LINE.match(line) for line in row["english"].splitlines()))
        self.assertEqual(self.appointment("2026-11-01")[0]["full"], "Revelation 7:2–4,9–14")
        parsed = self.parse("Rev 1:1-2; Ps 1; Jn 1:1-2\nRev Someone (*1965)\nRt. Fr. Someone (*1961)")
        self.assertEqual(len(parsed), 3)

    def test_local_community_alternatives_are_not_presented_as_vicariate_wide(self):
        parsed = self.parse("Is 1:1-2; Ps 1; Jn 1:1-2\nIn Jerusalem: Local feast\nActs 2:1-3; Mt 3:1-2")
        self.assertEqual([r["full"] for r in parsed], ["Isaiah 1:1–2", "Psalm 1", "John 1:1–2"])

    def test_order_calendar_coverage_and_different_precedence(self):
        francis = load(DATA / "feasts-franciscan-conventual-italy.json")
        augustine = load(DATA / "feasts-augustinian-discalced.json")
        self.assertEqual(list(francis["days"]), dates("2025-11-29", "2026-11-28"))
        self.assertEqual(list(augustine["days"]), dates("2026-01-01", "2026-12-31"))
        self.assertEqual(francis["days"]["2026-10-04"]["rank"], "Solemnity")
        self.assertIn("Francis", francis["days"]["2026-10-04"]["title"])
        self.assertEqual(francis["days"]["2026-08-28"]["rank"], "Memorial")
        self.assertEqual(augustine["days"]["2026-08-28"]["rank"], "Solemnity")
        conventual_readings = load(DATA / "readings-franciscan-conventual-italy.json")
        oad_readings = load(DATA / "readings-augustinian-discalced.json")
        self.assertEqual(len(conventual_readings["days"]), 75)
        self.assertEqual(conventual_readings["days"]["2026-01-25"]["readings"][0]["full"], "Isaiah 8:23b–9:3")
        self.assertEqual(list(oad_readings["days"]), [day for day in dates("2026-01-01", "2026-12-31") if day != "2026-05-30"])
        self.assertTrue(augustine["days"]["2026-05-30"]["readingSourceReview"])
        self.assertEqual([r["full"] for r in oad_readings["days"]["2026-08-28"]["readings"]],
                         ["Acts 2:42–47", "Psalm 149", "2 Timothy 4:1–8", "John 10:7–18"])
        for day in ["2026-05-31", "2026-10-02", "2026-11-09"]:
            self.assertNotIn(day, conventual_readings["days"])
            self.assertTrue(francis["days"][day]["readingSourceReview"])
        self.assertEqual([r["full"] for r in conventual_readings["days"]["2025-12-25"]["readings"]],
                         ["Isaiah 52:7–10", "Psalm 97", "Hebrews 1:1–6", "John 1:1–18"])
        for dataset in [francis, augustine]:
            for row in dataset["days"].values():
                self.assertTrue({"ar", "ru", "tl", "fr", "it", "uk"} <= set(row["titleByLanguage"]))
        for dataset in [conventual_readings, oad_readings]:
            self.assertTrue(set(dataset["days"]) <= set(dates(dataset["coverageStart"], dataset["coverageEnd"])))
            for row in dataset["days"].values():
                for citation in row["readings"]:
                    for field in ["shortByLanguage", "fullByLanguage"]:
                        self.assertTrue({"he", "ar", "ru", "tl", "fr", "it", "uk"} <= set(citation[field]))

    def test_native_datasets_are_byte_identical_to_canonical(self):
        for calendar in ["stjames", "franciscan-conventual-italy", "augustinian-discalced"]:
            for kind in ["feasts", "readings"]:
                name = f"{kind}-{calendar}.json"
                canonical = (DATA / name).read_bytes()
                for directory in ["iOS/Prosary/Data", "Android/app/src/main/assets/data", "Windows/Prosary/Data"]:
                    with self.subTest(dataset=name, platform=directory):
                        self.assertTrue((ROOT / directory / name).read_bytes() == canonical,
                                        f"{directory}/{name} differs from Shared/data/{name}")


if __name__ == "__main__":
    unittest.main()

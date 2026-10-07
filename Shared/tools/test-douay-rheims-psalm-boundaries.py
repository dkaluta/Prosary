#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Check real DRA ending clauses and intact cross-boundary source envelopes."""
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

from reading_psalm_mapping import DRA_PSALM_SOURCE_OVERLAPS
from reading_step_mapping import StepMapper

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("dra_boundary_builder", TOOLS / "build-reading-texts.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class DouayBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        lock = json.loads((TOOLS / "reading-text-sources.json").read_text())
        cls.source = next(row for row in lock["sources"] if row["id"] == "engDRA")
        cls.corpus = builder.load_source(cls.source)
        cls.mapper = StepMapper(cls.corpus, "douay-rheims-1899", overrides=DRA_PSALM_SOURCE_OVERLAPS)

    def passage(self, chapter, verse):
        refs, whole = self.mapper.from_standard([("PSA", chapter, verse)])
        return " ".join(self.corpus[book, c][v] for book, c, v in refs), refs, whole

    def test_every_new_overlap_is_bound_to_the_published_source_and_named_clauses(self):
        review = json.loads((TOOLS / "douay-rheims-psalm-boundaries.json").read_text())
        self.assertEqual(review["sourceSHA256"], self.source["sha256"])
        self.assertEqual(len(review["boundaries"]), 28)
        for row in review["boundaries"]:
            book, chapter, verse = row["source"]
            actual = self.corpus[book, chapter][verse]
            self.assertEqual(actual, row["sourceText"])
            self.assertEqual(hashlib.sha256(actual.encode()).hexdigest(), row["sourceTextSHA256"])
            self.assertEqual(DRA_PSALM_SOURCE_OVERLAPS[book, chapter, verse],
                             frozenset(tuple(ref) for ref in row["standard"]))
            self.assertTrue(row["boundaryReview"])
            self.assertTrue(row["publishedWitnessURL"].startswith("https://www.drbo.org/chapter/"))

    def test_works_appointment_keeps_everything_under_his_feet(self):
        text, refs, whole = self.passage(8, 6)
        self.assertIn(("PSA", 8, 7), refs)
        self.assertIn(("PSA", 8, 8), refs)
        self.assertIn("all things under his feet", text)
        self.assertTrue(whole)

    def test_night_fear_keeps_the_daytime_arrow_ending(self):
        text, _, whole = self.passage(91, 5)
        self.assertIn("terror of the night", text)
        self.assertIn("arrow that flieth in the day", text)
        self.assertTrue(whole)

    def test_hearing_today_keeps_today_and_the_whole_hardening_clause(self):
        text, _, whole = self.passage(95, 7)
        self.assertIn("people of his pasture", text)
        self.assertIn("Today if you shall hear", text)
        self.assertTrue(whole)

    def test_truth_of_the_heart_and_right_hand_are_not_lost_at_the_boundary(self):
        text, _, whole = self.passage(15, 2)
        self.assertIn("truth in his heart", text)
        self.assertTrue(whole)
        text, _, whole = self.passage(17, 7)
        self.assertIn("resist thy right hand", text)
        self.assertTrue(whole)

    def test_source_omission_corrections_restore_the_appointed_children_clause(self):
        text, refs, whole = self.passage(128, 3)
        self.assertEqual(refs, [("PSA", 127, 3)])
        self.assertIn("Thy wife as a fruitful vine", text)
        self.assertIn("Thy children as olive plants", text)
        self.assertFalse(whole)


if __name__ == "__main__":
    unittest.main()

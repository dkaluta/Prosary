#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Offline checks that reviewed reading boundaries cannot escape their scope."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from reading_appointment_reviews import (
    REVIEWS, SOURCE_LOCK, load_reviews, reviewed_appointment, reviewed_references,
)

KEY = "daily|Psalm 139:1–3; 139:13–14ab; 139:23–24"


class AppointmentReviewTests(unittest.TestCase):
    def test_review_is_limited_to_exact_citation_and_calendar(self):
        self.assertIsNotNone(reviewed_appointment(KEY, {"roman"}))
        for contexts in (set(), {"roman1962"}, {"roman", "syriac"}):
            self.assertIsNone(reviewed_appointment(KEY, contexts))
        self.assertIsNone(reviewed_appointment(KEY.replace("daily|", "torah|"), {"roman"}))
        self.assertIsNone(reviewed_appointment(KEY.replace("14ab", "14"), {"roman"}))
        self.assertIsNone(reviewed_appointment("daily|Psalm 139:1–3", {"roman"}))

    def test_dra_envelope_keeps_all_ways_clause_in_verse_four(self):
        review = reviewed_appointment(KEY, {"roman"})
        self.assertTrue(review["includesWholeVerses"])
        self.assertEqual(reviewed_references(review, "douay-rheims-1899"),
                         [("PSA", 138, verse) for verse in (1, 2, 3, 4, 13, 14, 23, 24)])

    def test_other_verified_editions_keep_their_own_psalm_number(self):
        review = reviewed_appointment(KEY, {"roman"})
        for edition_id, chapter in (
            ("masoretic-delitzsch", 139), ("synodal-1876", 138),
            ("ang-dating-biblia-1905", 139), ("crampon-1923", 139), ("kulish-1905", 139),
        ):
            with self.subTest(edition=edition_id):
                self.assertEqual(reviewed_references(review, edition_id),
                                 [("PSA", chapter, verse) for verse in (1, 2, 3, 13, 14, 23, 24)])
        for edition_id in ("martini", "jesuit-arabic-1897", "unknown"):
            self.assertIsNone(reviewed_references(review, edition_id))

    def load_modified(self, *, reviews=None, lock=None):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "reviews.json"
            source = Path(directory) / "sources.json"
            path.write_text(json.dumps(reviews or json.loads(REVIEWS.read_text())), encoding="utf-8")
            source.write_text(json.dumps(lock or json.loads(SOURCE_LOCK.read_text())), encoding="utf-8")
            return load_reviews(path, source)

    def test_a_changed_source_requires_new_boundary_review(self):
        lock = json.loads(SOURCE_LOCK.read_text())
        for source in lock["sources"]:
            if source["id"] == "engDRA":
                source["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "source changed: engDRA"):
            self.load_modified(lock=lock)

    def test_invalid_manual_envelopes_are_rejected(self):
        original = json.loads(REVIEWS.read_text())
        for sequence in (
            [["PSA", 138, 1], ["PSA", 138, 1]],
            [["PSA", 138, 3], ["PSA", 138, 2]],
            [["PSA", 138, True]],
            [["PSA", 138, 0]],
            [["PSA", 138, 1], ["ISA", 1, 2]],
        ):
            with self.subTest(sequence=sequence):
                changed = copy.deepcopy(original)
                changed["appointments"][KEY]["editionReferences"]["douay-rheims-1899"] = sequence
                with self.assertRaises(ValueError):
                    self.load_modified(reviews=changed)


if __name__ == "__main__":
    unittest.main()

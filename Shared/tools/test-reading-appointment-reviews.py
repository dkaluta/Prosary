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
    def test_corinthians_closing_blessing_keeps_each_edition_label(self):
        for start, contexts in ((3, {"ugcc", "ugcc-gregorian"}), (5, {"maronite"})):
            key = f"daily|2 Corinthians 13:{start}–13"
            review = reviewed_appointment(key, contexts)
            self.assertIsNotNone(review)
            self.assertFalse(review["includesWholeVerses"])
            self.assertIsNone(reviewed_appointment(key, contexts | {"syriac"}))
            for edition in review["reviewedEditionIds"]:
                last = 14 if edition in {"ang-dating-biblia-1905", "peshitta-1905"} else 13
                self.assertEqual(reviewed_references(review, edition),
                                 [("2CO", 13, verse) for verse in range(start, last + 1)])
            self.assertIsNone(reviewed_references(review, "jesuit-arabic-1897"))

    def test_peter_liturgical_cut_gets_notice_without_adding_verse_sixteen(self):
        key = "daily|1 Peter 3:8–15"
        review = reviewed_appointment(key, {"roman1962"})
        self.assertTrue(review["includesWholeVerses"])
        self.assertIsNone(reviewed_appointment(key, {"roman"}))
        for edition in review["reviewedEditionIds"]:
            self.assertEqual(reviewed_references(review, edition),
                             [("1PE", 3, verse) for verse in range(8, 16)])

    def test_reviewed_gospel_boundaries_keep_house_arrival_and_summoned_disciples(self):
        review = reviewed_appointment("daily|Mark 3:20–30", {"syriac"})
        self.assertTrue(review["includesWholeVerses"])
        self.assertIsNone(reviewed_appointment("daily|Mark 3:20–30", {"roman"}))
        for edition in review["reviewedEditionIds"]:
            first = 19 if edition in {"ang-dating-biblia-1905", "peshitta-1905"} else 20
            self.assertEqual(reviewed_references(review, edition),
                             [("MRK", 3, verse) for verse in range(first, 31)])
        review = reviewed_appointment("daily|Luke 7:11–18", {"syriac"})
        self.assertTrue(review["includesWholeVerses"])
        for edition in review["reviewedEditionIds"]:
            self.assertEqual(reviewed_references(review, edition),
                             [("LUK", 7, verse) for verse in range(11, 20)])

    def test_liturgical_cuts_keep_notices_without_unappointed_following_verses(self):
        for key, contexts, book, chapter, verses in (
            ("daily|Acts 3:13–15; 3:17–19", {"roman1962"}, "ACT", 3, (13, 14, 15, 17, 18, 19)),
            ("daily|Mark 16:1–7", {"roman1962"}, "MRK", 16, range(1, 8)),
            ("daily|Ephesians 5:3–13", {"maronite"}, "EPH", 5, range(3, 14)),
        ):
            with self.subTest(key=key):
                review = reviewed_appointment(key, contexts)
                self.assertTrue(review["includesWholeVerses"])
                self.assertIsNone(reviewed_appointment(key, contexts | {"roman"}))
                for edition in review["reviewedEditionIds"]:
                    self.assertEqual(reviewed_references(review, edition),
                                     [(book, chapter, verse) for verse in verses])

    def test_shared_mark_citations_cover_both_verified_calendar_boundaries(self):
        for key, first, last, contexts in (
            ("daily|Mark 3:13–19", 13, 19, {"ugcc", "ugcc-gregorian", "syriac"}),
            ("daily|Mark 3:20–27", 20, 27, {"ugcc", "ugcc-gregorian"}),
        ):
            review = reviewed_appointment(key, contexts)
            self.assertEqual(review["sourceSystem"], "reviewed")
            self.assertTrue(review["includesWholeVerses"])
            self.assertIsNone(reviewed_appointment(key, contexts | {"roman"}))
            for edition in review["reviewedEditionIds"]:
                starts_at = first
                ends_at = last
                if first == 13 and edition not in {"ang-dating-biblia-1905", "peshitta-1905"}:
                    ends_at = 20
                if first == 20 and edition in {"ang-dating-biblia-1905", "peshitta-1905"}:
                    starts_at = 19
                self.assertEqual(reviewed_references(review, edition),
                                 [("MRK", 3, verse) for verse in range(starts_at, ends_at + 1)])

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

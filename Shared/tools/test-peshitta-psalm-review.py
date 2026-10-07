#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Reference-only regressions for inspected Peshitta Psalm bodies and envelopes."""
from copy import deepcopy
import json
from pathlib import Path
import unittest

from peshitta_eu_source import review as website_review
from peshitta_psalm_review import REVIEW_PATH, validate_review
from reading_edition_mapping import EditionMapper
from reading_edition_reviews_peshitta import PROFILES
from reading_step_mapping import Unavailable

TOOLS = Path(__file__).resolve().parent


class PsalmReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.review = json.loads(REVIEW_PATH.read_text())
        cls.lock = json.loads((TOOLS / "reading-text-sources.json").read_text())
        cls.website = website_review()
        record = json.loads((TOOLS / "versification/editions/inventories.json").read_text())["editions"]["peshitta-1905"]
        cls.mapper = EditionMapper("peshitta-1905", record, profile=PROFILES["peshitta-1905"])

    def test_numbering_is_tied_to_actual_psalm_bodies_instead_of_a_blanket_greek_offset(self):
        for standard, expected in [((23, 1), (23, 1)), ((51, 10), (51, 10)),
                                   ((118, 1), (117, 1)), ((145, 14), (144, 14))]:
            with self.subTest(standard=standard):
                self.assertEqual(self.mapper.from_standard([("PSA", *standard)])[0], [("PSA", *expected)])

    def test_crossed_clauses_expand_to_complete_source_envelopes(self):
        self.assertEqual(self.mapper.from_standard([("PSA", 1, 1)]),
                         ([("PSA", 1, 1), ("PSA", 1, 2)], True))
        self.assertEqual(self.mapper.from_standard([("PSA", 1, 1), ("PSA", 1, 2)]),
                         ([("PSA", 1, 1), ("PSA", 1, 2)], False))
        self.assertEqual(self.mapper.from_standard([("PSA", 17, 3)]),
                         ([("PSA", 17, 3), ("PSA", 17, 4)], True))
        self.assertEqual(self.mapper.from_standard([("PSA", 113, 5)]), ([("PSA", 113, 5)], True))
        self.assertEqual(self.mapper.from_standard([("PSA", 145, 10), ("PSA", 145, 11)]),
                         ([("PSA", 144, 10)], False))
        self.assertEqual(self.mapper.from_standard([("PSA", 145, 13)]),
                         ([("PSA", 144, 12), ("PSA", 144, 13)], False))

    def test_similar_judgement_verses_and_repeated_refrains_keep_their_own_psalm_identity(self):
        self.assertEqual(self.mapper.from_standard([("PSA", 96, 13)]), ([("PSA", 96, 13)], False))
        self.assertEqual(self.mapper.from_standard([("PSA", 98, 9)]),
                         ([("PSA", 98, 8), ("PSA", 98, 9)], True))
        self.assertEqual(self.mapper.from_standard([("PSA", 107, 6)]), ([("PSA", 107, 6)], False))
        self.assertEqual(self.mapper.from_standard([("PSA", 107, 8)]), ([("PSA", 107, 8)], False))

    def test_source_gaps_and_unreviewed_units_do_not_gain_identity_fallbacks(self):
        for reference in [("PSA", 119, 91), ("PSA", 89, 1), ("PSA", 3, 1)]:
            with self.subTest(reference=reference), self.assertRaises(Unavailable):
                self.mapper.from_standard([reference])

    def test_every_frozen_unit_roundtrips_without_losing_a_source_member(self):
        allowed, _ = validate_review(self.review, self.lock, self.website)
        self.assertEqual(len(allowed), 427)
        for unit in self.review["units"]:
            sources = [tuple(ref) for ref in unit["sourceReferences"]]
            targets = [tuple(ref) for ref in unit["standardReferences"]]
            self.assertEqual(self.mapper.to_standard(sources)[0], targets)
            self.assertEqual(self.mapper.from_standard(targets)[0], sources)

    def test_changed_source_pins_or_missing_boundary_evidence_require_new_review(self):
        for change in ("source_pin", "overlap", "bridge", "hash"):
            value = deepcopy(self.review)
            if change == "source_pin":
                first = next(iter(value["sourceChapterPins"]))
                value["sourceChapterPins"][first] = "0" * 64
            elif change == "overlap": value["units"].append(deepcopy(value["units"][0]))
            elif change == "bridge": value["units"][0]["standardReferences"] = [["PSA", 2, 1]]
            else: value["units"][0]["sourceVerseSHA256"] = []
            with self.subTest(change=change), self.assertRaises(ValueError):
                validate_review(value, self.lock, self.website)


if __name__ == "__main__":
    unittest.main()

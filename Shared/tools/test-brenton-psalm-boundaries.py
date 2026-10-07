#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Keep the three reviewed Greek ending clauses and their intact wider rows.

Construct the numeric inventory from the exact pinned source in memory, so this
focused suite does not depend on concurrent global inventory regeneration.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from reading_edition_mapping import EditionMapper, corpus_digest
from reading_edition_reviews_greek import BRENTON_PSALM_SOURCE_OVERLAPS

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("brenton_boundary_builder", TOOLS / "build-reading-texts.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class BrentonBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        lock = json.loads((TOOLS / "reading-text-sources.json").read_text())
        cls.source = next(row for row in lock["sources"] if row["id"] == "grcbrent")
        cls.edition = next(row for row in lock["editions"] if row["id"] == "brenton-lxx")
        if not (builder.CACHE / cls.source["cache"]).is_file():
            raise unittest.SkipTest("The exact pinned Greek source cache is not present")
        cls.pins = {cls.source["id"]: cls.source["sha256"]}
        cls.corpus = builder.PinnedCorpus(builder.load_source(cls.source), cls.pins)
        record = {"sourcePins": cls.pins, "corpusSHA256": corpus_digest(cls.corpus),
                  "systems": {"ot": cls.edition["otSystem"], "nt": cls.edition["ntSystem"]},
                  "chapters": [[book, chapter, [[verse, len(text.split())]
                                for verse, text in sorted(values.items())]]
                               for (book, chapter), values in sorted(cls.corpus.items())]}
        cls.mapper = EditionMapper("brenton-lxx", record)
        cls.mapper.validate_source(cls.corpus, cls.pins)
        cls.review = json.loads((TOOLS / "brenton-psalm-boundaries.json").read_text())

    def passage(self, key):
        # Exercise the real appointment parser, numbering review and whole-unit
        # notice using a freshly verified numeric mapper, without stale globals.
        with patch.object(builder, "edition_mapper", return_value=self.mapper):
            return builder.resolve(key, {"roman"}, self.edition, self.corpus)

    def assert_intact_ending(self, index):
        review = self.review["boundaries"][index]
        book, chapter, verse = review["source"]
        for key in review["affectedRomanKeys"]:
            with self.subTest(appointment=key):
                passage = self.passage(key)
                selected = next(row for row in passage
                                if (row["chapter"], row["verse"]) == (chapter, verse))
                self.assertEqual(selected["text"], self.corpus[book, chapter][verse])
                self.assertIn(review["sourceClause"], selected["text"])
                self.assertTrue(passage.includes_whole_verses)
                for row in passage:
                    self.assertEqual(row["text"], self.corpus[book, row["chapter"]][row["verse"]])

    def test_review_is_bound_to_the_exact_source_rows_and_three_independent_edges(self):
        self.assertEqual(self.review["sourceId"], self.source["id"])
        self.assertEqual(self.review["sourceSHA256"], self.source["sha256"])
        self.assertEqual(self.review["sourceURL"], self.source["url"])
        self.assertEqual(self.review["sourceMember"], self.source["member"])
        self.assertEqual(len(self.review["boundaries"]), 3)
        self.assertEqual({tuple(row["source"]) for row in self.review["boundaries"]},
                         set(BRENTON_PSALM_SOURCE_OVERLAPS))
        for row in self.review["boundaries"]:
            ref = tuple(row["source"])
            actual = self.corpus[ref[:2]][ref[2]]
            self.assertEqual(hashlib.sha256(actual.encode()).hexdigest(), row["sourceTextSHA256"])
            self.assertIn(row["sourceClause"], actual)
            self.assertEqual(BRENTON_PSALM_SOURCE_OVERLAPS[ref],
                             tuple(tuple(target) for target in row["standard"]))

    def test_roman_psalm_seventeen_ending_keeps_the_mouth_clause(self):
        self.assert_intact_ending(0)

    def test_roman_psalm_nineteen_ending_keeps_the_sun_tabernacle(self):
        self.assert_intact_ending(1)

    def test_roman_psalm_ninety_five_ending_keeps_today_hear(self):
        self.assert_intact_ending(2)

    def test_complete_pairs_need_no_wider_notice_but_single_endings_do(self):
        for row in self.review["boundaries"]:
            source = tuple(row["source"])
            standard = [tuple(ref) for ref in row["standard"]]
            with self.subTest(source=source):
                refs, whole = self.mapper.from_standard(standard)
                self.assertIn(source, refs)
                self.assertFalse(whole)
                refs, whole = self.mapper.from_standard(standard[:1])
                self.assertIn(source, refs)
                self.assertTrue(whole)

    def test_greek_eight_already_keeps_under_feet_without_borrowing_douay_eight(self):
        refs, whole = self.mapper.from_standard([("PSA", 8, 6)])
        self.assertEqual(refs, [("PSA", 8, 7)])
        self.assertFalse(whole)
        self.assertIn("πάντα ὑπέταξας ὑποκάτω τῶν ποδῶν αὐτοῦ", self.corpus["PSA", 8][7])
        self.assertEqual(self.mapper.to_standard([("PSA", 8, 8)]), ([("PSA", 8, 7)], False))


if __name__ == "__main__":
    unittest.main()

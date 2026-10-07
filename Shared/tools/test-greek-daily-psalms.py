#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Pinned Psalm boundaries, printed suffix preservation and exact-scope gates."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

from greek_daily_psalms import Resolver, Unavailable, default_resolver, load_reviews, source_rows

SPLIT = "daily|Psalm 13:6ab–6ab; 13:6cd–6cd"
NUN = "daily|Psalm 145:8–9; 145:10–11; 145:12–13ab; 145:13cd–14"
KINGDOM = "daily|Psalm 145:10–11; 145:12–13ab; 145:17–18"
VOWS = "daily|Psalm 116:12–13; 116:17–18"
HEART = "daily|Psalm 139:1–3; 139:13–14ab; 139:23–24"


class GreekDailyScopeTests(unittest.TestCase):
    def setUp(self):
        self.raw = b"PSA 144:12 Power\nPSA 144:13 Kingdom\nPSA 144:13a Faithful\nPSA 144:14 Support\n"
        self.review = {"contexts": ["roman"], "sourceChapter": 144,
                       "sourceLabels": ["12", "13", "13a", "14"],
                       "includesWholeVerses": True, "isComplete": False}
        self.resolver = Resolver(self.raw, {NUN: self.review}, expected_sha256=hashlib.sha256(self.raw).hexdigest())

    def test_exact_citation_calendar_and_scope_do_not_escape_the_review(self):
        self.assertTrue(self.resolver.handles(NUN))
        for contexts in (set(), {"syriac"}, {"roman", "roman1962"}):
            with self.subTest(contexts=contexts), self.assertRaises(Unavailable):
                self.resolver.resolve(NUN, contexts)
        for key in (NUN + " ", NUN.replace("daily|", "torah|"), NUN.replace("13cd", "13c")):
            with self.subTest(key=key), self.assertRaises(Unavailable):
                self.resolver.resolve(key, {"roman"})

    def test_suffix_is_a_distinct_printed_witness_and_primary_is_never_repeated(self):
        passage = self.resolver.resolve(NUN, {"roman"})
        self.assertEqual([row["verse"] for row in passage.verses], [12, 13, 14])
        self.assertEqual([row["text"] for row in passage.verses], ["Power", "Kingdom", "Support"])
        witness = passage.source["contentBlocks"][2]
        self.assertEqual((witness["kind"], witness["printedLabel"], witness["text"]), ("witness", "13a", "Faithful"))
        self.assertFalse(passage.source["isComplete"])
        self.assertTrue(passage.includes_whole_verses)

    def test_changed_payload_and_missing_units_cannot_silently_shorten_a_passage(self):
        with self.assertRaisesRegex(ValueError, "source changed"):
            source_rows(self.raw)
        review = copy.deepcopy(self.review)
        review["sourceLabels"].append("15")
        with self.assertRaisesRegex(ValueError, "absent"):
            Resolver(self.raw, {NUN: review}, expected_sha256=hashlib.sha256(self.raw).hexdigest())


class PinnedGreekDailyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.resolver = default_resolver()

    def test_nine_reviewed_keys_preserve_every_selected_original_source_unit(self):
        self.assertEqual(len(load_reviews()), 9)
        for key, review in load_reviews().items():
            with self.subTest(key=key):
                passage = self.resolver.resolve(key, {"roman"})
                chapter = review["sourceChapter"]
                self.assertEqual([row["verse"] for row in passage.verses],
                                 [int(label) for label in review["sourceLabels"] if label.isdigit()])
                for row in passage.verses:
                    self.assertEqual(row["text"], self.resolver.rows[chapter, str(row["verse"])])
                for block in passage.source["contentBlocks"]:
                    if block["kind"] == "witness":
                        self.assertEqual(block["text"], self.resolver.rows[chapter, block["printedLabel"]])

    def test_psalm_thirteen_six_requires_both_greek_source_verses_five_and_six(self):
        passage = self.resolver.resolve(SPLIT, {"roman"})
        self.assertEqual([(row["chapter"], row["verse"]) for row in passage.verses], [(12, 5), (12, 6)])
        self.assertTrue(passage.verses[0]["text"].startswith("Ἐγὼ δὲ ἐπὶ τῷ ἐλέει"))
        self.assertTrue(passage.verses[1]["text"].startswith("Ἄσω τῷ Κυρίῳ"))
        self.assertTrue(passage.includes_whole_verses)

    def test_faithful_clause_is_present_only_when_appointed_and_keeps_printed_thirteen_a(self):
        full = self.resolver.resolve(NUN, {"roman"})
        witness = next(block for block in full.source["contentBlocks"] if block["kind"] == "witness")
        self.assertEqual(witness["printedLabel"], "13a")
        self.assertTrue(witness["text"].startswith("πιστὸς Κύριος"))
        kingdom = self.resolver.resolve(KINGDOM, {"roman"})
        self.assertFalse(any(block["kind"] == "witness" for block in kingdom.source["contentBlocks"]))
        self.assertNotIn(witness["text"], "\n".join(row["text"] for row in kingdom.verses))

    def test_vows_use_the_later_appointed_occurrence_not_the_omitted_four_a(self):
        passage = self.resolver.resolve(VOWS, {"roman"})
        self.assertEqual([row["verse"] for row in passage.verses], [3, 4, 8, 9])
        self.assertFalse(any(block["kind"] == "witness" for block in passage.source["contentBlocks"]))
        self.assertEqual(passage.verses[-1]["text"], self.resolver.rows[115, "9"])
        self.assertFalse(passage.source["isComplete"])

    def test_searched_paths_stay_in_greek_three_without_borrowing_douay_four(self):
        passage = self.resolver.resolve(HEART, {"roman"})
        self.assertEqual([row["verse"] for row in passage.verses], [1, 2, 3, 13, 14, 23, 24])
        self.assertTrue(passage.verses[2]["text"].endswith("πάσας τὰς ὁδούς μου προεῖδες,"))

    def test_builder_selects_all_nine_reviewed_excerpts_before_generic_chapter_exclusions(self):
        path = Path(__file__).with_name("build-reading-texts.py")
        specification = importlib.util.spec_from_file_location("greek_daily_integration_builder", path)
        builder = importlib.util.module_from_spec(specification)
        specification.loader.exec_module(builder)
        edition = next(edition for edition in json.loads(builder.LOCK.read_text())["editions"]
                       if edition["id"] == "brenton-lxx")
        for key in load_reviews():
            with self.subTest(key=key):
                expected = self.resolver.resolve(key, {"roman"})
                actual = builder.resolve(key, {"roman"}, edition, {})
                self.assertEqual(list(actual), expected.verses)
                self.assertEqual(actual.source, expected.source)


if __name__ == "__main__":
    unittest.main()

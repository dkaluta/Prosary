#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Bounded source119 correspondence, paired scripts and explicit omission guards."""
import hashlib
import unittest

from aramaic_script_converter import to_hebrew
from peshitta_daily_psalms import Resolver, Unavailable, default_resolver, load_reviews, source_rows
from peshitta_eu_source import parse_chapter

KEY = "daily|Psalm 119:41–41; 119:43–43; 119:44–44; 119:45–45; 119:47–47; 119:48–48"
OMISSION_KEY = "daily|Psalm 119:66–66; 119:71–71; 119:75–75; 119:91–91; 119:125–125; 119:130–130"


def fixture(marker="(ܠܝܬ)"):
    return "".join(f'<span class="verse" id="v{verse}" data-ref="psalms.118.{verse}">{verse} '
                   f'{marker if verse == 91 else "ܐܰܒܳܐ"}</span>' for verse in range(1, 177)).encode()


class SparseSourceTests(unittest.TestCase):
    def test_ordinary_complete_chapter_guard_remains_strict(self):
        raw = fixture()
        with self.assertRaises(ValueError): parse_chapter(raw, "psalms", 118)
        rows = source_rows(raw, expected_sha256=hashlib.sha256(raw).hexdigest())
        self.assertEqual(len(rows), 175)
        self.assertNotIn(91, rows)
        self.assertEqual(rows[90], "ܐܰܒܳܐ")
        self.assertEqual(rows[92], "ܐܰܒܳܐ")

    def test_changed_source_omission_label_or_missing_neighbour_requires_fresh_review(self):
        with self.assertRaisesRegex(ValueError, "source changed"): source_rows(fixture())
        for raw in (fixture(""), fixture("Missing"), fixture().replace(b'data-ref="psalms.118.92"', b'data-ref="psalms.118.93"')):
            with self.subTest(raw=raw[:20]), self.assertRaises(ValueError):
                source_rows(raw, expected_sha256=hashlib.sha256(raw).hexdigest())


class PinnedDailyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.resolver = default_resolver()

    def test_all_seven_appointments_retain_every_original_source_unit_and_both_scripts(self):
        reviews = load_reviews()
        self.assertEqual(len(reviews), 7)
        for key, review in reviews.items():
            with self.subTest(key=key):
                passage = self.resolver.resolve(key, {"roman"})
                self.assertEqual([row["verse"] for row in passage.verses], review["sourceVerses"])
                self.assertIsNone(passage.source)
                for row in passage.verses:
                    original = self.resolver.rows[row["verse"]]
                    self.assertEqual(row["chapter"], 118)
                    self.assertEqual(row["transliteratedText"], original)
                    self.assertEqual(row["text"], to_hebrew(original))

    def test_omitted_unit_and_foreign_calendar_never_gain_a_fallback(self):
        self.assertFalse(self.resolver.handles(OMISSION_KEY))
        for key, contexts in [(OMISSION_KEY, {"roman"}), (KEY, {"syriac"}),
                              (KEY, set()), (KEY, {"roman", "roman1962"}), (KEY + " ", {"roman"})]:
            with self.subTest(key=key, contexts=contexts), self.assertRaises(Unavailable):
                self.resolver.resolve(key, contexts)

    def test_lifting_hands_clause_stays_in_the_two_original_whole_units(self):
        passage = self.resolver.resolve(KEY, {"roman"})
        selected = {row["verse"]: row["transliteratedText"] for row in passage.verses}
        self.assertIn("ܘܰܐܪܺܝܡ", selected[47])
        self.assertTrue(selected[48].startswith("ܘܶܐܪܢܶܐ"))


if __name__ == "__main__": unittest.main()

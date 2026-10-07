#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Source-clause, scope and source-revision checks for the Arabic Psalm expansion."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from arabic_daily_psalms import Resolver, REVIEWS, ROOT, Unavailable, default_resolver


class ArabicDailyPsalmTests(unittest.TestCase):
    def setUp(self):
        self.resolver = default_resolver()

    def passage(self, chapter, verses):
        return self.resolver.resolve_standard([("PSA", chapter, verse) for verse in verses])

    def test_every_original_roman_psalm_has_all_reviewed_source_words(self):
        self.assertEqual(len(self.resolver.reviews), 103)
        for key in self.resolver.reviews:
            passage = self.resolver.resolve(key, {"roman"})
            self.assertTrue(passage.verses)
            self.assertTrue(all(row["text"].strip() for row in passage.verses))

    def test_under_feet_and_sun_tent_are_retained_in_complete_native_units(self):
        under_feet = self.passage(8, [6])
        self.assertEqual([(v["chapter"], v["verse"]) for v in under_feet.verses], [(8, 7)])
        self.assertIn("تحت قدميه", under_feet.verses[0]["text"])
        sun = self.passage(19, [4])
        self.assertEqual([(v["chapter"], v["verse"]) for v in sun.verses], [(18, 5), (18, 6)])
        self.assertIn("وللشمس نصب خباء", sun.verses[-1]["text"])
        self.assertTrue(sun.includes_whole_verses)

    def test_existing_printed_split_does_not_drop_today_or_right_hand_clauses(self):
        today = self.passage(95, [7])
        self.assertIn("اليوم", " ".join(v["text"] for v in today.verses))
        self.assertTrue(today.includes_whole_verses)
        right_hand = self.passage(118, [16])
        self.assertEqual([(v["chapter"], v["verse"]) for v in right_hand.verses], [(117, 16)])
        self.assertEqual(right_hand.verses[0]["text"].count("يمين الرب"), 3)
        self.assertTrue(right_hand.includes_whole_verses)
        tents = self.passage(118, [15])
        self.assertEqual([(v["chapter"], v["verse"]) for v in tents.verses], [(117, 15), (117, 16)])
        self.assertIn("في أخبية الصديقين", tents.verses[0]["text"])
        self.assertTrue(tents.includes_whole_verses)

    def test_sparse_overlap_cannot_falsely_certify_an_unreviewed_neighbor(self):
        review = json.loads(REVIEWS.read_text())
        review["units"] = [unit for unit in review["units"] if unit["source"] != [[117, 15]]]
        with self.assertRaisesRegex(ValueError, "neighboring unit"):
            Resolver(review)

    def test_correct_requested_vow_occurrence_is_not_replaced_by_earlier_duplicate(self):
        passage = self.passage(116, [12, 13, 17, 18])
        self.assertEqual([(v["chapter"], v["verse"]) for v in passage.verses], [(115, 3), (115, 4), (115, 8), (115, 9)])
        self.assertIn("ماذا أرد إلى الرب", passage.verses[0]["text"])
        self.assertTrue(passage.verses[2]["text"].startswith("فلك أذبح"))

    def test_old_print_wording_and_uncertain_alif_are_not_silently_modernized(self):
        frame = self.passage(139, [15])
        self.assertIn("ذاتي عنك", frame.verses[0]["text"])
        self.assertNotIn("عظامك", frame.verses[0]["text"])
        numbered_days = self.passage(90, [12])
        self.assertIn("فعلمنا أن نعد أيامنا هكذا فاتي", numbered_days.verses[0]["text"])
        self.assertIn("alif mark", numbered_days.source["attribution"])
        self.assertIn("princeton_aco001445/243", numbered_days.source["sourceURL"])

    def test_calendar_scope_and_unreviewed_source_words_fail_closed(self):
        key = next(iter(self.resolver.reviews))
        with self.assertRaises(Unavailable):
            self.resolver.resolve(key, {"stjames"})
        with self.assertRaises(Unavailable):
            self.resolver.resolve(key, {"roman", "stjames"})
        with self.assertRaises(Unavailable):
            self.resolver.resolve_standard([("PSA", 119, 3)])
        with self.assertRaises(Unavailable):
            self.resolver.resolve_standard([("GEN", 1, 1)])

    def test_new_source_pin_rejects_unreviewed_wording_changes(self):
        review = json.loads(REVIEWS.read_text())
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for source in review["sources"]:
                target = root / source["path"]
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / source["path"]).read_bytes())
            changed = root / review["sources"][-1]["path"]
            changed.write_text(changed.read_text().replace("فاتي", "فآتي", 1))
            with self.assertRaisesRegex(ValueError, "wording changed"):
                Resolver(review, root)


if __name__ == "__main__":
    unittest.main()

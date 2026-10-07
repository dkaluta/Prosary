#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Pin Martini's appointed clauses, native source units and exact review scope."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from martini_daily_psalms import CACHE, REVIEW_PATH, Resolver, Unavailable, default_resolver


class MartiniPsalmTests(unittest.TestCase):
    def setUp(self):
        self.resolver = default_resolver()

    def find(self, chapter, verses):
        wanted = {("PSA", chapter, verse) for verse in verses}
        return next((key, review) for key, review in self.resolver.reviews.items()
                    if wanted <= {tuple(ref) for ref in review["standardReferences"]})

    def test_all_103_exact_appointments_retain_original_rows(self):
        self.assertEqual(len(self.resolver.reviews), 103)
        for key, review in self.resolver.reviews.items():
            passage = self.resolver.resolve(key, {"roman"})
            self.assertEqual([(v["chapter"], v["verse"]) for v in passage.verses],
                             [tuple(ref) for ref in review["sourceReferences"]])
            for row in passage.verses:
                self.assertEqual(row["text"], self.resolver.rows[row["chapter"], row["verse"]])
            self.assertIn("Parola Viva", passage.source["attribution"])

    def test_complete_split_chapter_requests_keep_only_the_correct_original_body(self):
        for chapter, wanted, first_phrase, last_phrase in (
            (115, [("PSA", 116, verse) for verse in range(10, 20)], "Credetti;", "o Gerusalemme."),
            (147, [("PSA", 147, verse) for verse in range(12, 21)], "Loda, o Gerusalemme", "i suoi giudizj."),
        ):
            with self.subTest(chapter=chapter):
                passage = self.resolver.resolve_standard(wanted)
                self.assertEqual([(row["chapter"], row["verse"]) for row in passage.verses],
                                 self.resolver.whole_chapters[chapter])
                self.assertEqual([row["text"] for row in passage.verses],
                                 [self.resolver.rows[ref] for ref in self.resolver.whole_chapters[chapter]])
                self.assertEqual(self.resolver.whole_standard_groups[chapter], frozenset(wanted))
                self.assertTrue(all(row["chapter"] == chapter for row in passage.verses))
                self.assertIn(first_phrase, passage.verses[0]["text"])
                self.assertIn(last_phrase, passage.verses[-1]["text"])
        both = [("PSA", 116, verse) for verse in range(1, 20)]
        passage = self.resolver.resolve_standard(both)
        self.assertEqual([(row["chapter"], row["verse"]) for row in passage.verses],
                         self.resolver.whole_chapters[114] + self.resolver.whole_chapters[115])

    def test_dominion_appointment_keeps_under_the_feet_clause(self):
        key, _ = self.find(8, [6])
        passage = self.resolver.resolve(key, {"roman"})
        self.assertTrue(any("opere delle tue mani" in row["text"] for row in passage.verses))
        self.assertTrue(any("soggettate a' piedi di lui" in row["text"] for row in passage.verses))
        self.assertTrue(passage.includes_whole_verses)

    def test_children_and_olive_plants_follow_the_wife_clause(self):
        key, _ = self.find(128, [3])
        passage = self.resolver.resolve(key, {"roman"})
        rows = {v["verse"]: v["text"] for v in passage.verses if v["chapter"] == 127}
        self.assertIn("consorte come vite", rows[3])
        self.assertIn("figliuoli, come novelle piante d'ulivi", rows[4])

    def test_thoughts_paths_womb_and_everlasting_way_have_native_139_labels(self):
        key = "daily|Psalm 139:1–3; 139:13–14ab; 139:23–24"
        passage = self.resolver.resolve(key, {"roman"})
        self.assertEqual([v["verse"] for v in passage.verses], [1, 2, 3, 12, 13, 22, 23])
        self.assertTrue(any("vie tutte" in v["text"] for v in passage.verses))
        self.assertTrue(any("seno di mia madre" in v["text"] for v in passage.verses))
        self.assertIn("via dell'eternità", passage.verses[-1]["text"])

    def test_sacrifice_and_vows_keep_their_source_crossings(self):
        key, _ = self.find(116, [12, 13, 17, 18])
        passage = self.resolver.resolve(key, {"roman"})
        self.assertEqual([v["verse"] for v in passage.verses], [3, 4, 7, 8])
        self.assertIn("sagrificherò ostia di lode", passage.verses[2]["text"])
        self.assertIn("Scioglierò i voti", passage.verses[3]["text"])
        self.assertTrue(passage.includes_whole_verses)

    def test_unreviewed_citation_or_mixed_context_is_unavailable(self):
        key = next(iter(self.resolver.reviews))
        for contexts in ({"syriac"}, {"roman", "maronite"}, set()):
            with self.assertRaises(Unavailable): self.resolver.resolve(key, contexts)
        with self.assertRaises(Unavailable):
            self.resolver.resolve("daily|Psalm 8:1", {"roman"})

    def test_complete_established_chapter_keeps_native_irregular_rows(self):
        passage = self.resolver.resolve_standard([("PSA", 128, verse) for verse in range(1, 7)])
        self.assertEqual([(row["chapter"], row["verse"]) for row in passage.verses],
                         [(127, verse) for verse in range(1, 8)])
        self.assertIn("figliuoli, come novelle piante d'ulivi", passage.verses[3]["text"])
        passage = self.resolver.resolve_standard([("PSA", 150, verse) for verse in range(1, 7)])
        self.assertEqual([row["verse"] for row in passage.verses], [1, 2, 3, 4, 5])
        self.assertIn("ogni spirito", passage.verses[-1]["text"])

    def test_a_partial_request_cannot_use_unreviewed_offsets_or_a_whole_chapter_substitute(self):
        with self.assertRaisesRegex(Unavailable, "source-verse boundaries"):
            self.resolver.resolve_standard([("PSA", 2, 7)])

    def test_source_mutation_and_missing_boundary_fail_closed(self):
        review = json.loads(REVIEW_PATH.read_text())
        broken = copy.deepcopy(review)
        broken["boundaries"] = broken["boundaries"][1:]
        with self.assertRaises(ValueError): Resolver(broken)
        with tempfile.TemporaryDirectory() as directory:
            changed = Path(directory)
            source = review["sources"][0]
            (changed / source["cache"]).write_bytes((CACHE / source["cache"]).read_bytes() + b" ")
            with self.assertRaisesRegex(ValueError, "payload"):
                Resolver(review, changed)


if __name__ == "__main__":
    unittest.main()

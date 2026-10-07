#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Original complete Greek source bodies, suffix witnesses and bounded scope."""
import copy
import hashlib
import json
from pathlib import Path
import unittest
import zipfile

from brenton_reading_source import SOURCE_SHA256, parse_source
from greek_daily_psalms import Resolver, Unavailable, default_resolver, load_reviews, load_whole_reviews

TOOLS = Path(__file__).resolve().parent


def standard(chapter, first, last):
    return [("PSA", chapter, verse) for verse in range(first, last + 1)]


class GreekWholePsalmTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.resolver = default_resolver()
        cls.reviews = load_whole_reviews()
        lock = json.loads((TOOLS / "reading-text-sources.json").read_text())
        source = next(row for row in lock["sources"] if row["id"] == "grcbrent")
        with zipfile.ZipFile(TOOLS / ".scripture-cache" / source["cache"]) as archive:
            cls.raw = archive.read(source["member"])

    def assert_original_body(self, passage, chapters):
        expected_rows, expected_ids = [], []
        for chapter in chapters:
            for label in self.reviews[chapter]["sourceLabels"]:
                expected_ids.append(f"grcbrent-psa-{chapter}-{label}")
                if label.isdigit():
                    expected_rows.append({"chapter": chapter, "verse": int(label),
                                          "text": self.resolver.rows[chapter, label]})
        self.assertEqual(passage.verses, expected_rows)
        self.assertEqual([block["id"] for block in passage.source["contentBlocks"]], expected_ids)
        self.assertEqual(len(expected_ids), len(set(expected_ids)))
        self.assertTrue(passage.source["isComplete"])

    def test_all_four_complete_bodies_are_bound_to_the_original_bytes_labels_and_words(self):
        self.assertEqual(hashlib.sha256(self.raw).hexdigest(), SOURCE_SHA256)
        self.assertEqual(set(self.reviews), {12, 114, 115, 144})
        for chapter, review in self.reviews.items():
            labels = review["sourceLabels"]
            original_labels = {label for c, label in self.resolver.rows if c == chapter}
            self.assertEqual(set(labels), original_labels)
            body = [[chapter, label, self.resolver.rows[chapter, label]] for label in labels]
            raw = json.dumps(body, ensure_ascii=False, separators=(",", ":")) + "\n"
            self.assertEqual(hashlib.sha256(raw.encode()).hexdigest(), review["sourceBodySHA256"])
            self.assertEqual(review["sourceURL"], f"https://ebible.org/grcbrent/PSA{chapter:03d}.htm")

    def test_native_115_keeps_the_earlier_vows_as_printed_four_a_and_never_invents_five(self):
        passage = self.resolver.resolve_standard(standard(116, 10, 19))
        self.assert_original_body(passage, [115])
        self.assertEqual([row["verse"] for row in passage.verses], [1, 2, 3, 4, 6, 7, 8, 9, 10])
        witness = next(block for block in passage.source["contentBlocks"] if block["kind"] == "witness")
        self.assertEqual(witness["printedLabel"], "4a")
        self.assertEqual(witness["addresses"], [{"chapter": 115, "verse": 4, "part": "a"}])
        self.assertEqual(witness["text"], self.resolver.rows[115, "4a"])
        self.assertTrue(witness["text"].startswith("Τὰς εὐχάς μου"))
        self.assertEqual(passage.verses[-2]["text"], self.resolver.rows[115, "9"])
        self.assertFalse(passage.includes_whole_verses)

    def test_native_114_is_separate_and_the_full_standard_116_keeps_both_source_bodies(self):
        first = self.resolver.resolve_standard(standard(116, 1, 9))
        self.assert_original_body(first, [114])
        self.assertFalse(first.includes_whole_verses)
        complete = self.resolver.resolve_standard(standard(116, 1, 19))
        self.assert_original_body(complete, [114, 115])
        self.assertFalse(complete.includes_whole_verses)
        disclosed = self.resolver.resolve_standard(standard(116, 1, 19), includes_whole_verses=True)
        self.assertEqual(disclosed.verses, complete.verses)
        self.assertTrue(disclosed.includes_whole_verses)

    def test_whole_standard_145_preserves_the_additional_thirteen_a_witness_and_notice(self):
        passage = self.resolver.resolve_standard(standard(145, 1, 21))
        self.assert_original_body(passage, [144])
        self.assertEqual([row["verse"] for row in passage.verses], list(range(1, 22)))
        blocks = passage.source["contentBlocks"]
        witness_index = next(i for i, block in enumerate(blocks) if block["kind"] == "witness")
        self.assertEqual((blocks[witness_index - 1]["verse"], blocks[witness_index + 1]["verse"]), (13, 14))
        witness = blocks[witness_index]
        self.assertEqual(witness["printedLabel"], "13a")
        self.assertEqual(witness["text"], self.resolver.rows[144, "13a"])
        self.assertTrue(witness["text"].startswith("πιστὸς Κύριος"))
        self.assertTrue(passage.includes_whole_verses)

    def test_whole_standard_13_keeps_both_trust_and_song_with_the_extra_closing_praise(self):
        passage = self.resolver.resolve_standard(standard(13, 1, 6))
        self.assert_original_body(passage, [12])
        self.assertEqual(passage.verses[4]["text"], self.resolver.rows[12, "5"])
        self.assertTrue(passage.verses[4]["text"].startswith("Ἐγὼ δὲ ἐπὶ τῷ ἐλέει"))
        self.assertEqual(passage.verses[5]["text"], self.resolver.rows[12, "6"])
        self.assertIn("τοῦ ὑψίστου", passage.verses[5]["text"])
        self.assertTrue(passage.includes_whole_verses)

    def test_partial_groups_unrelated_chapters_and_title_slots_remain_unavailable(self):
        cases = [standard(116, 12, 13), standard(116, 10, 18), standard(145, 1, 20),
                 standard(13, 5, 6), standard(116, 1, 19) + [("PSA", 117, 1)],
                 standard(145, 1, 21) + [("PSA", 145, 0)], [("PSA", 115, 1)],
                 [("PSA", 145, True)], [], [("GEN", 13, 1)]]
        for references in cases:
            with self.subTest(refs=references), self.assertRaises(Unavailable):
                self.resolver.resolve_standard(references)

    def test_dropped_printed_witness_or_last_source_row_cannot_be_declared_complete(self):
        for chapter, label in ((115, "4a"), (144, "13a"), (12, "6")):
            reviews = copy.deepcopy(self.reviews)
            reviews[chapter]["sourceLabels"].remove(label)
            with self.subTest(chapter=chapter), self.assertRaisesRegex(ValueError, "complete Greek Psalm body review"):
                Resolver(self.raw, load_reviews(), whole_reviews=reviews)

    def test_changed_original_words_group_memberships_or_source_digest_fail_closed(self):
        with self.assertRaisesRegex(ValueError, "source changed"):
            Resolver(self.raw + b"\n", load_reviews(), whole_reviews=self.reviews)
        for mode in ("digest", "membership", "boolean"):
            reviews = copy.deepcopy(self.reviews)
            if mode == "digest":
                reviews[115]["sourceBodySHA256"] = "0" * 64
                reason = "reviewed source digest"
            elif mode == "membership":
                reviews[115]["standardReferences"].pop()
                reason = "complete Greek Psalm body review"
            else:
                reviews[144]["standardReferences"][0][2] = True
                reason = "complete Greek Psalm body review"
            with self.subTest(mode=mode), self.assertRaisesRegex(ValueError, reason):
                Resolver(self.raw, load_reviews(), whole_reviews=reviews)

    def test_base_bible_importer_still_withholds_the_lettered_or_gapped_chapters(self):
        corpus, excluded = parse_source(self.raw)
        for chapter in (115, 144):
            self.assertNotIn(("PSA", chapter), corpus)
            self.assertIn(("PSA", chapter), excluded)
        self.assertEqual(len(load_reviews()), 9)


if __name__ == "__main__":
    unittest.main()

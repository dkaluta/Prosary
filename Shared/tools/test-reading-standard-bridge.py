#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Reference-only regressions for the STEP Standard/SIL-English boundary."""
import unittest

from reading_standard_bridge import standard_chapter_max, standard_to_sil_english
from reading_step_mapping import Unavailable
from reading_versification import SUPPORTED_BOOKS, Versification


class StandardBridgeTests(unittest.TestCase):
    def test_third_john_preserves_both_parts_of_the_standard_final_verse(self):
        self.assertEqual(standard_to_sil_english([("3JN", 1, 14)]),
                         ([("3JN", 1, 14), ("3JN", 1, 15)], False))
        with self.assertRaises(Unavailable):
            standard_to_sil_english([("3JN", 1, 15)])

    def test_revelation_keeps_the_cross_chapter_unit(self):
        self.assertEqual(standard_to_sil_english([("REV", 13, 1)]),
                         ([("REV", 12, 18), ("REV", 13, 1)], False))
        self.assertEqual(standard_to_sil_english([("REV", 12, 17), ("REV", 13, 1)]),
                         ([("REV", 12, 17), ("REV", 12, 18), ("REV", 13, 1)], False))
        with self.assertRaises(Unavailable):
            standard_to_sil_english([("REV", 12, 18)])

    def test_philippians_swap_requires_the_complete_pair(self):
        self.assertEqual(standard_to_sil_english([("PHP", 1, 16)]),
                         ([("PHP", 1, 16), ("PHP", 1, 17)], True))
        self.assertEqual(standard_to_sil_english([("PHP", 1, 16), ("PHP", 1, 17)]),
                         ([("PHP", 1, 16), ("PHP", 1, 17)], False))

    def test_unsupported_books_titles_and_endpoints_are_not_identities(self):
        for refs in ([], [("SIR", 28, 6)], [("SUS", 1, 1)], [("PSA", 3, 0)],
                     [("GEN", 0, 1)], [("GEN", 1, 32)], [("EST", "A", 1)], [("GEN", 1, True)]):
            with self.subTest(refs=refs), self.assertRaises(Unavailable):
                standard_to_sil_english(refs)

    def test_all_standard_chapter_endpoints_cover_the_sil_body_inventory(self):
        converter = Versification()
        expected = set()
        mapped = set()
        chapters = 0
        for (book, chapter), maximum in converter.tables["eng"].maxima.items():
            if book not in SUPPORTED_BOOKS:
                continue
            expected.update((book, chapter, verse) for verse in range(1, maximum + 1))
            for verse in range(1, standard_chapter_max(book, chapter) + 1):
                refs, _ = standard_to_sil_english([(book, chapter, verse)])
                mapped.update(refs)
                for target_book, target_chapter, target_verse in refs:
                    self.assertLessEqual(target_verse, converter.expected_chapter_max("eng", target_book, target_chapter))
            chapters += 1
        self.assertEqual(chapters, 1189)
        self.assertEqual(mapped, expected)


if __name__ == "__main__":
    unittest.main()

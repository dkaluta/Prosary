#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Network-free regressions for the inspected Delitzsch 1901 verse boundaries."""
import unittest

from delitzsch_numbering import chapter_matches, source_references


def verses(book, chapter, numbers):
    return [(book, chapter, verse) for verse in numbers]


class DelitzschNumberingTests(unittest.TestCase):
    def test_john_keeps_both_halves_of_the_disciples_question(self):
        self.assertEqual(source_references(verses("JHN", 1, [37, 38, 39, 51])),
                         verses("JHN", 1, [37, 38, 39, 40, 52]))

    def test_romans_keeps_the_thanksgiving_and_the_conclusion(self):
        self.assertEqual(source_references(verses("ROM", 7, [24, 25])),
                         verses("ROM", 7, [24, 25, 26]))

    def test_corinthians_keeps_both_knowledge_clauses_then_love(self):
        self.assertEqual(source_references(verses("1CO", 13, [11, 12, 13])),
                         verses("1CO", 13, [11, 12, 13, 14]))

    def test_thessalonians_keeps_the_blessing_signature_and_grace(self):
        self.assertEqual(source_references(verses("2TH", 3, [15, 16, 17, 18])),
                         verses("2TH", 3, [15, 16, 17, 18, 19]))

    def test_second_corinthians_combines_the_complete_greeting(self):
        self.assertEqual(source_references(verses("2CO", 13, [11, 12, 13, 14])),
                         verses("2CO", 13, [11, 12, 13]))

    def test_revelation_requires_both_sides_of_the_cross_chapter_merge(self):
        self.assertEqual(source_references([("REV", 12, 17), ("REV", 12, 18), ("REV", 13, 1), ("REV", 13, 2)]),
                         [("REV", 12, 17), ("REV", 13, 1), ("REV", 13, 2)])
        self.assertEqual(source_references(verses("REV", 13, [2, 18])), verses("REV", 13, [2, 18]))

    def test_partial_or_reordered_merged_units_are_unavailable(self):
        for references in (
            [("2CO", 13, 12)], [("2CO", 13, 13)],
            [("REV", 12, 18)], [("REV", 13, 1)],
            [("2CO", 13, 13), ("2CO", 13, 12)],
            [("REV", 13, 1), ("REV", 12, 18)],
            [("2CO", 13, 12), ("2CO", 13, 14), ("2CO", 13, 13)],
        ):
            with self.subTest(references=references), self.assertRaisesRegex(ValueError, "merged"):
                source_references(references)

    def test_ordinary_omissions_and_requested_order_are_preserved(self):
        references = [("JHN", 3, 18), ("JHN", 3, 16), ("ROM", 8, 1)]
        self.assertEqual(source_references(iter(references)), references)
        self.assertEqual(source_references([]), [])

    def test_bad_references_and_duplicate_appointments_are_rejected(self):
        for references in (
            [("JHN", 1, 52)], [("ROM", 7, 26)], [("GEN", 1, 1)],
            [("JHN", 99, 1)], [("JHN", 1, 0)], [("JHN", True, 1)],
            [("JHN", 1, True)], [("JHN", 1)], [None],
            [("JHN", 1, 38), ("JHN", 1, 38)],
        ):
            with self.subTest(references=references), self.assertRaises(ValueError):
                source_references(references)

    def test_full_chapters_have_no_missing_or_repeated_source_verses(self):
        for book, chapter, english_max, source_max in (
            ("JHN", 1, 51, 52), ("ROM", 7, 25, 26), ("1CO", 13, 13, 14),
            ("2CO", 13, 14, 13), ("2TH", 3, 18, 19),
        ):
            with self.subTest(book=book):
                self.assertEqual(source_references(verses(book, chapter, range(1, english_max + 1))),
                                 verses(book, chapter, range(1, source_max + 1)))
        self.assertEqual(source_references(verses("REV", 12, range(1, 19)) + verses("REV", 13, range(1, 19))),
                         verses("REV", 12, range(1, 18)) + verses("REV", 13, range(1, 19)))

    def test_chapter_inventory_checks_each_reviewed_maximum(self):
        for book, chapter, maximum in (
            ("JHN", 1, 52), ("ROM", 7, 26), ("1CO", 13, 14),
            ("2CO", 13, 13), ("2TH", 3, 19), ("REV", 12, 17),
            ("REV", 13, 18), ("LUK", 6, 49),
        ):
            with self.subTest(book=book, chapter=chapter):
                self.assertTrue(chapter_matches(book, chapter, range(1, maximum + 1)))
                self.assertFalse(chapter_matches(book, chapter, range(1, maximum)))
                self.assertFalse(chapter_matches(book, chapter, range(1, maximum + 2)))
                self.assertFalse(chapter_matches(book, chapter, [1] + list(range(1, maximum))))
                self.assertFalse(chapter_matches(book, chapter, [True] + list(range(2, maximum + 1))))
        self.assertFalse(chapter_matches("JHN", True, range(1, 53)))
        self.assertFalse(chapter_matches("JHN", 99, [1]))
        self.assertFalse(chapter_matches("GEN", 1, range(1, 32)))


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Offline regression checks for the pinned Scripture numbering conversion."""
from pathlib import Path
import shutil
import tempfile
import unittest

from reading_versification import (
    SYSTEMS, TABLE_DIRECTORY, Versification, chapter_matches,
    chapter_verse_count, map_reference,
)


class VersificationTests(unittest.TestCase):
    def test_torah_chapter_boundaries_follow_original_hebrew_numbers(self):
        cases = [
            (("GEN", 32, 1), "eng", ("GEN", 31, 55)),
            (("GEN", 32, 2), "vul", ("GEN", 32, 1)),
            (("EXO", 7, 26), "eng", ("EXO", 8, 1)),
            (("EXO", 8, 1), "rso", ("EXO", 8, 5)),
            (("EXO", 21, 37), "vul", ("EXO", 22, 1)),
            (("LEV", 5, 20), "eng", ("LEV", 6, 1)),
            (("LEV", 6, 1), "vul", ("LEV", 6, 8)),
            (("NUM", 12, 16), "vul", ("NUM", 13, 1)),
            (("NUM", 17, 1), "eng", ("NUM", 16, 36)),
            (("NUM", 17, 16), "rso", ("NUM", 17, 1)),
            (("DEU", 13, 1), "eng", ("DEU", 12, 32)),
            (("DEU", 23, 1), "vul", ("DEU", 22, 30)),
            (("DEU", 28, 69), "rso", ("DEU", 29, 1)),
        ]
        for original, system, expected in cases:
            with self.subTest(original=original, system=system):
                self.assertEqual(map_reference(*original, "org", system), [expected])
                self.assertEqual(map_reference(*expected, system, "org"), [original])

    def test_cross_tradition_mapping_uses_original_as_intermediate(self):
        self.assertEqual(map_reference("NUM", 29, 40, "eng", "vul"), [("NUM", 30, 1)])
        self.assertEqual(map_reference("NUM", 30, 1, "vul", "eng"), [("NUM", 29, 40)])

    def test_explicit_torah_merges_reject_every_involved_whole_verse(self):
        cases = [
            ("vul", [("GEN", 49, 31)], [("GEN", 49, 31), ("GEN", 49, 32)]),
            ("vul", [("GEN", 50, 22)], [("GEN", 50, 22), ("GEN", 50, 23)]),
            ("vul", [("EXO", 40, 13)], [("EXO", 40, 13), ("EXO", 40, 14), ("EXO", 40, 15)]),
            ("vul", [("NUM", 20, 28), ("NUM", 20, 29)], [("NUM", 20, 28)]),
            ("rso", [("LEV", 14, 55)], [("LEV", 14, 55), ("LEV", 14, 56)]),
            ("rso", [("NUM", 26, 1)], [("NUM", 25, 19), ("NUM", 26, 1)]),
        ]
        for system, sources, originals in cases:
            for source in sources:
                with self.subTest(system=system, source=source):
                    self.assertIsNone(map_reference(*source, system, "org"))
            for original in originals:
                with self.subTest(system=system, original=original):
                    self.assertIsNone(map_reference(*original, "org", system))
        self.assertEqual(map_reference("GEN", 49, 33, "org", "vul"), [("GEN", 49, 32)])
        self.assertEqual(map_reference("NUM", 20, 29, "org", "vul"), [("NUM", 20, 30)])

    def test_splits_documented_only_in_comments_do_not_become_identity(self):
        self.assertIsNone(map_reference("NUM", 26, 1, "eng", "org"))
        self.assertIsNone(map_reference("NUM", 25, 19, "org", "eng"))
        self.assertIsNone(map_reference("NUM", 26, 1, "org", "eng"))
        self.assertIsNone(map_reference("MAT", 17, 14, "vul", "org"))
        self.assertIsNone(map_reference("MAT", 17, 15, "org", "vul"))
        self.assertIsNone(map_reference("ACT", 19, 40, "eng", "org"))
        self.assertIsNone(map_reference("ACT", 19, 41, "eng", "org"))

    def test_new_testament_is_not_one_uniform_numbering_system(self):
        self.assertEqual(map_reference("MAT", 17, 15, "vul", "eng"), [("MAT", 17, 16)])
        self.assertEqual(map_reference("MRK", 8, 39, "vul", "eng"), [("MRK", 9, 1)])
        self.assertEqual(map_reference("JHN", 6, 53, "vul", "eng"), [("JHN", 6, 52)])
        self.assertEqual(map_reference("ACT", 7, 56, "vul", "eng"), [("ACT", 7, 57)])
        self.assertEqual(map_reference("ROM", 14, 24, "rso", "eng"), [("ROM", 16, 25)])
        for book, chapter, verse, system in [
            ("MRK", 4, 40, "vul"), ("JHN", 6, 51, "vul"),
            ("JHN", 6, 52, "vul"), ("ACT", 7, 55, "vul"),
            ("ACT", 14, 6, "vul"), ("2CO", 11, 32, "rso"),
            ("REV", 13, 1, "rso"),
        ]:
            self.assertIsNone(map_reference(book, chapter, verse, system, "org"))

    def test_common_old_testament_passages_remain_available(self):
        for source in SYSTEMS:
            for target in SYSTEMS:
                self.assertEqual(map_reference("ISA", 40, 1, source, target), [("ISA", 40, 1)])
        self.assertNotEqual(map_reference("PSA", 23, 1, "eng", "org"),
                            map_reference("PSA", 23, 1, "vul", "org"))
        self.assertNotEqual(map_reference("ISA", 9, 1, "eng", "org"),
                            map_reference("ISA", 9, 1, "org", "org"))

    def test_actual_chapter_keys_must_match_not_only_count_or_maximum(self):
        self.assertTrue(chapter_matches("eng", "GEN", 32, range(1, 33)))
        self.assertFalse(chapter_matches("org", "GEN", 32, range(1, 33)))
        self.assertFalse(chapter_matches("eng", "GEN", 32, [1] * 31 + [32]))
        self.assertFalse(chapter_matches("eng", "GEN", 32, [0] + list(range(2, 33))))
        self.assertFalse(chapter_matches("eng", "GEN", 32, [str(i) for i in range(1, 33)]))
        self.assertFalse(chapter_matches("eng", "GEN", 32, [True] + list(range(2, 33))))
        self.assertFalse(chapter_matches("eng", "3JN", 1, range(1, 15)))
        self.assertFalse(chapter_matches("eng", "REV", 12, range(1, 18)))
        self.assertEqual(chapter_verse_count("3JN", 1, "eng"), 15)

    def test_unsupported_bounds_segments_and_superscriptions_are_unavailable(self):
        for ref in [("GEN", 0, 1), ("GEN", 1, 32), ("GEN", 51, 1), ("GEN", 1, True),
                    ("GEN", 1, "1a"), ("PSA", 23, 0), ("TOB", 1, 1), ("SIR", 1, 1)]:
            self.assertIsNone(map_reference(*ref, "org", "eng"))
        self.assertIsNone(map_reference("GEN", 1, 1, "guess", "eng"))
        self.assertIsNone(map_reference("EST", 1, 1, "org", "vul"))

    def test_same_system_does_not_bypass_ambiguous_whole_verse_policy(self):
        self.assertEqual(map_reference("GEN", 1, 1, "eng", "eng"), [("GEN", 1, 1)])
        self.assertIsNone(map_reference("NUM", 26, 1, "eng", "eng"))

    def test_all_accepted_mappings_round_trip_without_aliases(self):
        converter = Versification()
        checked = 0
        for source in SYSTEMS:
            for target in SYSTEMS:
                for ref in converter.to_original[source]:
                    mapped = converter.map_reference(*ref, source, target)
                    if mapped is not None:
                        self.assertEqual(len(mapped), 1)
                        self.assertEqual(converter.map_reference(*mapped[0], target, source), [ref])
                        checked += 1
        self.assertGreater(checked, 450_000)

    def test_checksum_drift_stops_conversion_before_use(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "versification"
            shutil.copytree(TABLE_DIRECTORY, destination)
            with (destination / "eng.vrs.txt").open("ab") as stream:
                stream.write(b"\n# unreviewed edit\n")
            with self.assertRaisesRegex(ValueError, "checksum changed"):
                Versification(destination)


if __name__ == "__main__":
    unittest.main(verbosity=2)

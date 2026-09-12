#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Offline Psalm-numbering checks; test data contains no NABRE wording."""
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re
import unittest
import zipfile

from reading_psalm_mapping import (
    DRA_PSALM_SOURCE_OVERLAPS, dra_psalm_standard_overrides,
    nabre_psalm_to_standard,
)
from reading_versification import Versification

TOOLS = Path(__file__).resolve().parent
DRA_CACHE = TOOLS / '.scripture-cache' / 'daily-readings' / 'engDRA_vpl.zip'


class PsalmMappingTests(unittest.TestCase):
    def test_every_nabre_psalm_verse_has_a_standard_correspondence(self):
        converter = Versification()
        psalms = {chapter: maximum for (book, chapter), maximum
                  in converter.tables['org'].maxima.items() if book == 'PSA'}
        self.assertEqual(set(psalms), set(range(1, 151)))
        psalms[2] = 11  # USCCB's Psalm 2 merges the final Standard 11-12.
        for chapter, maximum in psalms.items():
            original = [('PSA', chapter, verse) for verse in range(1, maximum + 1)]
            targets, wider = nabre_psalm_to_standard(original)
            self.assertFalse(wider, chapter)
            self.assertEqual(len(targets), len(set(targets)), chapter)
            body = [verse for book, mapped_chapter, verse in targets if verse > 0]
            self.assertEqual(body, list(range(1, converter.tables['eng'].maxima[('PSA', chapter)] + 1)), chapter)

    def test_numbered_titles_and_psalm_thirteen_split_are_preserved(self):
        self.assertEqual(nabre_psalm_to_standard([('PSA', 3, 2)]), ([('PSA', 3, 1)], False))
        self.assertEqual(nabre_psalm_to_standard([('PSA', 51, 3)]), ([('PSA', 51, 1)], False))
        self.assertEqual(nabre_psalm_to_standard([('PSA', 13, 6)]),
                         ([('PSA', 13, 5), ('PSA', 13, 6)], False))
        for chapter in (51, 52, 54, 60):
            with self.subTest(chapter=chapter):
                self.assertEqual(nabre_psalm_to_standard([('PSA', chapter, 1)]),
                                 ([('PSA', chapter, 0)], True))
                self.assertEqual(nabre_psalm_to_standard([('PSA', chapter, 1), ('PSA', chapter, 2)]),
                                 ([('PSA', chapter, 0)], False))

    def test_whole_psalm_and_chapter_splits_are_not_applied_to_the_nabre_source(self):
        for chapter, verse in ((9, 21), (10, 1), (114, 8), (115, 1), (116, 10), (147, 12)):
            expected = verse - 1 if chapter == 9 else verse
            self.assertEqual(nabre_psalm_to_standard([('PSA', chapter, verse)]),
                             ([('PSA', chapter, expected)], False))

    def test_step_hebrew_rows_agree_with_the_original_to_standard_adapter(self):
        path = Path(__file__).with_name('versification') / 'step' / 'rules.json'
        checked = 0
        for _, source_type, source, standard, action, _ in json.loads(path.read_text())['rules']:
            if 'Hebrew' not in source_type.split('+'):
                continue
            source_match = re.fullmatch(r'Psa\.(\d+):(\d+)', source)
            target_match = re.fullmatch(r'Psa\.(\d+):(Title|\d+)(?:-(\d+))?', standard)
            if not source_match or not target_match:
                continue
            if action not in {'Keep verse', 'Renumber verse', 'Renumber title', 'Concatenation'}:
                continue
            chapter, verse = map(int, source_match.groups())
            if verse == 0:
                continue
            if chapter in {2, 66, 72, 109, 146}:
                continue  # NABRE has independently reviewed local differences.
            target_chapter = int(target_match[1])
            start = 0 if target_match[2] == 'Title' else int(target_match[2])
            end = int(target_match[3]) if target_match[3] else start
            expected = [('PSA', target_chapter, number) for number in range(start, end + 1)]
            self.assertEqual(nabre_psalm_to_standard([('PSA', chapter, verse)])[0], expected,
                             f'{source_type}: {source} -> {standard}')
            checked += 1
        self.assertGreater(checked, 2000)

    def test_nabre_local_numbering_is_not_assumed_to_equal_hebrew_labels(self):
        self.assertEqual(nabre_psalm_to_standard([('PSA', 2, 11)]),
                         ([('PSA', 2, 11), ('PSA', 2, 12)], False))
        with self.assertRaises(ValueError):
            nabre_psalm_to_standard([('PSA', 2, 12)])
        for chapter in (66, 72, 109):
            self.assertEqual(nabre_psalm_to_standard([('PSA', chapter, 1)]),
                             ([('PSA', chapter, 0)], False))
            self.assertEqual(nabre_psalm_to_standard([('PSA', chapter, 2)]),
                             ([('PSA', chapter, 1), ('PSA', chapter, 2)], False))
        self.assertEqual(nabre_psalm_to_standard([('PSA', 146, 2)]),
                         ([('PSA', 146, 1), ('PSA', 146, 2)], True))
        self.assertEqual(nabre_psalm_to_standard([('PSA', 146, 1), ('PSA', 146, 2)]),
                         ([('PSA', 146, 1), ('PSA', 146, 2)], False))

    def test_dra_clause_boundaries_use_minimal_source_envelopes(self):
        overrides = dra_psalm_standard_overrides()
        self.assertEqual(overrides[('PSA', 13, 0)], {('PSA', 12, 1)})
        self.assertEqual(overrides[('PSA', 13, 1)], {('PSA', 12, 1)})
        self.assertEqual(overrides[('PSA', 139, 2)], {('PSA', 138, 2), ('PSA', 138, 3)})
        self.assertEqual(overrides[('PSA', 139, 3)], {('PSA', 138, 3), ('PSA', 138, 4)})
        self.assertEqual(overrides[('PSA', 139, 4)], {('PSA', 138, 4), ('PSA', 138, 5)})
        self.assertEqual(overrides[('PSA', 139, 5)], {('PSA', 138, 5)})
        selected = {('PSA', 139, verse) for verse in range(2, 6)}
        sources = set().union(*(overrides[reference] for reference in selected))
        self.assertEqual(sources, {('PSA', 138, verse) for verse in range(2, 6)})
        self.assertEqual(set().union(*(DRA_PSALM_SOURCE_OVERLAPS[source] for source in sources)), selected)

    def test_invalid_references_do_not_fall_back_to_identity(self):
        for references in ([], [('PSA', 0, 1)], [('PSA', 151, 1)], [('PSA', 1, 0)],
                           [('PSA', 1, 7)], [('PSA', 1, True)], [('GEN', 1, 1)]):
            with self.subTest(references=references), self.assertRaises(ValueError):
                nabre_psalm_to_standard(references)


@unittest.skipUnless(DRA_CACHE.exists(), 'Pinned DRA source cache is not present')
class RealDraPsalmMappingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from reading_step_mapping import StepMapper
        manifest = json.loads((TOOLS / 'reading-text-sources.json').read_text())
        source = next(item for item in manifest['sources'] if item['id'] == 'engDRA')
        cls.corpus = defaultdict(dict)
        with zipfile.ZipFile(DRA_CACHE) as archive:
            raw = archive.read(source['member'])
            if hashlib.sha256(raw).hexdigest() != source['sha256']:
                raise AssertionError('The cached DRA source differs from its reviewed pin')
            for line in raw.decode('utf-8-sig').splitlines():
                match = re.fullmatch(r'PSA (\d+):(\d+) (.*)', line)
                if match:
                    chapter, verse = map(int, match.groups()[:2])
                    if verse in cls.corpus[('PSA', chapter)]:
                        raise AssertionError('Duplicate DRA Psalm source verse')
                    cls.corpus[('PSA', chapter)][verse] = match[3]
        cls.mapper = StepMapper(cls.corpus, 'douay-rheims-1899', overrides=DRA_PSALM_SOURCE_OVERLAPS)

    def test_every_nabre_psalm_reference_resolves_to_existing_dra_text(self):
        self.assertEqual(len(self.corpus), 150)
        self.assertEqual(sum(map(len, self.corpus.values())), 2530)
        checked = 0
        for (book, chapter), maximum in Versification().tables['org'].maxima.items():
            if book != 'PSA':
                continue
            if chapter == 2:
                maximum = 11
            for verse in range(1, maximum + 1):
                standard, _ = nabre_psalm_to_standard([(book, chapter, verse)])
                mapped, _ = self.mapper.from_standard(standard)
                self.assertTrue(mapped, (chapter, verse))
                self.assertEqual(len(mapped), len(set(mapped)))
                for target_book, target_chapter, target_verse in mapped:
                    self.assertIn(target_verse, self.corpus[(target_book, target_chapter)])
                checked += 1
        self.assertEqual(checked, 2526)

    def test_dra_chapter_splits_follow_the_actual_source(self):
        for reference, targets in self.mapper.forward.items():
            if 10 <= reference[1] <= 146:
                self.assertNotIn(reference, targets, 'A Latin Psalm must not leak into the same-number Hebrew Psalm')
        boundaries = [
            ((9, 21), (9, 21)), ((10, 1), (9, 22)),
            ((114, 8), (113, 8)), ((115, 1), (113, 9)),
            ((116, 9), (114, 9)), ((116, 10), (115, 1)),
            ((147, 11), (146, 11)), ((147, 12), (147, 1)),
            ((147, 20), (147, 9)),
        ]
        for (chapter, verse), (target_chapter, target_verse) in boundaries:
            standard, _ = nabre_psalm_to_standard([('PSA', chapter, verse)])
            self.assertEqual(self.mapper.from_standard(standard)[0], [('PSA', target_chapter, target_verse)])

    def test_dra_overlap_flags_distinguish_partial_and_complete_groups(self):
        self.assertEqual(self.mapper.from_standard([('PSA', 139, verse) for verse in range(1, 4)]),
                         ([('PSA', 138, verse) for verse in range(1, 5)], True))
        self.assertEqual(self.mapper.from_standard([('PSA', 139, verse) for verse in range(2, 6)]),
                         ([('PSA', 138, verse) for verse in range(2, 6)], False))
        self.assertEqual(self.mapper.from_standard([('PSA', 13, 0)]), ([('PSA', 12, 1)], True))
        self.assertEqual(self.mapper.from_standard([('PSA', 13, 0), ('PSA', 13, 1)]),
                         ([('PSA', 12, 1)], False))

    def test_dra_source_titles_and_local_boundaries_are_not_body_verse_identities(self):
        self.assertEqual(self.mapper.from_standard([('PSA', 66, 0)]), ([('PSA', 65, 1)], True))
        self.assertEqual(self.mapper.from_standard([('PSA', 72, 0)]), ([('PSA', 71, 1)], False))
        self.assertEqual(self.mapper.from_standard([('PSA', 72, 1), ('PSA', 72, 2)]),
                         ([('PSA', 71, 2)], False))
        self.assertEqual(self.mapper.from_standard([('PSA', 109, 1), ('PSA', 109, 2)]),
                         ([('PSA', 108, 2), ('PSA', 108, 3)], True))
        self.assertEqual(self.mapper.from_standard([('PSA', 146, 3)]),
                         ([('PSA', 145, 2), ('PSA', 145, 3)], True))


if __name__ == '__main__':
    unittest.main()

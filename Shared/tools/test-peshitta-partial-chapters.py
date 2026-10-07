#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Valid source verses survive an unrelated defective verse without filling its gap."""
import hashlib
import json
from pathlib import Path
import unittest
from unittest.mock import patch
import zipfile
from peshitta_eu_source import load_verses, parse_chapter, partial_chapter, review
from reading_edition_mapping import mapper
from reading_step_mapping import Unavailable

ROOT = Path(__file__).resolve().parents[2]


class PartialChapterTests(unittest.TestCase):
    def test_omission_is_not_scripture_and_valid_neighbours_keep_numbers(self):
        raw = ('<span class="verse" id="v1" data-ref="job.42.1">1 ܐܰܒܳܐ</span>'
               '<span class="verse" id="v2" data-ref="job.42.2">2 (ܠܝܬ)</span>'
               '<span class="verse" id="v3" data-ref="job.42.3">3 ܐܰܒܳܐ</span>').encode()
        with self.assertRaises(ValueError): parse_chapter(raw, 'job', 42)
        values, omissions = partial_chapter(raw, 'job', 42)
        self.assertEqual(values, {1: 'ܐܰܒܳܐ', 3: 'ܐܰܒܳܐ'})
        self.assertEqual(set(omissions), {'2'})
        source = dict(book='JOB', chapter=42, slug='job', sha256=hashlib.sha256(raw).hexdigest())
        metadata = dict(excludedChapters={}, partialChapters={'JOB:42': {
            'omittedVerses': omissions, 'sourceSHA256': source['sha256'], 'retainedVerses': 2}})
        with patch('peshitta_eu_source.review', return_value=metadata):
            self.assertEqual(set(load_verses(source, raw)), {(42, 1), (42, 3)})
            metadata['partialChapters']['JOB:42']['omittedVerses'] = {}
            with self.assertRaisesRegex(ValueError, 'defects differ'): load_verses(source, raw)

    def test_bad_numbering_still_withholds_whole_chapter(self):
        raw = b'<span class="verse" id="v2" data-ref="job.42.2">2 text</span>'
        with self.assertRaisesRegex(ValueError, 'verse labels'): partial_chapter(raw, 'job', 42)

    def test_partial_reviews_pin_source_and_retained_inventory(self):
        raw = ('<span class="verse" id="v1" data-ref="job.42.1">1 ܐܰܒܳܐ</span>'
               '<span class="verse" id="v2" data-ref="job.42.2">2 (ܠܝܬ)</span>').encode()
        values, omissions = partial_chapter(raw, 'job', 42)
        digest = hashlib.sha256(raw).hexdigest()
        source = dict(book='JOB', chapter=42, slug='job', sha256=digest)
        metadata = dict(excludedChapters={}, partialChapters={'JOB:42': {
            'omittedVerses': omissions, 'sourceSHA256': '0'*64, 'retainedVerses': 1}})
        with patch('peshitta_eu_source.review', return_value=metadata):
            with self.assertRaisesRegex(ValueError, 'source differs'): load_verses(source, raw)
            metadata['partialChapters']['JOB:42']['sourceSHA256'] = digest
            metadata['partialChapters']['JOB:42']['retainedVerses'] = 2
            with self.assertRaisesRegex(ValueError, 'retained inventory'): load_verses(source, raw)

    def test_wrong_references_duplicates_and_markup_do_not_become_partial_text(self):
        for raw, reason in [
            ('<span class="verse" id="v1" data-ref="job.41.1">1 ܐܰܒܳܐ</span>', 'wrong book/chapter'),
            ('<span class="verse" id="v1" data-ref="job.42.1">1 ܐܰܒܳܐ</span>'*2, 'repeats'),
            ('<span class="verse" id="v1" data-ref="job.42.1">1 <b>ܐܰܒܳܐ</b></span>', 'unsupported inline'),
        ]:
            with self.subTest(reason=reason), self.assertRaisesRegex(ValueError, reason):
                partial_chapter(raw.encode(), 'job', 42)

    def test_committed_archive_declares_every_recovered_chapter_partial(self):
        catalog = json.loads((ROOT/'Shared/data/bible-catalog.json').read_text())
        edition = next(row for row in catalog['editions'] if row['id']=='peshitta-1905')
        archive = ROOT/'Shared/dist/bibles'/edition['downloadURL'].rsplit('/',1)[1]
        with zipfile.ZipFile(archive) as handle:
            for key, metadata in review()['partialChapters'].items():
                book, chapter = key.split(':')
                path = next(name for name in handle.namelist() if name.endswith(f'{book}/{chapter}.json'))
                row = json.loads(handle.read(path))
                book_metadata = next(value for value in edition['books'] if value['id'] == book)
                chapter_metadata = next(value for value in book_metadata['chapters'] if value['number'] == int(chapter))
                self.assertFalse(chapter_metadata['isComplete'], key)
                self.assertEqual(len(row['verses']), metadata['retainedVerses'], key)
                self.assertFalse({int(v) for v in metadata['omittedVerses']} & {v['verse'] for v in row['verses']})

    def test_recovered_browse_units_never_create_unreviewed_daily_correspondences(self):
        subject = mapper('peshitta-1905')
        catalog = json.loads((ROOT/'Shared/data/bible-catalog.json').read_text())
        edition = next(row for row in catalog['editions'] if row['id']=='peshitta-1905')
        archive = ROOT/'Shared/dist/bibles'/edition['downloadURL'].rsplit('/',1)[1]
        with zipfile.ZipFile(archive) as handle:
            for key in review()['partialChapters']:
                book, chapter = key.split(':')
                row = json.loads(handle.read(f'chapters/{book}/{chapter}.json'))
                for verse in row['verses']:
                    with self.subTest(reference=(book, int(chapter), verse['verse'])):
                        with self.assertRaises(Unavailable):
                            subject.to_standard([(book, int(chapter), verse['verse'])])


if __name__ == '__main__': unittest.main()

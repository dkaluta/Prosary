#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Offline structural and source-preservation checks for vocalized Delitzsch."""
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from delitzsch_source import parse_chapter, apply_reviewed_corrections, source_reviews


class SourceTests(unittest.TestCase):
    def test_only_verse_bodies_are_read_and_source_marks_survive(self):
        html = '<nav>Not Scripture</nav><article><header>Heading</header><p id="1">נִסָּיוֹן יְהוָ֥ה׃<span class="v" id="2"><a href="#2">2</a></span> טֶקְסְט <em>נִסָּיוֹן</em>׃</article><nav>Next chapter</nav>'
        self.assertEqual(parse_chapter(html.encode()), {1: 'נִסָּיוֹן יְהוָ֥ה׃', 2: 'טֶקְסְט נִסָּיוֹן׃'})

    def test_missing_repeated_unpointed_and_unterminated_verses_fail(self):
        for html in ('<article><p id="1">טקסט</article>',
                     '<article><p id="2">טֶקְסְט</article>',
                     '<article><p id="1">טֶקְסְט<span class="v" id="1">1</span>נִסָּיוֹן</article>',
                     '<article><p id="1">טֶקְסְט', '<nav>טֶקְסְט</nav>'):
            with self.subTest(html=html), self.assertRaises(ValueError):
                parse_chapter(html.encode())

    def test_reviewed_correction_is_exact_and_bound_to_its_source(self):
        review = {'sourceId':'fixture','sourceSHA256':'pin','verse':2,'before':'before','after':'after'}
        with patch('delitzsch_source.source_reviews', return_value=[review]):
            verses = {1:'before', 2:'text before end'}
            self.assertEqual(apply_reviewed_corrections({'id':'fixture','sha256':'pin'},verses),
                             {1:'before',2:'text after end'})
            self.assertEqual(verses[2], 'text before end')
            self.assertEqual(apply_reviewed_corrections({'id':'other','sha256':'pin'},verses),verses)
            for source, data in [({'id':'fixture','sha256':'changed'},verses),
                                 ({'id':'fixture','sha256':'pin'},{2:'missing'})]:
                with self.assertRaises(ValueError):
                    apply_reviewed_corrections(source,data)

    def test_every_transcription_correction_has_printed_page_evidence_and_pin(self):
        lock=json.loads((Path(__file__).parent/'reading-text-sources.json').read_text())
        pins={source['id']:source['sha256'] for source in lock['sources']}
        for review in source_reviews():
            self.assertEqual(review['sourceSHA256'],pins[review['sourceId']])
            self.assertTrue(review['before'] and review['after'])
            self.assertGreater(review['evidence']['pdfPage'],0)
            self.assertGreater(review['evidence']['printedPage'],0)
            self.assertTrue(review['evidence']['url'].startswith('https://archive.org/'))
            self.assertEqual(len(review['evidence']['sha256']),64)


if __name__ == '__main__':
    unittest.main()

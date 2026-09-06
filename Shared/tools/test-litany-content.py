#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Protect contextual Litany endings, credited Hebrew transcription, and scraped-text cleanup."""
import importlib.util
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
BUNDLE = ROOT / 'Shared/content/litanyOfLoreto'


def read(path):
    return json.loads(path.read_text())


def presentation_normalized_hebrew(text):
    text = re.sub('י[\u0591-\u05c7]*ה[\u0591-\u05c7]*ו[\u0591-\u05c7]*ה[\u0591-\u05c7]*', 'יהוה', text)
    return ' '.join(text.split())


class LitanyContentTests(unittest.TestCase):
    def test_each_supported_language_has_both_complete_exclusive_forms(self):
        manifest = read(BUNDLE / 'manifest.json')
        variants = read(BUNDLE / 'devotion.json')['variants']
        self.assertEqual(['standard', 'afterRosary'], [v['id'] for v in variants])
        self.assertEqual(variants[0]['steps'][:-1], variants[1]['steps'][:-1])
        self.assertEqual('collectStandard', variants[0]['steps'][-1]['bodyKey'])
        self.assertEqual('collectAfterRosary', variants[1]['steps'][-1]['bodyKey'])
        for language in manifest['languages']:
            with self.subTest(language=language):
                content = read(BUNDLE / f'content/{language}.json')
                text = content['prayers']
                self.assertTrue(content.get('$sources'))
                self.assertNotEqual(text['collectStandard'], text['collectAfterRosary'])
                for variant in variants:
                    self.assertEqual(1, sum(s['bodyKey'].startswith('collect') for s in variant['steps']))
                    for step in variant['steps']:
                        self.assertTrue(text[step['titleKey']].strip())
                        self.assertTrue(text[step['bodyKey']].strip())

    def test_erez_words_and_two_collects_are_preserved(self):
        original = read(BUNDLE / 'sources/erez-he.json')['prayers']
        actual = read(BUNDLE / 'content/he.json')['prayers']
        for number in range(1, 16):
            key = f'step{number:02}Body'
            self.assertEqual(presentation_normalized_hebrew(original[key]),
                             presentation_normalized_hebrew(actual[key]))
        combined = original['step16Body']
        standard, after = combined.split('אם תחנון זה נעשה בסוף המחרוזת, עושים סגירה זו:')
        standard = standard.split('אם תחנון זה נעשה כתפילה רגילה, עושים סגירה זו:')[1]
        for key, source in [('collectStandard', standard), ('collectAfterRosary', after)]:
            self.assertEqual(presentation_normalized_hebrew(source),
                             presentation_normalized_hebrew(actual[key]))
            self.assertNotIn('אם תחנון זה', actual[key])
        self.assertNotIn('יְהוָה', json.dumps(actual, ensure_ascii=False))

    def test_departed_response_matches_erez(self):
        rosary = read(ROOT / 'Shared/content/rosary/content/he.json')['prayers']
        self.assertEqual('̷א. מִי־יִתֵּן וְהֵם יָנוּחוּ בְּשָׁלוֹם.\n̷מ. אָמֵן.',
                         rosary['requiescantInPace'])

    def test_pointed_hebrew_website_navigation_is_detected(self):
        spec = importlib.util.spec_from_file_location('audit', Path(__file__).with_name('audit-content.py'))
        audit = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(audit)
        bad = {'prayers': {'body': 'פֶּרֶק הַבָּא, הַבְּשׂוֹרָה הַקְּדוֹשָׁה עַל־פִּי לוּקָס'}}
        self.assertTrue(audit.website_contaminants(bad))
        self.assertFalse(audit.website_contaminants({'prayers': {'body': 'וְהַקֶּבֶר קָרוֹב׃'}}))


if __name__ == '__main__':
    unittest.main()

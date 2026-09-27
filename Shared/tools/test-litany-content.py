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
    def test_rosary_litany_precedes_one_separate_rosary_collect(self):
        rosary = ROOT / 'Shared/content/rosary'
        closing = read(rosary / 'devotion.json')['closing']
        litany = next(i for i, step in enumerate(closing) if step.get('kind') == 'rosaryLitany')
        self.assertEqual({'kind': 'rosaryLitany', 'if': 'litanyOfLoreto'}, closing[litany])
        self.assertEqual('rosaryCollect', closing[litany + 1]['bodyKey'])
        self.assertEqual('rosaryCollect', closing[litany + 1]['if'])
        self.assertTrue(all(s['bodyKey'].startswith('signumCrucis') for s in closing[litany + 2:]))
        self.assertEqual(1, sum(s.get('bodyKey') == 'rosaryCollect' for s in closing))
        options = {o['key']: o for o in read(rosary / 'options.json')['options']}
        self.assertFalse(options['litanyOfLoreto']['default'])
        self.assertTrue(options['rosaryCollect']['default'])
        for key in ('litanyOfLoreto', 'rosaryCollect'):
            self.assertEqual({'he', 'ar', 'ru', 'tl', 'fr', 'it', 'uk'}, set(options[key]['nameByLanguage']))

    def test_separate_rosary_collect_reuses_sourced_words_and_preserves_basic_antiphon_collects(self):
        rosary = ROOT / 'Shared/content/rosary/content'
        for path in rosary.glob('*.json'):
            language = path.stem
            actual = read(path)
            prayers = actual['prayers']
            if language == 'arc':
                self.assertNotIn('rosaryCollect', prayers)  # No invented Syriac collect.
                continue
            if language in {'es', 'he-x-gamliel'}:
                source_language = 'he' if language == 'he-x-gamliel' else language
                expected = read(BUNDLE / f'content/{source_language}.json')['prayers']['collectAfterRosary']
            else:
                # The original remains available to a standalone Marian antiphon.
                expected = prayers['collectaStandard']
                self.assertTrue(prayers['collectaPaschale'])
            with self.subTest(language=language):
                self.assertEqual(expected, prayers['rosaryCollect'])
                self.assertTrue(prayers['rosaryCollectTitle'])
                if language.startswith('he'):
                    self.assertEqual('נתפללה', prayers['rosaryCollectTitle'])
        self.assertEqual('vicariate', read(rosary / 'he.json')['$prayerTraditionByKey']['rosaryCollect'])
        self.assertEqual('נתפללה', read(BUNDLE / 'content/he.json')['prayers']['collectTitle'])

    def test_hebrew_oremus_headings_use_the_requested_form_in_every_bundle(self):
        found = set()
        for latin in (ROOT / 'Shared/content').glob('*/content/la.json'):
            hebrew = latin.with_name('he.json')
            if not hebrew.exists():
                continue
            headings = read(hebrew)['prayers']
            for key, value in read(latin)['prayers'].items():
                if key.endswith('Title') and value.strip().casefold().rstrip('.') == 'oremus':
                    self.assertEqual('נתפללה', headings[key], str(hebrew) + ':' + key)
                    found.add(latin.parent.parent.name)
        self.assertTrue({'angelus', 'rosary', 'litanyOfLoreto'} <= found)

    def test_supported_forms_preserve_their_own_sourced_collect(self):
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
                # Both contextual endings now have published Ukrainian text as well;
                # a fallback must not silently replace either advertised prayer body.
                required = {step['bodyKey'] for variant in variants for step in variant['steps']}
                self.assertFalse(required - text.keys())
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

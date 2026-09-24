#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Keep mystery names/fruits complete without treating a fallback as a translation."""
import importlib.util
import json
from pathlib import Path
import re

from aramaic_script_converter import to_hebrew

TOOLS = Path(__file__).resolve().parent
CONTENT = TOOLS.parent / 'content'
spec = importlib.util.spec_from_file_location('coverage', TOOLS / 'audit-prayer-coverage.py')
coverage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(coverage)
report = coverage.inventory()
for pack in ('rosary', 'franciscanCrown', 'sevenSorrows'):
    for language, row in report['packs'][pack].items():
        for field in ('title', 'fruit'):
            assert not row['missing_mysteries'][field], (pack, language, field, row['missing_mysteries'][field])
    data = json.loads((CONTENT / pack / 'content/arc.json').read_text())
    assert 'editorial' in data['$metadataSource']
    for key, entry in data['mysteries'].items():
        for field in ('title', 'fruit'):
            alternate = entry['transliterated' + field.title()]
            assert re.search(r'[ܐ-ܬ]', alternate), (pack, key, field)
            assert not re.search(r'[א-ת]', alternate), (pack, key, field)
            assert entry[field] == to_hebrew(alternate, keep_plural_dots=False), (pack, key, field)
        # Imported Scripture must retain its source and paired script track.
        if key in data['$scriptureImport']['mysteryKeys']:
            assert 'פשיטתא' in entry['description'], (pack, key)
            assert 'ܦܫܝܛܬܐ' in entry['transliteratedDescription'], (pack, key)
        elif 'description' in entry:
            assert entry['description'] == to_hebrew(entry['transliteratedDescription'], keep_plural_dots=False), (pack, key)
            credit = data['$editorialTranslations']['mysteries.' + key + '.description']
            assert 'not a quotation from Scripture' in credit, (pack, key)
print('Mystery names and fruits: all 12 prayer languages; Aramaic pairs and Scripture provenance passed.')

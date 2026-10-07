#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Pin contributor-supplied prayer wording, scripts and distinct attribution."""
import json
from pathlib import Path

tools = Path(__file__).resolve().parent
shared = tools.parent
fixture = json.loads((tools / 'fixtures/contributor-prayer-corrections.json').read_text())
for record in fixture['prayers']:
    content = json.loads((shared / f"content/rosary/content/{record['language']}.json").read_text())
    assert content[record['field']][record['key']] == record['text'], record['key']
    assert content['$contributorCorrections']['credit'] == fixture['credit']
    assert content['$contributorCorrections']['suppliedOn'] == fixture['suppliedOn']
    assert f"{record['field']}.{record['key']}" in content['$contributorCorrections']['fields']
    if record['field'] == 'prayers':
        assert content['$sources'][record['key']] == fixture['credit']

arc = json.loads((shared / 'content/rosary/content/arc.json').read_text())
assert any('\u0700' <= char <= '\u074f' for char in arc['prayers']['oratioFatimae'])
assert not any('\u0590' <= char <= '\u05ff' for char in arc['prayers']['oratioFatimae'])
assert 'oratioFatimae' not in arc['transliterations']
assert 'Smelova' in arc['$comment']
assert 'manchester.ac.uk' in arc['$sources']['subTuumPraesidium']
options = json.loads((shared / 'content/rosary/options.json').read_text())['options']
assert 'skipFifthDecade' not in {entry['key'] for entry in options}
print('PASS: five supplied prayer corrections, original Syriac script, distinct source credits, and full-decade Rosary options')

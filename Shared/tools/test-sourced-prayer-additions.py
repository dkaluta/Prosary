#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Protect newly verified prayer wording, seasonal assembly and exact source credit."""
import hashlib
import json
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
CONTENT = TOOLS.parent / 'content'
fixture = json.loads((TOOLS / 'fixtures/sourced-prayer-additions.json').read_text())


def read(pack, language):
    return json.loads((CONTENT / pack / 'content' / f'{language}.json').read_text())


def digest(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


rosary = read('rosary', 'el')
opening = fixture['greekInvitatory']
assert rosary['prayers']['invitatoryBodyLent'] == opening['lentText']
assert rosary['prayers']['invitatoryBody'] == opening['lentText'] + ' ' + opening['alleluia']
assert opening['alleluia'] not in rosary['prayers']['invitatoryBodyLent']
for key in ('invitatoryBody', 'invitatoryBodyLent'):
    assert rosary['$sources'][key] == opening['source']
assert '1823' in rosary['$comment'] and 'p. 7' in rosary['$comment']

stations = read('stationsOfTheCross', 'el')
acclamation = fixture['greekStationsAcclamation']
body = stations['prayers']['stationsAcclamation']
assert digest(body) == acclamation['renderedSha256']
assert len(body.replace('**', '').split()) == acclamation['excerptWordCount']
assert stations['$sources']['stationsAcclamation'] == acclamation['source']
assert '2019' in stations['$prayerSource']

sorrows = read('sevenSorrows', 'es')
closing = fixture['spanishSorrowsClosing']
devotion = json.loads((CONTENT / 'sevenSorrows/devotion.json').read_text())
closing_key = next(step['bodyKey'] for step in devotion['closing']
                   if step.get('titleKey') == 'sevenSorrowsClosingTitle')
assert closing_key == 'sevenSorrowsClosingBody'
response, collect = sorrows['prayers'][closing_key].split('\n\nOremos. ')
assert digest(response) == closing['responseSha256']
assert len(response.replace('**', '').split()) == closing['responseWordCount']
assert collect == closing['collectText']
for source in ('collectSource', 'responseSource'):
    assert closing[source] in sorrows['$sources'][closing_key]
assert '1851' in sorrows['$prayerSource']
assert 'Madre nuestra' in collect and 'por la muerte' in collect
assert 'intercesion de todos los santos' in collect
assert 'not supplied' not in sorrows['$comment']

print('Verified Greek openings, Greek Stations response and historical Spanish Sorrows closing passed.')

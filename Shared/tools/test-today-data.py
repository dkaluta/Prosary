#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Check offline Today contracts against source fixtures and every native asset copy."""
import datetime as dt
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / 'Shared/data'
TARGETS = [ROOT / 'iOS/Prosary/Data', ROOT / 'Android/app/src/main/assets/data', ROOT / 'Windows/Prosary/Data']
LANGUAGES = {'he', 'ar', 'ru', 'tl', 'fr', 'it'}


def read(name):
    return json.loads((DATA / f'{name}.json').read_text())


def translations(value, description):
    assert LANGUAGES <= value.keys(), f'{description}: missing {LANGUAGES - value.keys()}'
    assert all(isinstance(value[code], str) and value[code].strip() for code in LANGUAGES), description


def full(name, date):
    return [item['full'] for item in read(name)['days'][date]['readings']]


def main():
    registry = read('calendars')
    assert [c['id'] for c in registry['calendars']] == ['lpj', 'roman', 'roman1962', 'ugcc', 'syriac', 'maronite']
    feast_files, reading_files = set(), set()
    for calendar in registry['calendars']:
        translations(calendar['nameByLanguage'], calendar['id'])
        for choice in [calendar, *calendar.get('paschaVariants', {}).values()]:
            feast_files.add(choice['file'])
            reading_files.add(choice['readingsFile'])
    feast_count = citation_count = 0
    for name in sorted(feast_files):
        dataset = read(name)
        assert dataset['days'], name
        for date, day in dataset['days'].items():
            dt.date.fromisoformat(date)
            translations(day['titleByLanguage'], f'{name}/{date}/{day["title"]}')
            if 'Pentecost' in day['title']:
                assert 'שבועות' in day['titleByLanguage']['he'], (name, date, day['titleByLanguage']['he'])
            feast_count += 1
    for name in sorted(reading_files):
        for date, day in read(name)['days'].items():
            dt.date.fromisoformat(date)
            assert day['readings'], (name, date)
            for item in day['readings']:
                assert item['type'] in {'reading', 'psalm', 'gospel'}, (name, date)
                assert ':' in item['full'] and '\n' not in item['full'], (name, date, item['full'])
                for field in ['shortByLanguage', 'fullByLanguage']:
                    translations(item[field], f'{name}/{date}/{field}')
                citation_count += 1
    # User's dated counterexample and the distinct published Gregorian usage.
    assert full('readings-ugcc', '2026-09-06') == ['2 Corinthians 1:21–2:4', 'Matthew 22:1–14']
    assert full('readings-ugcc-gregorian', '2026-09-06') == ['2 Corinthians 4:6–15', 'Matthew 22:35–46']
    assert read('feasts-ugcc')['days']['2026-09-06']['title'] == '14th Sunday after Pentecost'
    assert read('feasts-ugcc-gregorian')['days']['2026-09-06']['title'] == '15th Sunday after Pentecost'
    assert read('feasts-ugcc')['days']['2026-01-25']['title'] == 'Sunday of Zacchaeus; Saint Gregory the Theologian'
    assert read('feasts-ugcc-gregorian')['days']['2026-01-18']['title'] == 'Sunday of Zacchaeus'
    for name in ['feasts-ugcc', 'feasts-ugcc-gregorian']:
        for date in ['2026-11-08', '2026-12-06', '2027-01-17', '2027-07-11', '2027-08-29']:
            assert 'Sunday' in read(name)['days'][date]['title'], (name, date)
    assert full('readings-roman1962', '2026-09-06') == ['Galatians 5:25–26; 6:1–10', 'Luke 7:11–16']
    vetus = read('readings-roman1962')['days']
    assert sum(date.startswith('2026-') for date in vetus) == 365
    assert all(any(r['type'] == 'gospel' for r in day['readings']) for day in vetus.values())
    for date, count in [('2026-04-03', 3), ('2026-04-04', 6), ('2026-05-30', 7),
                        ('2026-11-02', 6), ('2026-12-25', 6)]:
        assert len(vetus[date]['readings']) == count, (date, vetus[date])
    assert full('readings-syriac', '2026-09-06') == ['1 Thessalonians 2:13–20; 3:1–5', 'Luke 11:33–41']
    assert full('readings-maronite', '2026-09-06') == ['Amos 5:21–24', 'Romans 8:18–27', 'Luke 18:9–14']
    assert [r['type'] for r in read('readings-maronite')['days']['2026-09-06']['readings']] == ['reading', 'reading', 'gospel']
    assert not {'2026-02-18', '2026-02-20'} & read('readings-ugcc')['days'].keys()
    # Native picker can navigate beyond source coverage, which must remain an absent row.
    assert all('2031-08-01' not in read(name)['days'] for name in reading_files)
    torah = read('torah-portions')
    assert torah['region'] == 'IL'
    for date, portion in torah['days'].items():
        chosen, saturday = dt.date.fromisoformat(date), dt.date.fromisoformat(portion['saturday'])
        assert saturday.weekday() == 5 and 0 <= (saturday - chosen).days <= 6
        for item in portion['readings']:
            assert item['full'].split()[0] in {'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy'}
            translations(item['fullByLanguage'], f'Torah/{date}')
    assert torah['days']['2026-09-06']['saturday'] == '2026-09-12'
    assert torah['days']['2026-09-06']['isHoliday']
    assert 'Nasso' in torah['days']['2026-05-23']['title']  # Israel differs from diaspora here.
    for path in DATA.glob('*.json'):
        for target in TARGETS:
            assert path.read_bytes() == (target / path.name).read_bytes(), f'Native asset drift: {target / path.name}'
    print(f'Today data passed: {len(registry["calendars"])} calendars, {len(feast_files)} feast tables, '
          f'{feast_count} localized dates, {citation_count} citations, {len(torah["days"])} Israel Torah dates, 3 matching native copies')


if __name__ == '__main__':
    main()

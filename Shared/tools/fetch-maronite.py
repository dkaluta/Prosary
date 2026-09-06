#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["requests"]
# ///
"""Refresh Maronite calendar names and citations from Evangelizo's MAE edition.

Each source day is downloaded once, reused by the existing feast/readings parsers, and
cached outside the repository. Only titles, canonical ranks and references are shipped;
Scripture, commentary, biographies and prayers are never copied into the datasets.
Run --start 2026-01-01 --end 2026-12-31 --cache /tmp/prosary-maronite-cache --sync.
The source has a rolling horizon. Missing dates stay missing, never borrowing another rite.
"""
from __future__ import annotations
import argparse
import datetime as dt
import importlib.util
import json
from pathlib import Path
import re
import shutil
import sys
import time
import requests

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / 'Shared' / 'data'


def module(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    value = importlib.util.module_from_spec(spec)
    sys.modules[name] = value
    spec.loader.exec_module(value)
    return value


def rank(title: str) -> str:
    if title in {'Pentecost', 'Pentecost Sunday', 'Easter Sunday', 'Great Sunday of the Resurrection'}:
        return 'Great Feast'
    if 'Sunday' in title:
        return 'Sunday'
    if title == 'Thursday of the Mysteries' or re.search(r'\b(?:(?:Great|Holy) (?:Friday|Thursday|Saturday)|Passion week)\b', title, re.I):
        return 'Holy Week'
    if title == 'Ash Monday' or 'Fast' in title or 'Lent' in title:
        return 'Fast'
    return 'Feast'


def is_ferial(title: str) -> bool:
    """MAE prints season/week labels for ordinary weekdays; these are not feast ranks.
    Keep distinct named days of Holy Week and source feasts such as Ash Monday.
    The two misspellings are actual publication titles, not alternative identities."""
    if title == 'Thursday of the Mysteries' or re.search(r'\b(?:Holy|Great|Passion) Week\b',title,re.I):
        return False
    return bool(re.match(r'^(?:Monday|Tuesday|Wednesday|Wednesay|Thursday|Friday|Saturday|Saturay) (?:of|after|before|in) ',title)
        or re.match(r'^(?:First|Second|Third|Fourth|Fifth|Sixth|Seventh|Eighth|Ninth|Tenth) day after ',title)
        or re.match(r'^The [\w-]+ day of [A-Z][a-z]+$',title))


def localize(feasts: dict, readings: dict, feast_module, reading_module) -> None:
    for day in [day for day,row in feasts.items() if is_ferial(row['title'])]:
        del feasts[day]
    catalog_path = Path(__file__).with_name('feast-titles-maronite.json')
    if catalog_path.exists():
        catalog = json.loads(catalog_path.read_text())['titles']
        for row in feasts.values():
            if row['title'] in catalog:
                row.setdefault('titleByLanguage', {}).update({k:v for k,v in catalog[row['title']].items() if k in ['en','he','ar','ru','tl','fr','it']})
    missing_titles = sorted({row['title'] for row in feasts.values()
        if any(not row.get('titleByLanguage',{}).get(language) for language in ['en','he','ar','ru','tl','fr','it'])})
    if missing_titles:
        raise ValueError(f'Add editorial display translations to feast-titles-maronite.json for: {missing_titles}')
    hebrew = json.loads(reading_module.HEBREW_BOOKS_FILE.read_text())['books']
    other = json.loads(reading_module.LOCALIZED_BOOKS_FILE.read_text())['books']
    missing_he = reading_module.localize_hebrew_readings(readings, hebrew)
    missing_other = reading_module.localize_reading_names(readings, other)
    if missing_he or missing_other:
        raise ValueError(f'Missing sourced Bible book metadata: {missing_he | missing_other}')


def self_test() -> None:
    assert rank('Sixteenth Sunday of Pentecost: Parable of the Pharisee and the Tax Collector') == 'Sunday'
    assert rank('Pentecost Sunday') == 'Great Feast'
    assert rank('Pentecost') == 'Great Feast'
    assert rank('Second Sunday of the Resurrection: New Sunday') == 'Sunday'
    assert rank('Ash Monday') == 'Fast'
    assert rank('Holy Friday') == 'Holy Week'
    assert is_ferial('Monday of the First Week of Epiphany')
    assert is_ferial('Saturay of the Second Week of Great Lent')
    assert not is_ferial('Ash Monday')
    assert not is_ferial('Monday of Holy Week')
    assert not is_ferial('Monday of Passion week')
    assert not is_ferial('Thursday of the Mysteries')
    print('Maronite rank and edition wrapper checks passed.')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--start', type=dt.date.fromisoformat, default=dt.date(dt.date.today().year,1,1))
    parser.add_argument('--end', type=dt.date.fromisoformat, default=dt.date(dt.date.today().year,12,31))
    parser.add_argument('--cache', type=Path, default=Path('/tmp/prosary-maronite-cache'))
    parser.add_argument('--delay', type=float, default=1.5)
    parser.add_argument('--sync', action='store_true')
    parser.add_argument('--localize-only', action='store_true')
    parser.add_argument('--self-test', action='store_true')
    args=parser.parse_args()
    if args.self_test:
        self_test(); return
    if args.start > args.end:
        parser.error('--start must be no later than --end')
    f=module('prosary_maronite_feasts','fetch-feasts.py')
    r=module('prosary_maronite_readings','fetch-readings.py')
    # MAE uses Za where the other Evangelizo editions use Zc. Its own book.full_title
    # explicitly identifies the Book of Zechariah (2026-03-08 and 2026-03-29).
    r.EVANGELIZO_BOOKS.setdefault('Za',('Zech.','Zechariah'))
    args.cache.mkdir(parents=True, exist_ok=True)
    f.CACHE_DIR=args.cache
    paths=[DATA/'feasts-maronite.json',DATA/'readings-maronite.json']
    if args.localize_only and any(not path.exists() for path in paths):
        parser.error('--localize-only requires existing Maronite datasets; fetch source dates first')
    existing=[json.loads(path.read_text()) if path.exists() else {'days':{}} for path in paths]
    feasts,readings=[entry['days'] for entry in existing]
    day=args.start; fetched=0; unavailable=[]
    if not args.localize_only:
        while day <= args.end:
            key=day.isoformat(); cache=args.cache/f'evangelizo-mae-{key}.json'
            payload=None
            source_unavailable=False
            for attempt in range(4):
                try:
                    if not cache.exists(): time.sleep(max(0,args.delay))
                    payload=f.fetch_json(f.EVANGELIZO.format(edition='MAE',date=key),f'evangelizo-mae-{key}')
                    break
                except requests.HTTPError as error:
                    if error.response is not None and error.response.status_code==400:
                        unavailable.append(key); source_unavailable=True; break
                    time.sleep(5*(attempt+1))
                except requests.RequestException:
                    time.sleep(5*(attempt+1))
            if payload:
                data=payload.get('data') or {}
                title='; '.join(part.strip() for part in data.get('liturgic_title','').strip().split('|'))
                if title and not is_ferial(title):
                    previous=feasts.get(key,{})
                    feasts[key]={'title':title,'rank':rank(title)}
                    if previous.get('title') == title and previous.get('titleByLanguage'):
                        feasts[key]['titleByLanguage']=previous['titleByLanguage']
                # Feed the already-cached payload to the established citation parser.
                r.request=lambda url, **kwargs: payload
                parsed=r.evangelizo_day(day,'MAE')
                if parsed:
                    readings[parsed[0]]=parsed[1]
                fetched+=1
            elif source_unavailable and day > dt.date.today():
                print(f'MAE future horizon reached at {key}',flush=True);break
            elif not source_unavailable:
                raise RuntimeError(f'MAE failed after four attempts at {key}; existing datasets were not overwritten')
            if day.day in [1,15]:print(f'MAE through {key}: {fetched} fetched, {len(feasts)} titles, {len(readings)} reading dates',flush=True)
            day+=dt.timedelta(days=1)
    localize(feasts,readings,f,r)
    comment='Maronite Catholic calendar and lectionary metadata courtesy of Evangelizo.org — Daily Gospel (© Evangelizo.org), publication edition MAE. No Scripture, commentary, biography or prayer text. The source rolling horizon limits coverage; absent dates have no inferred readings. Feast ranks are display classifications inferred from source titles. Display title translations are Prosary editorial metadata, not official church editions. Hebrew Bible book names: Evangelizo HE, St James Vicariate and Mechon Mamre; other citation-name sources: Shared/tools/reading-books-localized.json.'
    for path,days in zip(paths,[feasts,readings]):
        out={'$comment':comment,'generated':dt.date.today().isoformat(),'source':f.EVANGELIZO.format(edition='MAE',date='{date}'),'days':dict(sorted(days.items()))}
        path.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
        print(f'Wrote {path.name}: {len(days)} dates',flush=True)
        if args.sync:
            for target in r.TARGETS:
                target.mkdir(parents=True,exist_ok=True);shutil.copy2(path,target/path.name)
    if unavailable:print(f'Source unavailable for {len(unavailable)} requested dates; no substitutes were inserted.',flush=True)

if __name__=='__main__':main()

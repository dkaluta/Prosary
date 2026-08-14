#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["requests"]
# ///
"""Regenerate the Home "Today" feast datasets in Shared/data/ — one file per liturgical
calendar, listed in Shared/data/calendars.json.

    usage: fetch-feasts.py [--years 2026 2027] [--sync] [--cache DIR]
           --years  the civil years to bake in (default: the current and next year)
           --sync   also copy every Shared/data/*.json into the three platform asset dirs
           --cache  read litcal-<year>.json / missalemeum-<year>.json from DIR instead of
                    fetching when present (and save fetched payloads there)

Calendars and their sources:
  feasts.json            Roman — Holy Land: the General Roman Calendar from the litcal API
                         (litcal.johnromanodorazio.com, Apache-2.0 data) overlaid with the
                         Latin Patriarchate of Jerusalem's documented propers (LPJ_PROPERS
                         below). The app's default calendar; keeps the original filename so
                         nothing that predates switchable calendars moves.
  feasts-roman.json      Roman — General Calendar: litcal, no overlay.
  feasts-roman1962.json  Roman — 1962 (Vetus Ordo): missalemeum.com's API (MIT), with the
                         1962 class ranks ("1st Class" … "3rd Class"; IV-class days and bare
                         ferias are omitted the same way ferial days are omitted elsewhere).

Movable feasts are baked in per year at generation time — no computus ships in the app. A
date outside a table simply hides the Today row. pope-intentions.json is maintained by hand
from popesprayer.va (monthly prose, no API) and is untouched here.

The per-day shape every platform's TodayInfoStore decodes is {"title": …, "rank": …}; the
Home screens bold the title when the rank is "Solemnity" or "1st Class". Sundays of the
season carry rank "Sunday". Never rename ranks casually: validate-devotion.py's hours-type
rank vocabulary camelCases the default calendar's set.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import shutil
import sys
from collections import defaultdict
from pathlib import Path

import requests

TOOLS = Path(__file__).resolve().parent
SHARED = TOOLS.parent
ROOT = SHARED.parent
DATA = SHARED / "data"

PLATFORM_DATA_DIRS = [
    ROOT / "iOS" / "Prosary" / "Data",
    ROOT / "Android" / "app" / "src" / "main" / "assets" / "data",
    ROOT / "Windows" / "Prosary" / "Data",
]

# The Latin Patriarchate of Jerusalem's documented propers, overlaid on the General Roman
# Calendar (fixed dates; they replace whatever the general calendar has that day).
LPJ_PROPERS = {
    "07-15": {"title": "Dedication of the Basilica of the Holy Sepulchre", "rank": "Feast"},
    "08-26": {"title": "Saint Mary of Jesus Crucified Baouardy, Virgin", "rank": "Memorial"},
    "10-25": {"title": "Our Lady, Queen of Palestine and of the Holy Land", "rank": "Solemnity"},
}

LITCAL = "https://litcal.johnromanodorazio.com/api/v5/calendar/{year}?year_type=CIVIL"
MISSALEMEUM = "https://www.missalemeum.com/en/api/v5/calendar/{year}"


CACHE_DIR: Path | None = None


def fetch_json(url: str, cache_name: str):
    cache_file = CACHE_DIR / f"{cache_name}.json" if CACHE_DIR else None
    if cache_file and cache_file.exists():
        return json.loads(cache_file.read_text(encoding="utf-8"))
    response = requests.get(url, headers={"Accept": "application/json", "Accept-Language": "en"}, timeout=60)
    response.raise_for_status()
    if cache_file:
        cache_file.write_text(response.text, encoding="utf-8")
    return response.json()


def roman_days(year: int) -> dict:
    """One {date: {title, rank}} entry per non-ferial day of the General Roman Calendar.

    litcal grades: 0 weekday, 1 commemoration, 2 optional memorial, 3 memorial, 4 feast,
    5 feast of the Lord (which is also how Sundays of the season arrive), 6 solemnity,
    7 precedence over solemnities. Per day: drop the anticipated "… Vigil Mass" events (the
    Easter Vigil proper, plain "Easter Vigil", stays — it is Holy Saturday's celebration),
    keep the highest grade, and skip the day entirely below optional memorial.
    """
    by_day: dict[str, list] = defaultdict(list)
    for event in fetch_json(LITCAL.format(year=year), f"litcal-{year}")["litcal"]:
        date = event["date"][:10]
        if date.startswith(str(year)) and not event["name"].endswith("Vigil Mass"):
            by_day[date].append(event)

    days = {}
    for date, events in sorted(by_day.items()):
        top = max(events, key=lambda e: e["grade"])
        if top["grade"] >= 6:
            rank = "Solemnity"
        elif top["grade"] == 5:
            rank = "Sunday" if "Sunday" in top["name"] else "Feast"
        elif top["grade"] == 4:
            rank = "Feast"
        elif top["grade"] == 3:
            rank = "Memorial"
        elif top["grade"] == 2:
            rank = "Optional Memorial"
        else:
            continue
        days[date] = {"title": top["name"], "rank": rank}
    return days


def roman1962_days(year: int) -> dict:
    """One entry per I–III class day of the 1962 calendar (missalemeum). IV-class days and
    bare ferias are omitted — the Vetus Ordo twin of skipping ferial days."""
    ranks = {1: "1st Class", 2: "2nd Class", 3: "3rd Class"}
    days = {}
    for entry in fetch_json(MISSALEMEUM.format(year=year), f"missalemeum-{year}"):
        if entry["rank"] in ranks and entry["title"] and entry["title"] != "Feria":
            days[entry["id"]] = {"title": entry["title"], "rank": ranks[entry["rank"]]}
    return days


def write_dataset(path: Path, comment: str, years: list[int], days: dict) -> None:
    payload = {
        "$comment": comment,
        "generated": dt.date.today().isoformat(),
        "years": years,
        "days": days,
    }
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"wrote {path.relative_to(ROOT)} ({len(days)} days)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--years", type=int, nargs="+", default=None)
    parser.add_argument("--sync", action="store_true", help="copy Shared/data/*.json to the platform asset dirs")
    parser.add_argument("--cache", type=Path, default=None, help="payload cache directory")
    args = parser.parse_args()
    years = args.years or [dt.date.today().year, dt.date.today().year + 1]
    if args.cache:
        global CACHE_DIR
        CACHE_DIR = args.cache
        CACHE_DIR.mkdir(parents=True, exist_ok=True)

    roman: dict = {}
    vetus: dict = {}
    for year in years:
        roman.update(roman_days(year))
        vetus.update(roman1962_days(year))

    lpj = dict(roman)
    for year in years:
        for month_day, entry in LPJ_PROPERS.items():
            lpj[f"{year}-{month_day}"] = dict(entry)
    lpj = dict(sorted(lpj.items()))

    write_dataset(
        DATA / "feasts.json",
        "Per-day sanctoral table for the Home 'Today' row: General Roman Calendar "
        "(litcal.johnromanodorazio.com, locale en) overlaid with the Latin Patriarchate of "
        "Jerusalem's documented propers. Movable feasts are baked in per year at generation "
        "time — no computus ships in the app. Regenerate yearly (Shared/tools/fetch-feasts.py); "
        "dates outside this table simply hide the row.",
        years, lpj)
    write_dataset(
        DATA / "feasts-roman.json",
        "Per-day sanctoral table, Roman — General Calendar: litcal.johnromanodorazio.com "
        "(locale en), no local propers. Generated by Shared/tools/fetch-feasts.py; see "
        "feasts.json for the conventions.",
        years, roman)
    write_dataset(
        DATA / "feasts-roman1962.json",
        "Per-day table, Roman — 1962 (Vetus Ordo): missalemeum.com (MIT), I–III class days "
        "with the 1962 class ranks; IV-class days and bare ferias are omitted. Generated by "
        "Shared/tools/fetch-feasts.py; see feasts.json for the conventions.",
        years, vetus)

    if args.sync:
        for target in PLATFORM_DATA_DIRS:
            if not target.is_dir():
                print(f"error: missing platform data dir {target}", file=sys.stderr)
                return 1
            for source in sorted(DATA.glob("*.json")):
                shutil.copy2(source, target / source.name)
            print(f"synced -> {target.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

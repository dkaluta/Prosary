#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["requests"]
# ///
"""Regenerate the Home "Today" feast datasets in Shared/data/ — one file per liturgical
calendar, listed in Shared/data/calendars.json.

    usage: fetch-feasts.py [--years 2026 2027] [--sync] [--cache DIR]
           fetch-feasts.py --localize-only --sync
           --years  the civil years to bake in (default: the current and next year)
           --sync   also copy every Shared/data/*.json into the three platform asset dirs
           --cache  read litcal-<year>.json / missalemeum-<year>.json from DIR instead of
                    fetching when present (and save fetched payloads there)
           --localize-only  apply sourced feast/saint names to the existing dates offline

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
  feasts-syriac.json     West Syriac — Syriac Catholic: Evangelizo.org's Daily Gospel
                         publication API (the "SYE" English Syriac-calendar edition — the
                         very rite Erez's Mission belongs to), one request per day, taking
                         only the liturgical day title; ferial days arrive as plain date
                         titles ("The fourteenth day of August") and are skipped. CREDIT IS
                         REQUIRED AND GIVEN — dataset comment, ARCHITECTURE.markdown, and every
                         platform's About screen carry "courtesy of Evangelizo.org (Daily
                         Gospel), © Evangelizo.org". The API serves a rolling window only
                         (~3 months ahead; farther dates answer "too far in the future"), so
                         this dataset covers as far as the API allows at generation time and
                         extends on each rerun — regenerate more often than yearly.
  All calendars         carry sourced Hebrew feast and saint titles inline as
                         titleByLanguage.he. Exact identity catalogs preserve names from
                         Evangelizo HE and Hebrew church publications across calendar years
                         and explicitly reviewed aliases across rites. They never replace a
                         calendar's dates, original observances, or ranks. Uncovered identities
                         retain their source-language title.
  feasts-ugcc.json       Byzantine — Ukrainian Greek Catholic, the diasporic (fully Gregorian)
                         usage prayed in the Holy Land: no licensed machine-readable source
                         exists, so the fixed menologion is CURATED IN THIS SCRIPT
                         (UGCC_MENOLOGION — the Twelve Great Feasts and the major
                         commemorations of every Byzantine wall calendar, plus the UGCC's own:
                         Josaphat, Volodymyr, Olha, the Blessed New Martyrs) and the movable
                         Paschal cycle is computed from the Gregorian Pascha. Ranks: "Great
                         Feast" (bolded like "Solemnity"), "Feast", "Sunday", "Holy Week",
                         "Fast". Every Sunday gets a name — the Triodion/Pentecostarion
                         Sundays their own, the rest numbered after Pentecost with the
                         pre-Nativity/Theophany specials. A fixed Great Feast falling on a
                         movable-cycle day is joined into one title (the Annunciation in Holy
                         Week — 2027 is such a year). Curated data wants eparchial
                         verification; corrections are one table edit away.

Movable feasts are baked in per year at generation time — no computus ships in the app. A
date outside a table simply hides the Today row. pope-intentions.json is maintained by hand
from popesprayer.va (monthly prose, no API) and is untouched here.

The per-day shape every platform's TodayInfoStore decodes is
{"title": …, "rank": …, "titleByLanguage"?: {"he": …}}; the
Pray screens bold the title when the rank is "Solemnity" or "1st Class". Sundays of the
season carry rank "Sunday". Never rename ranks casually: validate-devotion.py's hours-type
rank vocabulary camelCases the default calendar's set.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import shutil
import time
from collections import defaultdict
from pathlib import Path

import requests

TOOLS = Path(__file__).resolve().parent
SHARED = TOOLS.parent
ROOT = SHARED.parent
DATA = SHARED / "data"
HEBREW_TITLE_CATALOGS = [TOOLS / "hebrew-feast-titles.json", TOOLS / "hebrew-saint-titles.json"]

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
EVANGELIZO = "https://publication.evangelizo.ws/{edition}/days/{date}"

# Evangelizo's ferial days in the SYE edition carry a plain date title ("The fourteenth day
# of August") — the equivalent of the litcal weekdays every other dataset omits. The HE
# edition is less uniform; its observed ferial forms are the weekday-in-week
# ("יום ה בשבוע כב' של הזמן הרגיל", Saturdays "שבת בשבוע …", sometimes without the ב:
# "יום ב שבוע יא'"), the days-after ("שבת אחרי יום האפר", "היום ה-2 אחרי ההתגלות"), and
# Christmastide's plain-date "המקראות ל- 2 בינואר". Sundays ("יום א ה-22 של הזמן הרגיל",
# "יום א' ה-1 בצום") match none of these and are kept, as are the Holy Week day names
# ("יום השישי הגדול").
EVANGELIZO_FERIAL = {
    "SYE": re.compile(r"^The [\w-]+ day of [A-Z][a-z]+$"),
    "HE": re.compile(r"^(?:(?:יום \S{1,2}|שבת) (?:ב?שבוע|אחרי)|היום ה-\d+ אחרי|המקראות ל)"),
}

# The UGCC fixed menologion (new-style/Gregorian dates), curated — see the module docstring.
# G = Great Feast, F = Feast.
UGCC_MENOLOGION = {
    "01-01": ("The Circumcision of Our Lord; Saint Basil the Great", "F"),
    "01-06": ("The Holy Theophany of Our Lord", "G"),
    "01-07": ("Synaxis of the Holy Prophet and Forerunner John the Baptist", "F"),
    "01-17": ("Venerable Anthony the Great", "F"),
    "01-25": ("Saint Gregory the Theologian", "F"),
    "01-30": ("The Three Holy Hierarchs", "F"),
    "02-02": ("The Encounter of Our Lord", "G"),
    "03-09": ("The Holy Forty Martyrs of Sebaste", "F"),
    "03-25": ("The Annunciation of the Most Holy Theotokos", "G"),
    "04-23": ("Holy Great-Martyr George", "F"),
    "05-08": ("Holy Apostle and Evangelist John the Theologian", "F"),
    "05-21": ("Holy Equal-to-the-Apostles Constantine and Helena", "F"),
    "06-24": ("The Nativity of the Holy Prophet John the Baptist", "F"),
    "06-27": ("The Blessed New Martyrs of the Ukrainian Catholic Church", "F"),
    "06-29": ("Holy Apostles Peter and Paul", "F"),
    "07-11": ("Holy Equal-to-the-Apostles Olha, Princess of Kyiv", "F"),
    "07-15": ("Holy Equal-to-the-Apostles Great Prince Volodymyr", "F"),
    "07-20": ("The Holy Prophet Elijah", "F"),
    "08-06": ("The Holy Transfiguration of Our Lord", "G"),
    "08-15": ("The Dormition of the Most Holy Theotokos", "G"),
    "08-29": ("The Beheading of the Holy Prophet John the Baptist", "F"),
    "09-08": ("The Nativity of the Most Holy Theotokos", "G"),
    "09-14": ("The Exaltation of the Precious and Life-Giving Cross", "G"),
    "10-01": ("The Protection of the Most Holy Theotokos (Pokrov)", "F"),
    "10-26": ("Holy Great-Martyr Demetrius", "F"),
    "11-08": ("Synaxis of the Archangel Michael and the Other Bodiless Powers", "F"),
    "11-12": ("Holy Priest-Martyr Josaphat, Archbishop of Polotsk", "F"),
    "11-13": ("Saint John Chrysostom", "F"),
    "11-21": ("The Entrance of the Most Holy Theotokos into the Temple", "G"),
    "11-30": ("Holy Apostle Andrew the First-Called", "F"),
    "12-06": ("Saint Nicholas the Wonderworker", "F"),
    "12-09": ("The Conception of the Most Holy Theotokos by Saint Anna", "F"),
    "12-25": ("The Nativity of Our Lord", "G"),
    "12-26": ("Synaxis of the Most Holy Theotokos", "F"),
    "12-27": ("Holy First-Martyr and Archdeacon Stephen", "F"),
}

# The movable Paschal cycle as offsets in days from Pascha. Sundays carry rank "Sunday" except
# Palm Sunday (one of the Twelve Great Feasts); Holy Week days rank "Holy Week".
UGCC_PASCHAL_CYCLE = [
    (-70, "Sunday of the Publican and the Pharisee", "Sunday"),
    (-63, "Sunday of the Prodigal Son", "Sunday"),
    (-56, "Meatfare Sunday — of the Last Judgment", "Sunday"),
    (-49, "Cheesefare Sunday — of Forgiveness", "Sunday"),
    (-48, "First Day of the Great Fast", "Fast"),
    (-42, "First Sunday of the Great Fast — of Orthodoxy", "Sunday"),
    (-35, "Second Sunday of the Great Fast — Saint Gregory Palamas", "Sunday"),
    (-28, "Third Sunday of the Great Fast — Veneration of the Cross", "Sunday"),
    (-21, "Fourth Sunday of the Great Fast — Saint John Climacus", "Sunday"),
    (-14, "Fifth Sunday of the Great Fast — Saint Mary of Egypt", "Sunday"),
    (-8, "Lazarus Saturday", "Feast"),
    (-7, "Flowery (Palm) Sunday — the Entrance into Jerusalem", "G"),
    (-6, "Great and Holy Monday", "Holy Week"),
    (-5, "Great and Holy Tuesday", "Holy Week"),
    (-4, "Great and Holy Wednesday", "Holy Week"),
    (-3, "Great and Holy Thursday", "Holy Week"),
    (-2, "Great and Holy Friday", "Holy Week"),
    (-1, "Great and Holy Saturday", "Holy Week"),
    (0, "The Resurrection of Our Lord — Holy Pascha", "G"),
    (1, "Bright Monday", "Feast"),
    (2, "Bright Tuesday", "Feast"),
    (7, "Thomas Sunday", "Sunday"),
    (14, "Sunday of the Myrrh-Bearing Women", "Sunday"),
    (21, "Sunday of the Paralytic", "Sunday"),
    (24, "Mid-Pentecost", "Feast"),
    (28, "Sunday of the Samaritan Woman", "Sunday"),
    (35, "Sunday of the Man Born Blind", "Sunday"),
    (39, "The Ascension of Our Lord", "G"),
    (42, "Sunday of the Fathers of the First Council of Nicaea", "Sunday"),
    (49, "The Descent of the Holy Spirit — Pentecost", "G"),
    (50, "Monday of the Holy Spirit", "Feast"),
    (56, "Sunday of All Saints", "Sunday"),
]

UGCC_RANKS = {"G": "Great Feast", "F": "Feast"}


def evangelizo_titles(edition: str, start_year: int) -> dict[str, str]:
    """{date: non-ferial liturgic_title} from Evangelizo's Daily Gospel publication API, one
    request per day starting January 1 of the first requested year. The API answers HTTP 400
    ("This date is too far in the future") past its rolling ~3-month horizon — that is the
    stop signal, so coverage grows with every rerun. Anything else (the API drops sporadic
    requests under sequential load) is retried before giving up on the remainder. A title
    Evangelizo pipe-joins ("חג מרים אם האדון | חג ברית ישו") is rejoined with the datasets'
    usual '; '."""
    titles: dict[str, str] = {}
    ferial = EVANGELIZO_FERIAL[edition]
    day = dt.date(start_year, 1, 1)
    while True:
        date = day.isoformat()
        payload = horizon = None
        for attempt in range(4):
            try:
                payload = fetch_json(
                    EVANGELIZO.format(edition=edition, date=date),
                    f"evangelizo-{edition.lower()}-{date}")
                break
            except requests.HTTPError as error:
                if error.response is not None and error.response.status_code == 400:
                    horizon = True
                    break
                time.sleep(2 * (attempt + 1))
            except requests.RequestException:
                time.sleep(2 * (attempt + 1))
        if payload is None:
            if horizon:
                print(f"  (Evangelizo {edition} horizon reached after {date})")
            else:
                print(f"  (warning: Evangelizo {edition} kept failing at {date} — stopping early)")
            break
        title = (payload.get("data") or {}).get("liturgic_title", "").strip()
        if title and not ferial.match(title):
            titles[date] = "; ".join(part.strip() for part in title.split("|"))
        day += dt.timedelta(days=1)
    if not titles:
        raise SystemExit(f"error: Evangelizo returned no {edition} days at all")
    return titles


def syriac_days(start_year: int) -> dict:
    """One entry per named day of the Syriac Catholic calendar (Evangelizo edition SYE).
    Sundays rank "Sunday", fast-season weekdays "Fast", the rest "Feast"."""
    days: dict[str, dict] = {}
    for date, title in evangelizo_titles("SYE", start_year).items():
        if "Pascha" in title:
            # The feast of feasts outranks its own Sunday — and gets the bolded top rank.
            rank = "Great Feast"
        elif "Sunday" in title:
            rank = "Sunday"
        elif "Fast" in title:
            rank = "Fast"
        else:
            rank = "Feast"
        days[date] = {"title": title, "rank": rank}
    return days


def add_hebrew_titles(days: dict, titles: dict[str, str]) -> dict:
    """Return a copy of ``days`` enriched with sourced Hebrew titles.

    The HE publication sometimes names a proper-reading day that LitCal leaves ferial. Such
    a row cannot safely be inserted into the General Roman sanctoral table with an invented
    rank, so it is logged and omitted. Existing English titles always remain authoritative.
    """
    localized = {date: dict(entry) for date, entry in days.items()}
    for date, title in titles.items():
        entry = localized.get(date)
        if entry is None:
            print(f"  (no General Roman entry for sourced Hebrew title on {date}: {title!r})")
            continue
        entry["titleByLanguage"] = {**entry.get("titleByLanguage", {}), "he": title}
    return localized


def hebrew_title_catalog() -> dict[str, str]:
    """Exact feast identities and explicitly reviewed aliases, never date-based matches."""
    result: dict[str, str] = {}
    for path in HEBREW_TITLE_CATALOGS:
        payload = json.loads(path.read_text(encoding="utf-8"))
        for title, entry in payload["titles"].items():
            if not entry.get("he", "").strip() or not entry.get("source", "").strip():
                raise ValueError(f"{path.name}: missing Hebrew name or source for {title!r}")
            if title in result and result[title] != entry["he"]:
                raise ValueError(f"Conflicting Hebrew titles for {title!r}")
            result[title] = entry["he"]
    return result


def localized_feast_title(title: str, catalog: dict[str, str]) -> str | None:
    if title in catalog:
        return catalog[title]
    # Byzantine fixed feasts can coincide with Holy Week. Translate each actual component;
    # a sourced name for one feast must never replace or conceal the other observance.
    if "; " in title:
        parts = title.split("; ")
        translated = [localized_feast_title(part, catalog) for part in parts]
        if any(translated):
            return "; ".join(localized or original for original, localized in zip(parts, translated))
    return None


def localize_feast_days(days: dict, catalog: dict[str, str]) -> tuple[int, set[str]]:
    """Enrich titles in place, preserving dates, ranks, original titles and authored languages."""
    added = 0
    missing: set[str] = set()
    for entry in days.values():
        if entry.get("titleByLanguage", {}).get("he"):
            continue
        title = entry["title"]
        translated = localized_feast_title(title, catalog)
        if translated:
            entry.setdefault("titleByLanguage", {})["he"] = translated
            added += 1
        else:
            missing.add(title)
    return added, missing


def localize_existing_datasets() -> None:
    catalog = hebrew_title_catalog()
    registry = json.loads((DATA / "calendars.json").read_text(encoding="utf-8"))
    for name in dict.fromkeys(calendar["file"] for calendar in registry["calendars"]):
        path = DATA / f"{name}.json"
        payload = json.loads(path.read_text(encoding="utf-8"))
        added, missing = localize_feast_days(payload["days"], catalog)
        credit = (
            " Hebrew feast and saint names use the credited source catalogs in "
            "Shared/tools/hebrew-feast-titles.json and hebrew-saint-titles.json; "
            "the calendar's own dates, observances, ranks and original titles are retained.")
        if "Hebrew feast and saint names" not in payload["$comment"]:
            payload["$comment"] += credit
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(f"localized {path.name}: {added} added; {len(missing)} distinct titles retain their source language")


def sync_datasets() -> None:
    for target in PLATFORM_DATA_DIRS:
        if not target.is_dir():
            raise SystemExit(f"error: missing platform data dir {target}")
        for source in sorted(DATA.glob("*.json")):
            shutil.copy2(source, target / source.name)
        stale = target / "feasts-roman-he.json"
        if stale.exists():
            stale.unlink()
        print(f"synced -> {target.relative_to(ROOT)}")


def gregorian_easter(year: int) -> dt.date:
    """Meeus/Jones/Butcher — the same Gregorian computus the apps' calendar service uses."""
    a, b, c = year % 19, year // 100, year % 100
    d, e = b // 4, b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = c // 4, c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month = (h + l - 7 * m + 114) // 31
    day = (h + l - 7 * m + 114) % 31 + 1
    return dt.date(year, month, day)


def _ordinal(n: int) -> str:
    suffix = "th" if 11 <= n % 100 <= 13 else {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
    return f"{n}{suffix}"


def ugcc_days(year: int) -> dict:
    """One entry per feast/named day of the UGCC's diasporic (fully Gregorian) calendar.

    Layered lowest to highest: numbered Sundays after Pentecost (counted from the previous
    year's Pentecost before this year's) → fixed Feasts → the pre-Nativity/Theophany special
    Sundays → fixed Great Feasts → the movable Paschal cycle, which joins rather than
    replaces a fixed Great Feast it lands on (the Annunciation in Holy Week).
    """
    pascha = gregorian_easter(year)
    pentecost_previous = gregorian_easter(year - 1) + dt.timedelta(days=49)
    pentecost = pascha + dt.timedelta(days=49)
    days: dict[str, dict] = {}

    def put(date: dt.date, title: str, rank: str) -> None:
        days[date.isoformat()] = {"title": title, "rank": rank}

    # Numbered Sundays after Pentecost — the base layer every other layer may cover.
    day = dt.date(year, 1, 1)
    while day.year == year:
        if day.weekday() == 6:
            since = pentecost if day > pentecost else pentecost_previous
            n = (day - since).days // 7
            if n >= 2:  # 1st after Pentecost is All Saints, a movable-cycle entry.
                put(day, f"{_ordinal(n)} Sunday after Pentecost", "Sunday")
        day += dt.timedelta(days=1)

    # Fixed Feasts, then the special Sundays around Nativity and Theophany, then fixed Great
    # Feasts — a Great Feast outranks a special Sunday, which outranks a plain fixed feast.
    for month_day, (title, code) in UGCC_MENOLOGION.items():
        if code == "F":
            put(dt.date.fromisoformat(f"{year}-{month_day}"), title, UGCC_RANKS[code])
    specials = [
        ((12, 11), (12, 17), "Sunday of the Holy Forefathers"),
        ((12, 18), (12, 24), "Sunday before the Nativity — of the Holy Fathers"),
        ((12, 26), (12, 31), "Sunday after the Nativity"),
        ((1, 1), (1, 5), "Sunday before Theophany"),
        ((1, 7), (1, 13), "Sunday after Theophany"),
    ]
    for (m1, d1), (m2, d2), title in specials:
        day = dt.date(year, m1, d1)
        last = dt.date(year, m2, d2)
        while day <= last:
            if day.weekday() == 6:
                put(day, title, "Sunday")
            day += dt.timedelta(days=1)
    for month_day, (title, code) in UGCC_MENOLOGION.items():
        if code == "G":
            put(dt.date.fromisoformat(f"{year}-{month_day}"), title, UGCC_RANKS[code])

    # The movable Paschal cycle wins the day — but a fixed Great Feast it lands on is joined
    # into the title, never displaced (Byzantine practice celebrates them together).
    for offset, title, code in UGCC_PASCHAL_CYCLE:
        date = pascha + dt.timedelta(days=offset)
        rank = UGCC_RANKS.get(code, code)
        existing = days.get(date.isoformat())
        if existing and existing["rank"] == "Great Feast" and code not in ("G",):
            put(date, f"{existing['title']}; {title}", "Great Feast")
        else:
            put(date, title, rank)

    return dict(sorted(days.items()))


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
    parser.add_argument("--localize-only", action="store_true", help="apply sourced names offline without changing calendar coverage")
    parser.add_argument("--self-test", action="store_true", help="check exact-title localization without fetching data")
    args = parser.parse_args()
    if args.self_test:
        catalog = {"Feast": "חג", "Other observance": "זכר", "Saint": "קדוש"}
        days = {
            "2026-09-05": {"title": "Saint", "rank": "Memorial", "titleByLanguage": {"ar": "existing"}},
            "2027-09-05": {"title": "Saint", "rank": "Feast"},
            "2026-09-06": {"title": "Unknown", "rank": "Sunday"},
            "2026-09-07": {"title": "Feast", "rank": "Feast", "titleByLanguage": {"he": "authored"}},
        }
        originals = {date: (row["title"], row["rank"]) for date, row in days.items()}
        added, missing = localize_feast_days(days, catalog)
        assert added == 2 and missing == {"Unknown"}
        assert {date: (row["title"], row["rank"]) for date, row in days.items()} == originals
        assert days["2026-09-05"]["titleByLanguage"] == {"ar": "existing", "he": "קדוש"}
        assert days["2027-09-05"]["titleByLanguage"]["he"] == "קדוש"
        assert days["2026-09-07"]["titleByLanguage"]["he"] == "authored"
        snapshot = json.dumps(days, ensure_ascii=False)
        assert localize_feast_days(days, catalog) == (0, {"Unknown"})
        assert json.dumps(days, ensure_ascii=False) == snapshot
        assert localized_feast_title("Feast; Other observance", catalog) == "חג; זכר"
        assert localized_feast_title("Feast; Unknown", catalog) == "חג; Unknown"
        assert localized_feast_title("Different saint", catalog) is None
        hebrew_title_catalog()  # Validate every checked-in label has a source and no conflict.
        print("feast localization self-test passed")
        return 0
    if args.localize_only:
        localize_existing_datasets()
        if args.sync:
            sync_datasets()
        return 0
    years = args.years or [dt.date.today().year, dt.date.today().year + 1]
    if args.cache:
        global CACHE_DIR
        CACHE_DIR = args.cache
        CACHE_DIR.mkdir(parents=True, exist_ok=True)

    roman: dict = {}
    vetus: dict = {}
    ugcc: dict = {}
    for year in years:
        roman.update(roman_days(year))
        vetus.update(roman1962_days(year))
        ugcc.update(ugcc_days(year))
    syriac = syriac_days(years[0])
    roman = add_hebrew_titles(roman, evangelizo_titles("HE", years[0]))

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
    write_dataset(
        DATA / "feasts-syriac.json",
        "Per-day table, West Syriac — Syriac Catholic: liturgical day titles courtesy of "
        "Evangelizo.org — Daily Gospel (© Evangelizo.org), publication edition SYE, used "
        "with attribution (also on every platform's About screen). Ferial plain-date titles "
        "are omitted. Evangelizo serves a rolling ~3-month horizon, so this table ends where "
        "the API did at generation time and extends on each rerun of "
        "Shared/tools/fetch-feasts.py — regenerate more often than yearly.",
        sorted({int(key[:4]) for key in syriac}), syriac)
    obsolete = DATA / "feasts-roman-he.json"
    if obsolete.exists():
        obsolete.unlink()
        print(f"removed obsolete {obsolete.relative_to(ROOT)}")
    write_dataset(
        DATA / "feasts-ugcc.json",
        "Per-day table, Byzantine — Ukrainian Greek Catholic, the diasporic (fully Gregorian) "
        "usage: CURATED in Shared/tools/fetch-feasts.py (no licensed machine-readable source "
        "exists — fixed menologion authored there, movable Paschal cycle computed from the "
        "Gregorian Pascha). Ranks: Great Feast / Feast / Sunday / Holy Week / Fast. Awaiting "
        "eparchial/community verification; see the script for the layering rules.",
        years, ugcc)

    localize_existing_datasets()

    if args.sync:
        sync_datasets()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

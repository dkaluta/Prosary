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
                         publication API ("SYE" English and "SYA" Arabic editions), taking
                         named liturgy plus every saint from both editions. Reviewed bilingual
                         identities prevent duplicates. Plain-date ferial titles are omitted
                         without discarding their saints. CREDIT IS
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
                         French and Italian names are joined from LitCal's matching stable
                         event_key identities in feast-titles-localized.json. Reviewed exact
                         aliases extend those names to the same observances in other calendars.
  feasts-ugcc.json       Byzantine — UGCC new-style fixed feasts with Julian Pascha.
                         The curated menologion and named movable cycles are baked per year.
  feasts-ugcc-gregorian.json uses the same fixed feasts with Gregorian Pascha. The registry
                         selects matching feast and reading files for each choice.
  feasts-maronite.json   Evangelizo MAE, generated with fetch-maronite.py, distinct from SYE.
  All titles            sourced labels take precedence over credited editorial metadata in
                         feast-titles-*.json. All seven interface locales are covered without
                         copying dates, ranks, or readings across rites.

Movable feasts are baked in per year at generation time — no computus ships in the app. A
date outside a table simply hides the Today row. pope-intentions.json is maintained by hand
from popesprayer.va (monthly prose, no API) and is untouched here.

The per-day shape every platform's TodayInfoStore decodes is
{"title": …, "rank": …, "titleByLanguage"?: {"he": …, "fr": …, "it": …}}; the
Pray screens bold the title when the rank is "Solemnity" or "1st Class". Sundays of the
season carry rank "Sunday". Never rename ranks casually: validate-devotion.py's hours-type
rank vocabulary camelCases the default calendar's set.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import html
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
LOCALIZED_TITLE_CATALOG = TOOLS / "feast-titles-localized.json"
DISPLAY_TITLE_CATALOGS = [TOOLS / f"feast-titles-{name}.json" for name in
                          ("roman", "roman-he", "ugcc", "syriac", "maronite", "extra")]

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
    (-77, "Sunday of Zacchaeus", "Sunday"),
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


def evangelizo_label(value: str | None) -> str:
    """Normalize source presentation only, never spelling or saint identity."""
    return " ".join(html.unescape(value or "").split())


def syriac_identities() -> tuple[dict[str, str], dict[str, str], dict[str, str]]:
    """Reviewed bilingual identities, never matched by date or array position."""
    arabic: dict[str, str] = {}
    aliases: dict[str, str] = {}
    english_ids: dict[str, str] = {}
    for path in sorted(TOOLS.glob("syriac-observance-identities-*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        for target, name in ((arabic, "arabic"), (aliases, "aliases"), (english_ids, "englishSaintIds")):
            for key, value in payload.get(name, {}).items():
                key, value = evangelizo_label(key), evangelizo_label(value)
                if key in target and target[key] != value:
                    raise ValueError(f"Conflicting Syriac identity: {key}")
                target[key] = value
    return arabic, aliases, english_ids


def syriac_day(english: dict, arabic: dict,
               identities: tuple[dict[str, str], dict[str, str], dict[str, str]]) -> dict | None:
    """Retain named liturgy plus every saint in either edition, deduplicated by identity.

    English saint names take display precedence over equivalent liturgy/Arabic labels.
    Reviewed identities are separate metadata, never replacements for English spelling.
    Unknown Arabic identities retain their published Arabic name rather than being guessed
    or dropped. The source's class suffix is part of its Arabic caption, not a Roman rank.
    """
    translations, aliases, english_ids = identities
    clean = evangelizo_label
    def identity(title):
        seen = set()
        while title in aliases:
            if title in seen:
                raise ValueError(f"Cyclic Syriac identity alias: {title}")
            seen.add(title)
            title = aliases[title]
        return title
    entries: dict[str, dict] = {}
    def add(title, arabic_title=None, *, identity_title=None, priority=0):
        title = clean(title)
        if not title or title in {"#REF!", "#VALUE!", "#N/A", "#NAME?"}:
            return
        key = identity(clean(identity_title) if identity_title else title)
        row = entries.setdefault(key, {"title": title, "identity": key, "priority": priority})
        if priority > row["priority"]:
            row.update(title=title, priority=priority)
        if arabic_title:
            row["ar"] = clean(arabic_title)
    title = clean(english.get("liturgic_title"))
    arabic_title = clean(arabic.get("liturgic_title"))
    named_liturgy = bool(title and not EVANGELIZO_FERIAL["SYE"].fullmatch(title))
    named_arabic_liturgy = bool(arabic_title and not re.match(r"^اليوم .*شهر ", arabic_title))
    arabic_identity = translations.get(arabic_title)
    different_liturgy = bool(named_liturgy and named_arabic_liturgy and arabic_identity
                            and identity(arabic_identity) != identity(title))
    if named_liturgy:
        add("; ".join(part.strip() for part in title.split("|")),
            arabic_title if named_arabic_liturgy and not different_liturgy else None, priority=1)
    for saint in english.get("saints") or []:
        add(saint.get("name"), identity_title=english_ids.get(saint.get("id")), priority=2)
    if named_arabic_liturgy and (not named_liturgy or different_liturgy):
        # A reviewed difference must remain visible, after the English observances.
        add(arabic_identity or arabic_title, arabic_title)
    for saint in arabic.get("saints") or []:
        name = clean(saint.get("name"))
        add(translations.get(name, name), name)
    if not entries:
        return None
    if named_liturgy and "Pascha" in title:
        rank = "Great Feast"
    elif named_liturgy and "Sunday" in title:
        rank = "Sunday"
    elif named_liturgy and "Fast" in title:
        rank = "Fast"
    else:
        rank = "Feast"
    return {"title": "; ".join(row["title"] for row in entries.values()), "rank": rank,
            "observances": [{"title": row["title"], "identity": row["identity"],
                             **({"sourceTitleByLanguage": {"ar": row["ar"]}} if row.get("ar") else {})}
                            for row in entries.values()],
            "titleByLanguage": {"ar": "; ".join(row.get("ar", row["title"]) for row in entries.values())}}


def evangelizo_day(edition: str, date: str) -> dict | None:
    """None marks the documented future horizon; other persistent errors abort safely."""
    for attempt in range(6):
        try:
            payload = fetch_json(EVANGELIZO.format(edition=edition, date=date),
                                 f"evangelizo-{edition.lower()}-{date}")
            data = payload.get("data") if isinstance(payload, dict) else None
            if (not isinstance(data, dict) or data.get("date") != date
                    or not isinstance(data.get("liturgic_title"), str)
                    or not data["liturgic_title"].strip()
                    or not isinstance(data.get("saints"), list)
                    or any(not isinstance(saint, dict) or not isinstance(saint.get("name"), str)
                           or not saint["name"].strip() for saint in data["saints"])):
                raise ValueError(f"Incomplete Evangelizo {edition} payload for {date}")
            return data
        except requests.HTTPError as error:
            response = error.response
            if response is not None and response.status_code == 400 and "future" in response.text.lower():
                return None
            if attempt == 5:
                raise
            retry = response.headers.get("Retry-After", "30") if response is not None else "30"
            time.sleep(max(2 * (attempt + 1), int(retry) if retry.isdigit() else 30))
        except requests.RequestException:
            if attempt == 5:
                raise
            time.sleep(2 * (attempt + 1))
    raise AssertionError("unreachable")


def syriac_days(start_year: int, until: dt.date | None = None) -> dict:
    """Merge English and Arabic Syriac liturgy/saints without cross-rite substitution."""
    days: dict[str, dict] = {}
    identities = syriac_identities()
    day = dt.date(start_year, 1, 1)
    while until is None or day <= until:
        date = day.isoformat()
        english = evangelizo_day("SYE", date)
        arabic = evangelizo_day("SYA", date)
        if english is None and arabic is None:
            break
        if english is None or arabic is None:
            raise ValueError(f"Syriac source horizons disagree on {date}; retaining previous dataset")
        entry = syriac_day(english, arabic, identities)
        if entry:
            days[date] = entry
        day += dt.timedelta(days=1)
    if not days:
        raise ValueError("Evangelizo returned no Syriac observances")
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


def hebrew_title_typography(title: str) -> str:
    """Join Hebrew compounds/prefixes with maqaf; retain sentence and numeric range dashes."""
    return re.sub(r"(?<=[\u0590-\u05ff])-(?=[\u0590-\u05ff0-9])", "־", title)


def localized_feast_entry_title(entry: dict, catalog: dict[str, str]) -> str | None:
    """Use reviewed component identities when source spellings are ambiguous."""
    components = entry.get("observances")
    if not components:
        return localized_feast_title(entry["title"], catalog)
    translated = [localized_feast_title(part["identity"], catalog) for part in components]
    if any(translated):
        return "; ".join(value or part["title"] for part, value in zip(components, translated))
    return None


def syriac_identity_catalog(catalog: dict[str, str]) -> dict[str, str]:
    """Reuse exact reviewed aliases without treating ambiguous source names as identities."""
    result = dict(catalog)
    aliases = syriac_identities()[1]
    for title, value in catalog.items():
        seen = set()
        while title in aliases:
            if title in seen:
                raise ValueError(f"Cyclic Syriac identity alias: {title}")
            seen.add(title)
            title = aliases[title]
        result.setdefault(title, value)
    return result


def localize_feast_days(days: dict, catalog: dict[str, str]) -> tuple[int, set[str]]:
    """Apply catalog edits by identity, retaining other languages and uncatalogued titles."""
    updated = 0
    missing: set[str] = set()
    for entry in days.values():
        title = entry["title"]
        translated = localized_feast_entry_title(entry, catalog) or entry.get("titleByLanguage", {}).get("he")
        if translated:
            translated = hebrew_title_typography(translated)
            if entry.get("titleByLanguage", {}).get("he") != translated:
                entry.setdefault("titleByLanguage", {})["he"] = translated
                updated += 1
        elif not entry.get("titleByLanguage", {}).get("he"):
            missing.add(title)
    return updated, missing


def sourced_title_catalogs(payload: dict | None = None) -> dict[str, dict[str, str]]:
    """Index reviewed event identities by exact source title, never by calendar date.

    Every localized name retains its publication source. Conflicting aliases fail closed;
    an abbreviated saint name cannot silently attach to two different observances.
    """
    if payload is None:
        payload = json.loads(LOCALIZED_TITLE_CATALOG.read_text(encoding="utf-8"))
    catalogs: dict[str, dict[str, str]] = {}
    for event_key, event in payload["events"].items():
        if not event_key or not event.get("englishTitles"):
            raise ValueError("Localized feast identity lacks an event key or English source title")
        aliases = event["englishTitles"] + event.get("reviewedEnglishAliases", [])
        for language, title in event["titleByLanguage"].items():
            if not title.strip() or not event.get("sources", {}).get(language):
                raise ValueError(f"{event_key}/{language}: missing localized name or source")
            catalog = catalogs.setdefault(language, {})
            for alias in aliases:
                if not alias.strip():
                    raise ValueError(f"{event_key}: empty identity alias")
                if alias in catalog and catalog[alias] != title:
                    raise ValueError(f"{language}: conflicting feast identity for {alias!r}")
                catalog[alias] = title
    return catalogs


def add_sourced_feast_titles(days: dict, catalogs: dict[str, dict[str, str]]) -> dict[str, int]:
    """Fill translated display names while retaining all canonical calendar properties."""
    updates = {language: 0 for language in catalogs}
    for entry in days.values():
        for language, catalog in catalogs.items():
            translated = localized_feast_entry_title(entry, catalog)
            if translated and entry.get("titleByLanguage", {}).get(language) != translated:
                entry.setdefault("titleByLanguage", {})[language] = translated
                updates[language] += 1
    return updates


def localize_syriac_days(days: dict, catalogs: dict[str, dict[str, str]], *, require_complete: bool = True) -> list[tuple[str, str, str]]:
    """Localize each retained observance; a locale key must contain an actual translation.

    SYA captions remain authoritative Arabic, with catalog labels filling English-only
    observances. The supplied Hebrew reference is applied only here, after shared labels.
    New untranslated identities fail regeneration instead of masquerading as seven locales.
    """
    from syriac_hebrew_calendar import apply_hebrew_reference

    languages = ("he", "ar", "ru", "tl", "fr", "it", "uk")
    catalogs = {language: syriac_identity_catalog(values) for language, values in catalogs.items()}
    for scoped_path in sorted(TOOLS.glob("syriac-feast-titles-reviewed*.json")):
        scoped = json.loads(scoped_path.read_text())["titles"]
        for identity, values in scoped.items():
            if not isinstance(identity, str) or not identity.strip() or not isinstance(values, dict):
                raise ValueError(f"Invalid reviewed Syriac identity in {scoped_path.name}")
            for language, value in values.items():
                if language not in languages or not isinstance(value, str) or not value.strip():
                    raise ValueError(f"Invalid reviewed Syriac translation: {scoped_path.name}/{identity}/{language}")
                catalogs.setdefault(language, {})[identity] = value
    for day in days.values():
        # Compatibility with the first component format, before Arabic was stored per saint.
        arabic_parts = day.get("titleByLanguage", {}).get("ar", "").split("; ")
        for index, part in enumerate(day["observances"]):
            arabic = part.get("sourceTitleByLanguage", {}).get("ar")
            if not arabic and "titleByLanguage" not in part and len(arabic_parts) == len(day["observances"]):
                candidate = arabic_parts[index]
                if candidate != part["title"]:
                    arabic = candidate
                    part.setdefault("sourceTitleByLanguage", {})["ar"] = candidate
            part["titleByLanguage"] = {"en": part["title"]}
            for language in languages:
                # An observance is already a reviewed unit. Never let a partly translated
                # compound fall through to localized_feast_title's generic source fallback.
                value = catalogs.get(language, {}).get(part["identity"])
                if isinstance(value, str) and value.strip():
                    part["titleByLanguage"][language] = value
            if arabic:
                part["titleByLanguage"]["ar"] = arabic
    # Preserve already sourced names and the user's chosen descriptors, Thomas spelling
    # and Pentecost terminology. The supplied reference fills remaining Syriac names.
    preferred_hebrew = {key: value for key, value in catalogs.get("he", {}).items()
                        if "Pentecost" in key}
    preferred_hebrew.update(syriac_identity_catalog(hebrew_title_catalog()))
    apply_hebrew_reference(days, syriac_identities()[1], preferred_hebrew)
    missing = []
    for date, day in days.items():
        day["titleByLanguage"] = {}
        for language in languages:
            values = [part["titleByLanguage"].get(language) for part in day["observances"]]
            for part, value in zip(day["observances"], values):
                if not value:
                    missing.append((date, language, part["identity"]))
            if all(values):
                day["titleByLanguage"][language] = "; ".join(values)
    if missing and require_complete:
        raise ValueError(f"Untranslated Syriac observances ({len(missing)}): " +
                         "; ".join(f"{date}/{language}: {identity}" for date, language, identity in missing[:20]))
    return missing


def feast_title_catalogs() -> dict[str, dict[str, str]]:
    """Load sourced and editorial names without mutating any calendar dataset."""
    display_catalogs: dict[str, dict[str, str]] = {}
    for path in DISPLAY_TITLE_CATALOGS:
        if path.exists():
            for title, translations in json.loads(path.read_text(encoding="utf-8"))["titles"].items():
                for language, value in translations.items():
                    if language in {"he", "ar", "ru", "tl", "fr", "it", "uk"}:
                        if not value.strip():
                            raise ValueError(f"Empty display translation: {path.name}/{title}/{language}")
                        display_catalogs.setdefault(language, {})[evangelizo_label(title)] = value
    catalog = display_catalogs.pop("he", {}) | {evangelizo_label(key): value for key, value in hebrew_title_catalog().items()}
    sourced_catalogs = sourced_title_catalogs()
    for language, values in sourced_catalogs.items():
        display_catalogs[language] = display_catalogs.get(language, {}) | {evangelizo_label(key): value for key, value in values.items()}
    # Aliases are reviewed named identities, never fuzzy matching or same-date matching.
    # Fill only missing values so exact published labels retain precedence.
    aliases_path = TOOLS / "feast-title-aliases.json"
    if aliases_path.exists():
        aliases = json.loads(aliases_path.read_text(encoding="utf-8"))["aliases"]
        aliases.update(syriac_identities()[1])
        for values in [catalog, *display_catalogs.values()]:
            for _ in range(len(aliases)):
                changed = False
                for alias, identity in aliases.items():
                    if alias not in values and identity in values:
                        values[alias] = values[identity]
                        changed = True
                if not changed:
                    break
    return {**display_catalogs, "he": catalog}


def localize_existing_datasets(only: set[str] | None = None) -> None:
    catalogs = feast_title_catalogs()
    catalog = catalogs["he"]
    display_catalogs = {language: values for language, values in catalogs.items() if language != "he"}
    registry = json.loads((DATA / "calendars.json").read_text(encoding="utf-8"))
    names = [calendar["file"] for calendar in registry["calendars"]]
    names += [variant["file"] for calendar in registry["calendars"]
              for variant in calendar.get("paschaVariants", {}).values()]
    for name in dict.fromkeys(names):
        if only is not None and name not in only:
            continue
        path = DATA / f"{name}.json"
        payload = json.loads(path.read_text(encoding="utf-8"))
        if name == "feasts-syriac":
            localize_syriac_days(payload["days"], catalogs)
            updated, missing, sourced_updates = len(payload["days"]), set(), {}
        else:
            updated, missing = localize_feast_days(payload["days"], catalog)
            sourced_updates = add_sourced_feast_titles(payload["days"], display_catalogs)
        credit = (
            " Hebrew feast and saint names use the credited source catalogs in "
            "Shared/tools/hebrew-feast-titles.json and hebrew-saint-titles.json; "
            "the calendar's own dates, observances, ranks and original titles are retained.")
        if "Hebrew feast and saint names" not in payload["$comment"]:
            payload["$comment"] += credit
        if "French and Italian feast names" not in payload["$comment"]:
            payload["$comment"] += (
                " French and Italian feast names are sourced from LitCal (Apache-2.0), "
                "joined by stable event identity with reviewed exact aliases in "
                "Shared/tools/feast-titles-localized.json; no calendar dates or ranks are changed.")
        if "Editorial display labels" not in payload["$comment"]:
            payload["$comment"] += " Editorial display labels in all interface languages are supplied by Prosary's feast-titles catalogs where a published translation is unavailable; they are calendar metadata, not official liturgical prayer translations. Published exact-title translations take precedence."
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(f"localized {path.name}: {updated} added or updated; {len(missing)} distinct titles retain their source language")
        print(f"  sourced language updates: {sourced_updates}")


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


def julian_easter(year: int) -> dt.date:
    """Julian Pascha as a civil Gregorian date; century offsets are calculated, not fixed."""
    a, b, c = year % 4, year % 7, year % 19
    d = (19 * c + 15) % 30
    e = (2 * a + 4 * b - d + 34) % 7
    month, day = (d + e + 114) // 31, (d + e + 114) % 31 + 1
    return dt.date(year, month, day) + dt.timedelta(days=year // 100 - year // 400 - 2)


def ugcc_days(year: int, pascha_style: str = "julian") -> dict:
    """UGCC new-style fixed dates; Julian Pascha by default, Gregorian by explicit choice.

    Layered lowest to highest: numbered Sundays after Pentecost (counted from the previous
    year's Pentecost before this year's) → fixed Feasts → the pre-Nativity/Theophany special
    Sundays → fixed Great Feasts → the movable Paschal cycle, which joins rather than
    replaces a fixed Great Feast it lands on (the Annunciation in Holy Week).
    """
    computus = gregorian_easter if pascha_style == "gregorian" else julian_easter
    pascha = computus(year)
    pentecost_previous = computus(year - 1) + dt.timedelta(days=49)
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
            date = dt.date.fromisoformat(f"{year}-{month_day}")
            if days.get(date.isoformat(), {}).get("rank") != "Sunday":
                put(date, title, UGCC_RANKS[code])
    specials = [
        ((9, 7), (9, 13), "Sunday before the Exaltation of the Cross"),
        ((9, 15), (9, 21), "Sunday after the Exaltation of the Cross"),
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

    # Saints do not erase the Sunday cycle. Join their fixed commemoration after the
    # movable/special Sunday has been resolved (Zacchaeus + Gregory on 25 Jan 2026).
    for month_day, (title, code) in UGCC_MENOLOGION.items():
        key = f"{year}-{month_day}"
        existing = days.get(key)
        if code == "F" and existing and existing["rank"] == "Sunday":
            existing["title"] += f"; {title}"

    # These fixed-season Sunday commemorations accompany the numbered Sunday.
    # Both are explicit in the official 2026 calendar (July 19 and October 11).
    for month, first, last, title in [
        (7, 13, 19, "Sunday of the Fathers of the Six Ecumenical Councils"),
        (10, 11, 17, "Sunday of the Fathers of the Seventh Ecumenical Council"),
    ]:
        for day_number in range(first, last + 1):
            date = dt.date(year, month, day_number)
            if date.weekday() == 6:
                days[date.isoformat()]["title"] += f"; {title}"

    return dict(sorted(days.items()))


CACHE_DIR: Path | None = None
LAST_EVANGELIZO_REQUEST = 0.0


def fetch_json(url: str, cache_name: str):
    cache_file = CACHE_DIR / f"{cache_name}.json" if CACHE_DIR else None
    if cache_file and cache_file.exists():
        return json.loads(cache_file.read_text(encoding="utf-8"))
    if url.startswith("https://publication.evangelizo.ws/"):
        global LAST_EVANGELIZO_REQUEST
        time.sleep(max(0.0, LAST_EVANGELIZO_REQUEST + 1.1 - time.monotonic()))
        LAST_EVANGELIZO_REQUEST = time.monotonic()
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
    parser.add_argument("--ugcc-only", action="store_true", help="regenerate both Byzantine Pascha styles offline")
    parser.add_argument("--syriac-only", action="store_true", help="refresh English/Arabic Syriac liturgy and saints only")
    parser.add_argument("--until", type=dt.date.fromisoformat, help="last Syriac date to fetch (otherwise follow the source horizon)")
    args = parser.parse_args()
    if args.self_test:
        assert julian_easter(2026) == dt.date(2026, 4, 12)
        assert julian_easter(2027) == dt.date(2027, 5, 2)
        assert ugcc_days(2026)["2026-09-06"]["title"] == "14th Sunday after Pentecost"
        assert ugcc_days(2026, "gregorian")["2026-09-06"]["title"] == "15th Sunday after Pentecost"
        assert ugcc_days(2026)["2026-05-31"]["title"] == "The Descent of the Holy Spirit — Pentecost"
        catalog = {"Feast": "חג", "Other observance": "זכר", "Saint": "קדוש"}
        days = {
            "2026-09-05": {"title": "Saint", "rank": "Memorial", "titleByLanguage": {"ar": "existing"}},
            "2027-09-05": {"title": "Saint", "rank": "Feast"},
            "2026-09-06": {"title": "Unknown", "rank": "Sunday"},
            "2026-09-07": {"title": "Feast", "rank": "Feast", "titleByLanguage": {"he": "earlier catalog text"}},
            "2026-09-08": {"title": "Uncatalogued", "rank": "Feast", "titleByLanguage": {"he": "authored"}},
        }
        originals = {date: (row["title"], row["rank"]) for date, row in days.items()}
        added, missing = localize_feast_days(days, catalog)
        assert added == 3 and missing == {"Unknown"}
        assert {date: (row["title"], row["rank"]) for date, row in days.items()} == originals
        assert days["2026-09-05"]["titleByLanguage"] == {"ar": "existing", "he": "קדוש"}
        assert days["2027-09-05"]["titleByLanguage"]["he"] == "קדוש"
        assert days["2026-09-07"]["titleByLanguage"]["he"] == "חג"
        assert days["2026-09-08"]["titleByLanguage"]["he"] == "authored"
        snapshot = json.dumps(days, ensure_ascii=False)
        assert localize_feast_days(days, catalog) == (0, {"Unknown"})
        assert json.dumps(days, ensure_ascii=False) == snapshot
        assert localized_feast_title("Feast; Other observance", catalog) == "חג; זכר"
        assert localized_feast_title("Feast; Unknown", catalog) == "חג; Unknown"
        assert localized_feast_title("Different saint", catalog) is None
        assert hebrew_title_typography("בר-נבא; ה-22; 1–3; חג — זכר") == "בר־נבא; ה־22; 1–3; חג — זכר"
        catalog["Saint"] = "קדוש, כהן"
        assert localize_feast_days(days, catalog) == (2, {"Unknown"})
        assert days["2026-09-05"]["titleByLanguage"] == {"ar": "existing", "he": "קדוש, כהן"}
        hebrew_title_catalog()  # Validate every checked-in label has a source and no conflict.
        fixture = {"events": {"SaintIdentity": {
            "englishTitles": ["Saint"], "reviewedEnglishAliases": ["St."],
            "titleByLanguage": {"fr": "Saint français", "it": "Santo italiano"},
            "sources": {"fr": ["https://example.org/fr"], "it": ["https://example.org/it"]},
        }}}
        sourced = sourced_title_catalogs(fixture)
        assert add_sourced_feast_titles(days, sourced) == {"fr": 2, "it": 2}
        assert {date: (row["title"], row["rank"]) for date, row in days.items()} == originals
        assert days["2026-09-05"]["titleByLanguage"]["ar"] == "existing"
        assert days["2026-09-05"]["titleByLanguage"]["he"] == "קדוש, כהן"
        assert "titleByLanguage" not in days["2026-09-06"]
        assert add_sourced_feast_titles(days, sourced) == {"fr": 0, "it": 0}
        assert localized_feast_title("St.", sourced["fr"]) == "Saint français"
        assert localized_feast_title("Saint; Unknown", sourced["it"]) == "Santo italiano; Unknown"
        assert localized_feast_title("Different Saint", sourced["fr"]) is None
        fixture["events"]["ConflictingIdentity"] = {
            "englishTitles": ["St."], "titleByLanguage": {"fr": "Other saint"},
            "sources": {"fr": ["https://example.org/other"]},
        }
        try:
            sourced_title_catalogs(fixture)
        except ValueError as error:
            assert "conflicting feast identity" in str(error)
        else:
            raise AssertionError("Conflicting localized feast aliases must be rejected")
        sourced_real = sourced_title_catalogs()
        assert sourced_real["fr"]["Saint Teresa of Calcutta, Virgin"] == "Sainte Teresa de Calcutta, vierge"
        assert sourced_real["it"]["St. Bonaventure"] == "San Bonaventura, vescovo e dottore"
        print("feast localization self-test passed")
        return 0
    if args.localize_only:
        localize_existing_datasets()
        if args.sync:
            sync_datasets()
        return 0
    years = args.years or [dt.date.today().year, dt.date.today().year + 1]
    if args.ugcc_only:
        write_ugcc_datasets(years)
        localize_existing_datasets()
        if args.sync:
            sync_datasets()
        return 0
    if args.cache:
        global CACHE_DIR
        CACHE_DIR = args.cache
        CACHE_DIR.mkdir(parents=True, exist_ok=True)

    if args.syriac_only:
        write_syriac_dataset(syriac_days(years[0], args.until))
        localize_existing_datasets({"feasts-syriac"})
        if args.sync:
            sync_datasets()
        return 0

    roman: dict = {}
    vetus: dict = {}
    ugcc: dict = {}
    for year in years:
        roman.update(roman_days(year))
        vetus.update(roman1962_days(year))
        ugcc.update(ugcc_days(year))
    syriac = syriac_days(years[0], args.until)
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
    write_syriac_dataset(syriac)
    obsolete = DATA / "feasts-roman-he.json"
    if obsolete.exists():
        obsolete.unlink()
        print(f"removed obsolete {obsolete.relative_to(ROOT)}")
    write_ugcc_datasets(years)

    localize_existing_datasets()

    if args.sync:
        sync_datasets()
    return 0


def write_syriac_dataset(days: dict) -> None:
    # Validate every locale before replacing the last complete generated dataset.
    localize_syriac_days(days, feast_title_catalogs())
    write_dataset(DATA / "feasts-syriac.json",
                  "West Syriac — Syriac Catholic: liturgical day titles and every listed saint "
                  "from Evangelizo.org — Daily Gospel (© Evangelizo.org), publication editions "
                  "SYE and SYA, with attribution on every platform's About screen. Named liturgy "
                  "and commemorations are combined using reviewed bilingual identities, not "
                  "array positions or another rite's dates. Plain-date ferial captions are omitted "
                  "without discarding their saints. English saint names retain SYE spelling; "
                  "Arabic supplies additional observances. Reviewed identities are separate "
                  "from display names. Arabic source labels are retained; all eight interface "
                  "languages have reviewed labels, and missing translations block regeneration. "
                  "The supplied Urtotho Hebrew Syriac calendar (2026), preserved in Shared/tools/sources, "
                  "provides Syriac-only labels and exact-day saint descriptions through a reviewed UID index; "
                  "it does not change dates, ranks, or other calendars. Existing preferred Hebrew Thomas "
                  "and Pentecost labels remain. Source class suffixes are not converted into Roman ranks. "
                  "Regenerate with Shared/tools/fetch-feasts.py --syriac-only --sync; Evangelizo "
                  "has a rolling future horizon, and --until may bound a refresh to a known range.",
                  sorted({int(key[:4]) for key in days}), days)


def write_ugcc_datasets(years: list[int]) -> None:
    for style, suffix in (("julian", ""), ("gregorian", "-gregorian")):
        days = {}
        for year in years:
            days.update(ugcc_days(year, style))
        write_dataset(DATA / f"feasts-ugcc{suffix}.json",
                      f"Byzantine Ukrainian Greek Catholic calendar: new-style fixed feasts with {style.title()} Pascha. Fixed menologion and movable cycle curated in Shared/tools/fetch-feasts.py. Default Julian Pascha follows the UGCC in Ukraine; Gregorian Pascha is an explicit alternate usage. The corresponding reading table must use the same Pascha style. Research and source links in Shared/calendar-research.markdown.", years, days)


if __name__ == "__main__":
    raise SystemExit(main())

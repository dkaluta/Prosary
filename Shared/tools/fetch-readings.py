#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["requests"]
# ///
"""Refresh the offline citation tables used by the selected liturgical calendar.

Only Scripture *citations* are retained, never the Scripture text. The generated files are:

* ``readings-roman.json`` — Novus Ordo, Evangelizo HE; sourced Hebrew full book names are
  retained in ``fullByLanguage.he`` and compacted deterministically for ``shortByLanguage.he``.
* ``readings-roman1962.json`` — Vetus Ordo, Missale Meum's public v5 proper API.
* ``readings-ugcc.json`` — Byzantine/UGCC Gregorian usage, Royal Doors' published calendar.
* ``readings-syriac.json`` — Syriac Catholic, Evangelizo SYE.

Use ``--sync`` to copy the four tables into every native port. Existing dates are retained,
so the rolling Evangelizo horizon grows rather than erasing previously fetched days.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import json
import re
import shutil
import time
from pathlib import Path
from typing import Any

import requests

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "Shared" / "data"
TARGETS = [
    ROOT / "iOS" / "Prosary" / "Data",
    ROOT / "Android" / "app" / "src" / "main" / "assets" / "data",
    ROOT / "Windows" / "Prosary" / "Data",
]

EVANGELIZO_URL = "https://publication.evangelizo.ws/{edition}/days/{date}"
MISSALE_MEUM_URL = "https://www.missalemeum.com/en/api/v5/proper/{date}"
ROYAL_DOORS_ICS = (
    "https://calendar.google.com/calendar/ical/"
    "ugccliturgy%40gmail.com/public/basic.ics"
)
HEADERS = {"User-Agent": "Prosary offline citation generator (+https://prayers.prosary.app)"}

# Evangelizo uses compact internal book codes. The first two values are Prosary's English
# short/full forms; the API itself supplies the Hebrew forms used for the HE localization.
EVANGELIZO_BOOKS = {
    "Gn": ("Gen.", "Genesis"), "Ex": ("Exod.", "Exodus"),
    "Lv": ("Lev.", "Leviticus"), "Nb": ("Num.", "Numbers"),
    "Dt": ("Deut.", "Deuteronomy"), "Jos": ("Josh.", "Joshua"),
    "Jg": ("Judg.", "Judges"), "Rt": ("Ruth", "Ruth"),
    "1_S": ("1 Sam.", "1 Samuel"), "2_S": ("2 Sam.", "2 Samuel"),
    "1_K": ("1 Kgs.", "1 Kings"), "2_K": ("2 Kgs.", "2 Kings"),
    "1_Ch": ("1 Chr.", "1 Chronicles"), "2_Ch": ("2 Chr.", "2 Chronicles"),
    "Ezr": ("Ezra", "Ezra"), "Ne": ("Neh.", "Nehemiah"),
    "Tb": ("Tob.", "Tobit"), "Jdt": ("Jdt.", "Judith"),
    "Est": ("Esth.", "Esther"), "1_M": ("1 Macc.", "1 Maccabees"),
    "2_M": ("2 Macc.", "2 Maccabees"), "Jb": ("Job", "Job"),
    "Ps": ("Ps.", "Psalm"), "Pr": ("Prov.", "Proverbs"),
    "Qo": ("Eccl.", "Ecclesiastes"), "Sg": ("Song", "Song of Songs"),
    "Ws": ("Wis.", "Wisdom"), "Si": ("Sir.", "Sirach"),
    "Is": ("Isa.", "Isaiah"), "Jr": ("Jer.", "Jeremiah"),
    "Lm": ("Lam.", "Lamentations"), "Ba": ("Bar.", "Baruch"),
    "Ezk": ("Ezek.", "Ezekiel"), "Dn": ("Dan.", "Daniel"),
    "Ho": ("Hos.", "Hosea"), "Jl": ("Joel", "Joel"),
    "Am": ("Amos", "Amos"), "Ob": ("Obad.", "Obadiah"),
    "Jon": ("Jon.", "Jonah"), "Mi": ("Mic.", "Micah"),
    "Na": ("Nah.", "Nahum"), "Hab": ("Hab.", "Habakkuk"),
    "Zp": ("Zeph.", "Zephaniah"), "Hg": ("Hag.", "Haggai"),
    "Zc": ("Zech.", "Zechariah"), "Ml": ("Mal.", "Malachi"),
    "Mt": ("Mt.", "Matthew"), "Mc": ("Mk.", "Mark"),
    "Lc": ("Lk.", "Luke"), "Jn": ("Jn.", "John"),
    "Ac": ("Acts", "Acts"), "Rm": ("Rom.", "Romans"),
    "1_Co": ("1 Cor.", "1 Corinthians"), "2_Co": ("2 Cor.", "2 Corinthians"),
    "Ga": ("Gal.", "Galatians"), "Ep": ("Eph.", "Ephesians"),
    "Ph": ("Phil.", "Philippians"), "Col": ("Col.", "Colossians"),
    "1_Th": ("1 Thess.", "1 Thessalonians"),
    "2_Th": ("2 Thess.", "2 Thessalonians"),
    "1_Tm": ("1 Tim.", "1 Timothy"), "2_Tm": ("2 Tim.", "2 Timothy"),
    "Tt": ("Titus", "Titus"), "Phm": ("Phlm.", "Philemon"),
    "Heb": ("Heb.", "Hebrews"), "Jas": ("Jas.", "James"),
    "1_P": ("1 Pet.", "1 Peter"), "2_P": ("2 Pet.", "2 Peter"),
    "1_Jn": ("1 Jn.", "1 John"), "2_Jn": ("2 Jn.", "2 John"),
    "3_Jn": ("3 Jn.", "3 John"), "Jude": ("Jude", "Jude"),
    "Rv": ("Rev.", "Revelation"), "Ap": ("Rev.", "Revelation"),
}

# Aliases observed in Missale Meum and Royal Doors. Values are the same compact/full pair
# used by the app. This table is intentionally explicit: fuzzy book-name guessing can turn
# prose in an event title into a false Scripture citation.
GENERIC_BOOKS: dict[str, tuple[str, str]] = {}


def aliases(short: str, full: str, *names: str) -> None:
    for name in names:
        GENERIC_BOOKS[name.casefold().rstrip(".")] = (short, full)


aliases("Gen.", "Genesis", "Genesis", "Gen")
aliases("Exod.", "Exodus", "Exodus", "Exod", "Ex")
aliases("Lev.", "Leviticus", "Leviticus", "Lev")
aliases("Num.", "Numbers", "Numbers", "Num")
aliases("Deut.", "Deuteronomy", "Deuteronomy", "Deut")
aliases("Josh.", "Joshua", "Joshua", "Josh")
aliases("Judg.", "Judges", "Judges", "Judg")
aliases("Ruth", "Ruth", "Ruth")
aliases("1 Sam.", "1 Samuel", "1 Samuel", "1 Sam")
aliases("2 Sam.", "2 Samuel", "2 Samuel", "2 Sam")
aliases("1 Kgs.", "1 Kings", "1 Kings", "1 Kgs")
aliases("2 Kgs.", "2 Kings", "2 Kings", "2 Kgs")
aliases("1 Chr.", "1 Chronicles", "1 Chronicles", "1 Chr")
aliases("2 Chr.", "2 Chronicles", "2 Chronicles", "2 Chr")
aliases("Ezra", "Ezra", "Ezra")
aliases("Neh.", "Nehemiah", "Nehemiah", "Neh")
aliases("Tob.", "Tobit", "Tobit", "Tob")
aliases("Jdt.", "Judith", "Judith", "Jdt")
aliases("Esth.", "Esther", "Esther", "Esth")
aliases("1 Macc.", "1 Maccabees", "1 Maccabees", "1 Macc")
aliases("2 Macc.", "2 Maccabees", "2 Maccabees", "2 Macc")
aliases("Job", "Job", "Job")
aliases("Ps.", "Psalm", "Psalm", "Psalms", "Ps")
aliases("Prov.", "Proverbs", "Proverbs", "Prov")
aliases("Eccl.", "Ecclesiastes", "Ecclesiastes", "Eccles", "Eccl")
aliases("Song", "Song of Songs", "Song of Songs", "Canticle of Canticles", "Cant")
aliases("Wis.", "Wisdom", "Wisdom", "Wis")
aliases("Sir.", "Sirach", "Sirach", "Ecclesiasticus", "Ecclus")
aliases("Isa.", "Isaiah", "Isaiah", "Isaias", "Isa")
aliases("Jer.", "Jeremiah", "Jeremiah", "Jer")
aliases("Lam.", "Lamentations", "Lamentations", "Lam")
aliases("Bar.", "Baruch", "Baruch", "Bar")
aliases("Ezek.", "Ezekiel", "Ezekiel", "Ezechiel", "Ezek")
aliases("Dan.", "Daniel", "Daniel", "Dan")
aliases("Hos.", "Hosea", "Hosea", "Hos")
aliases("Joel", "Joel", "Joel")
aliases("Amos", "Amos", "Amos")
aliases("Obad.", "Obadiah", "Obadiah", "Obad")
aliases("Jon.", "Jonah", "Jonah", "Jon")
aliases("Mic.", "Micah", "Micah", "Mic")
aliases("Nah.", "Nahum", "Nahum", "Nah")
aliases("Hab.", "Habakkuk", "Habakkuk", "Hab")
aliases("Zeph.", "Zephaniah", "Zephaniah", "Zeph")
aliases("Hag.", "Haggai", "Haggai", "Hag")
aliases("Zech.", "Zechariah", "Zechariah", "Zech")
aliases("Mal.", "Malachi", "Malachi", "Mal")
aliases("Mt.", "Matthew", "Matthew", "Matt", "Mt")
aliases("Mk.", "Mark", "Mark", "Mk")
aliases("Lk.", "Luke", "Luke", "Lk")
aliases("Jn.", "John", "John", "Jn", "Joannes")
aliases("Acts", "Acts", "Acts")
aliases("Rom.", "Romans", "Romans", "Rom")
aliases("1 Cor.", "1 Corinthians", "1 Corinthians", "1 Cor")
aliases("2 Cor.", "2 Corinthians", "2 Corinthians", "2 Cor")
aliases("Gal.", "Galatians", "Galatians", "Gal")
aliases("Eph.", "Ephesians", "Ephesians", "Eph")
aliases("Phil.", "Philippians", "Philippians", "Phil")
aliases("Col.", "Colossians", "Colossians", "Col")
aliases("1 Thess.", "1 Thessalonians", "1 Thessalonians", "1 Thess")
aliases("2 Thess.", "2 Thessalonians", "2 Thessalonians", "2 Thess")
aliases("1 Tim.", "1 Timothy", "1 Timothy", "1 Tim")
aliases("2 Tim.", "2 Timothy", "2 Timothy", "2 Tim")
aliases("Titus", "Titus", "Titus")
aliases("Phlm.", "Philemon", "Philemon", "Phlm")
aliases("Heb.", "Hebrews", "Hebrews", "Hebrew", "Heb")
aliases("Jas.", "James", "James", "Jas")
aliases("1 Pet.", "1 Peter", "1 Peter", "1 Pet")
aliases("2 Pet.", "2 Peter", "2 Peter", "2 Pet")
aliases("1 Jn.", "1 John", "1 John", "1 Jn")
aliases("2 Jn.", "2 John", "2 John", "2 Jn")
aliases("3 Jn.", "3 John", "3 John", "3 Jn")
aliases("Jude", "Jude", "Jude")
aliases("Rev.", "Revelation", "Revelation", "Apocalypse", "Rev")

_BOOK_PATTERN = "|".join(
    re.escape(name).replace(r"\ ", r"\s+") + r"\.?"
    for name in sorted(GENERIC_BOOKS, key=len, reverse=True)
)
_VERSE = r"\d+[a-z]?(?:[–-](?:(?:\d+:)?\d+[a-z]?))?"
_REFERENCE = rf"\d+:{_VERSE}(?:,\s*(?:(?:\d+:)?{_VERSE}))*"
GENERIC_CITATION = re.compile(
    rf"(?<![\w])(?P<book>{_BOOK_PATTERN})\s+(?P<reference>{_REFERENCE})",
    re.IGNORECASE,
)
CONTINUATION = re.compile(rf"^\s*(?P<reference>{_VERSE}(?:,\s*{_VERSE})*)\s*[.]?\s*$")
GOSPEL_BOOKS = {"Matthew", "Mark", "Luke", "John"}


def hebrew_numeral(value: int) -> str:
    """Traditional Hebrew-number spelling with geresh/gershayim (15/16 avoid the Name)."""
    if not 1 <= value <= 999:
        raise ValueError(f"Hebrew chapter number out of range: {value}")
    letters: list[str] = []
    while value >= 400:
        letters.append("ת")
        value -= 400
    for amount, letter in ((300, "ש"), (200, "ר"), (100, "ק")):
        if value >= amount:
            letters.append(letter)
            value -= amount
    if value in (15, 16):
        letters.extend(("ט", "ו" if value == 15 else "ז"))
        value = 0
    else:
        for amount, letter in (
                (90, "צ"), (80, "פ"), (70, "ע"), (60, "ס"), (50, "נ"),
                (40, "מ"), (30, "ל"), (20, "כ"), (10, "י"), (9, "ט"),
                (8, "ח"), (7, "ז"), (6, "ו"), (5, "ה"), (4, "ד"),
                (3, "ג"), (2, "ב"), (1, "א")):
            if value >= amount:
                letters.append(letter)
                value -= amount
    raw = "".join(letters)
    return f"{raw}׳" if len(raw) == 1 else f"{raw[:-1]}״{raw[-1]}"


def hebrew_reference(reference: str) -> str:
    """Use gematria for every chapter and a space before Arabic-numeral verses."""
    return re.sub(
        r"(?<!\d)(\d+):",
        lambda match: f"{hebrew_numeral(int(match.group(1)))} ",
        reference,
    )


def hebrew_short_book_title(title: str) -> str:
    """Compact a sourced Hebrew epistle title without translating its book name.

    Evangelizo's ``short_title`` is not consistently short: depending on the book/date it
    may repeat ``אגרת`` and the author's name, or it may already use a compact form.
    Today only needs the distinctive recipient/ordinal while the complete, source-authored
    title remains untouched in ``fullByLanguage``.
    """
    source_title = title.strip()
    title = re.sub(r"\s+", " ", source_title).replace("השניה", "השנייה")

    # Pauline titles retain the sourced recipient and, for numbered letters, the ordinal.
    pauline = re.fullmatch(r"(?:אגרת|איגרת) שאול (.+)", title)
    if pauline:
        return pauline.group(1)

    already_compact_pauline = re.fullmatch(
        r"(?:הראשונה|השנייה|השלישית) אל .+|אל .+", title)
    if already_compact_pauline:
        return title

    # Hebrews has no named author in the source title.
    hebrews = re.fullmatch(r"(?:האגרת|האיגרת) (.+)", title)
    if hebrews:
        return hebrews.group(1)

    # The catholic epistles name the author before the ordinal in the full title. Compact
    # Hebrew reads more naturally with the ordinal first: "השנייה של כיפא".
    catholic = re.fullmatch(
        r"(?:אגרת|איגרת) (.+?) "
        r"(הראשונה|השנייה|השלישית)",
        title,
    )
    if catholic:
        author, ordinal = catholic.groups()
        return f"{ordinal} של {author}"

    already_compact_catholic = re.fullmatch(
        r"(הראשונה|השנייה|השלישית) ל(.+)", title)
    if already_compact_catholic:
        ordinal, author = already_compact_catholic.groups()
        return f"{ordinal} של {author}"

    # Unnumbered catholic epistles need only their source-authored book/author name.
    unnumbered = re.fullmatch(r"(?:אגרת|איגרת) (.+)", title)
    return unnumbered.group(1) if unnumbered else source_title


def hebrew_short_citation(text: str) -> str:
    """Compact a Hebrew book title and convert its trailing chapter to gematria."""
    citation = re.sub(
        r"(?<!\d)(\d+)\s*$",
        lambda match: hebrew_numeral(int(match.group(1))),
        text,
    )
    chapter = re.fullmatch(r"(.+?)\s+([א-ת]+[׳״])", citation)
    if not chapter:
        return hebrew_short_book_title(citation)
    book, numeral = chapter.groups()
    return f"{hebrew_short_book_title(book)} {numeral}"


def request(url: str, *, json_response: bool = True) -> Any:
    response: requests.Response | None = None
    for attempt in range(4):
        try:
            response = requests.get(url, headers=HEADERS, timeout=30)
            if response.status_code == 200:
                return response.json() if json_response else response.text
            if response.status_code == 400:
                return None
            if response.status_code == 429:
                retry_after = response.headers.get("Retry-After", "")
                wait = float(retry_after) if retry_after.isdigit() else 15.0 * (attempt + 1)
                print(f"  rate limited by source; retrying in {wait:g}s")
                time.sleep(wait)
                continue
        except (requests.RequestException, ValueError):
            pass
        time.sleep(0.5 * (attempt + 1))
    status = response.status_code if response is not None else "no response"
    print(f"  warning: {url} failed ({status})")
    return None


def normalized_evangelizo_reference(raw: str) -> str:
    parts: list[str] = []
    for segment in raw.split("#"):
        segment = re.sub(r"^[^ ]+\s+", "", segment.strip())
        segment = re.sub(r"^(\d+),", r"\1:", segment, count=1)
        parts.append(segment.replace("-", "–"))
    return "; ".join(part for part in parts if part)


def type_for_book(full_book: str) -> str:
    if full_book in GOSPEL_BOOKS:
        return "gospel"
    if full_book == "Psalm":
        return "psalm"
    return "reading"


def citation(short_book: str, full_book: str, reference: str, kind: str | None = None) -> dict:
    reference = reference.replace("-", "–").strip().rstrip(".")
    chapter = re.search(r"\d+", reference)
    return {
        "type": kind or type_for_book(full_book),
        "short": f"{short_book} {chapter.group(0)}" if chapter else short_book,
        "full": f"{full_book} {reference}",
    }


def generic_citations(text: str) -> list[dict]:
    """Extract explicit ``Book chapter:verse`` citations from sourced prose/calendar text."""
    found: list[dict] = []
    for segment in text.replace("*", "").split(";"):
        matches = list(GENERIC_CITATION.finditer(segment))
        if not matches:
            continuation = CONTINUATION.match(segment)
            if continuation and found:
                suffix = continuation.group("reference").replace("-", "–")
                found[-1]["full"] += f"; {suffix}"
            continue
        for match in matches:
            key = re.sub(r"\s+", " ", match.group("book").rstrip(".")).casefold()
            short_book, full_book = GENERIC_BOOKS[key]
            item = citation(short_book, full_book, match.group("reference"))
            if item["full"] not in {prior["full"] for prior in found}:
                found.append(item)
    return found


def evangelizo_day(day: dt.date, edition: str) -> tuple[str, dict] | None:
    payload = request(EVANGELIZO_URL.format(edition=edition, date=day.isoformat()))
    if not payload:
        return None
    readings: list[dict] = []
    for source in (payload.get("data") or {}).get("readings") or []:
        code = (source.get("reading_code") or "").strip()
        match = re.match(r"([^ ]+)\s+(.+)", code)
        if not match:
            continue
        book_code, raw_reference = match.groups()
        short_book, full_book = EVANGELIZO_BOOKS.get(
            book_code, (book_code.replace("_", " "), book_code.replace("_", " ")))
        reference = normalized_evangelizo_reference(raw_reference)
        item = citation(short_book, full_book, reference, source.get("type") or "reading")
        if edition == "HE":
            book = source.get("book") or {}
            short_hebrew = (book.get("short_title") or book.get("full_title") or "").strip()
            full_hebrew = (book.get("full_title") or book.get("short_title") or "").strip()
            if short_hebrew:
                chapter = re.search(r"\d+", reference)
                item["shortByLanguage"] = {
                    "he": hebrew_short_citation(
                        f"{short_hebrew} {chapter.group(0)}" if chapter else short_hebrew)
                }
            if full_hebrew:
                item["fullByLanguage"] = {"he": f"{full_hebrew} {hebrew_reference(reference)}"}
        readings.append(item)
    return (day.isoformat(), {"readings": readings}) if readings else None


def missale_meum_day(day: dt.date) -> tuple[str, dict] | None:
    payload = request(MISSALE_MEUM_URL.format(date=day.isoformat()))
    if not payload:
        return None
    readings: list[dict] = []
    for proper in payload:
        for section in proper.get("sections") or []:
            identifier = str(section.get("id") or "").casefold()
            label = str(section.get("label") or "").casefold()
            if not any(word in identifier or word in label
                       for word in ("lectio", "lesson", "epistle", "prophe", "evangel", "gospel")):
                continue
            body = section.get("body") or []
            english = body[0][0] if body and body[0] else ""
            extracted = generic_citations(english)
            if extracted:
                # A lesson's first starred reference is the appointed citation. Limiting each
                # section prevents incidental cross-references in the supplied Scripture text.
                item = extracted[0]
                if "evangel" in identifier or "gospel" in label:
                    item["type"] = "gospel"
                if item["full"] not in {prior["full"] for prior in readings}:
                    readings.append(item)
    return (day.isoformat(), {"readings": readings}) if readings else None


def unfold_ics(text: str) -> str:
    unfolded = re.sub(r"\r?\n[ \t]", "", text)
    return unfolded.replace("\r\n", "\n").replace("\r", "\n")


def unescape_ics(value: str) -> str:
    return (value.replace(r"\n", "\n").replace(r"\N", "\n")
            .replace(r"\,", ",").replace(r"\;", ";").replace(r"\\", "\\"))


def royal_doors_days(wanted: set[str]) -> dict[str, dict]:
    text = request(ROYAL_DOORS_ICS, json_response=False)
    if not text:
        return {}
    days: dict[str, dict] = {}
    for block in unfold_ics(text).split("BEGIN:VEVENT")[1:]:
        date_match = re.search(r"^DTSTART(?:;VALUE=DATE)?:([0-9]{8})$", block, re.MULTILINE)
        summary_match = re.search(r"^SUMMARY:(.*)$", block, re.MULTILINE)
        if not date_match or not summary_match:
            continue
        raw_date = date_match.group(1)
        date = f"{raw_date[:4]}-{raw_date[4:6]}-{raw_date[6:]}"
        if date not in wanted:
            continue
        extracted = generic_citations(unescape_ics(summary_match.group(1)))
        if not extracted:
            continue
        row = days.setdefault(date, {"readings": []})
        existing = {item["full"] for item in row["readings"]}
        row["readings"].extend(item for item in extracted if item["full"] not in existing)
    return days


def normalized_existing_days(path: Path, legacy: Path | None = None) -> dict[str, dict]:
    source = path if path.exists() else legacy
    if source is None or not source.exists():
        return {}
    days = json.loads(source.read_text(encoding="utf-8")).get("days", {})
    for row in days.values():
        for item in row.get("readings", []):
            hebrew = item.pop("hebrew", None)
            if hebrew:
                item.setdefault("fullByLanguage", {})["he"] = hebrew
                chapter = re.search(r"\d+", hebrew)
                hebrew_book = hebrew[:chapter.start()].strip() if chapter else hebrew
                item.setdefault("shortByLanguage", {})["he"] = (
                    f"{hebrew_book} {chapter.group(0)}" if chapter else hebrew_book)
            full_hebrew = (item.get("fullByLanguage") or {}).get("he")
            if full_hebrew:
                item.setdefault("fullByLanguage", {})["he"] = hebrew_reference(full_hebrew)
            short_hebrew = (item.get("shortByLanguage") or {}).get("he")
            if short_hebrew:
                item.setdefault("shortByLanguage", {})["he"] = hebrew_short_citation(short_hebrew)
    return days


def existing_dates(name: str, *, legacy: str | None = None) -> set[str]:
    return set(normalized_existing_days(
        DATA / f"{name}.json", DATA / legacy if legacy else None))


def write_dataset(name: str, comment: str, refreshed: dict[str, dict], *, legacy: str | None = None) -> Path:
    destination = DATA / f"{name}.json"
    existing = normalized_existing_days(destination, DATA / legacy if legacy else None)
    existing.update(refreshed)
    payload = {
        "$comment": comment,
        "generated": dt.date.today().isoformat(),
        "days": dict(sorted(existing.items())),
    }
    destination.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {destination.relative_to(ROOT)} ({len(existing)} days; refreshed {len(refreshed)})")
    return destination


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days-back", type=int, default=31)
    parser.add_argument("--days-ahead", type=int, default=100)
    parser.add_argument(
        "--sources", nargs="+",
        choices=("roman", "roman1962", "ugcc", "syriac"),
        default=("roman", "roman1962", "ugcc", "syriac"),
        help="refresh only these tables (all by default)")
    parser.add_argument(
        "--refresh-existing", action="store_true",
        help="re-fetch dates already present; by default only missing dates hit the network")
    parser.add_argument("--sync", action="store_true")
    parser.add_argument(
        "--self-test", action="store_true",
        help="run citation-format/parser assertions without fetching data")
    args = parser.parse_args()

    if args.self_test:
        assert hebrew_numeral(1) == "א׳"
        assert hebrew_numeral(3) == "ג׳"
        assert hebrew_numeral(15) == "ט״ו"
        assert hebrew_numeral(16) == "ט״ז"
        assert hebrew_numeral(119) == "קי״ט"
        assert hebrew_reference("1:1–2:2; 15:3–16") == "א׳ 1–ב׳ 2; ט״ו 3–16"
        assert hebrew_short_citation("יוחנן 3") == "יוחנן ג׳"
        assert hebrew_short_citation("אגרת שאול הראשונה אל הקורינתים 4") == \
            "הראשונה אל הקורינתים ד׳"
        assert hebrew_short_citation("אגרת כיפא השניה 2") == "השנייה של כיפא ב׳"
        assert hebrew_short_citation("אגרת שאול אל הרומים 8") == "אל הרומים ח׳"
        assert hebrew_short_citation("השניה ליוחנן 1") == "השנייה של יוחנן א׳"
        print("citation self-test passed")
        return

    today = dt.date.today()
    days = [today + dt.timedelta(days=offset)
            for offset in range(-args.days_back, args.days_ahead + 1)]
    rows: dict[str, dict[str, dict]] = {"roman": {}, "syriac": {}, "roman1962": {}}
    selected = set(args.sources)

    # Evangelizo asks clients not to burst the publication service. Fetch its two editions
    # serially and pause between missing dates; the one-second cadence stays below the
    # observed rate limit. Stable existing citations are skipped unless explicitly refreshed.
    for source, edition, legacy in (
            ("roman", "HE", "readings.json"), ("syriac", "SYE", None)):
        if source not in selected:
            continue
        present = set() if args.refresh_existing else existing_dates(f"readings-{source}")
        if legacy and not present:
            present = existing_dates("readings-roman", legacy=legacy)
        for day in days:
            if day.isoformat() in present:
                continue
            result = evangelizo_day(day, edition)
            if result:
                date, row = result
                rows[source][date] = row
            time.sleep(1.05)

    if "roman1962" in selected:
        present = (set() if args.refresh_existing
                   else existing_dates("readings-roman1962"))
        vetus_days = [day for day in days if day.isoformat() not in present]
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            for result in pool.map(missale_meum_day, vetus_days):
                if result:
                    date, row = result
                    rows["roman1962"][date] = row

    rows["ugcc"] = (royal_doors_days({day.isoformat() for day in days})
                    if "ugcc" in selected else {})

    if "roman" in selected:
        write_dataset(
            "readings-roman",
            "Novus Ordo daily lectionary citations courtesy of Evangelizo.org — Daily "
            "Gospel (© Evangelizo.org), publication edition HE. Hebrew full book titles "
            "are relayed from the source; short titles are source-preserving compact forms. "
            "Scripture text is not included.",
            rows["roman"], legacy="readings.json")
    if "roman1962" in selected:
        write_dataset(
            "readings-roman1962",
            "Roman 1962 (Vetus Ordo) appointed Epistle/Gospel citations from Missale "
            "Meum's public v5 proper API (MIT); Scripture text is not included.",
            rows["roman1962"])
    if "ugcc" in selected:
        write_dataset(
            "readings-ugcc",
            "Byzantine Ukrainian Greek Catholic citations from Royal Doors' published "
            "UGCC Liturgical Year (Gregorian) calendar; Scripture text is not included.",
            rows["ugcc"])
    if "syriac" in selected:
        write_dataset(
            "readings-syriac",
            "West Syriac Catholic daily lectionary citations courtesy of Evangelizo.org — "
            "Daily Gospel (© Evangelizo.org), publication edition SYE; Scripture text is "
            "not included.",
            rows["syriac"])

    obsolete = DATA / "readings.json"
    if obsolete.exists():
        obsolete.unlink()
        print(f"removed obsolete {obsolete.relative_to(ROOT)}")

    if args.sync:
        outputs = [DATA / f"readings-{source}.json"
                   for source in ("roman", "roman1962", "ugcc", "syriac")]
        for target in TARGETS:
            target.mkdir(parents=True, exist_ok=True)
            for source in outputs:
                shutil.copy2(source, target / source.name)
            shutil.copy2(DATA / "calendars.json", target / "calendars.json")
            stale = target / "readings.json"
            if stale.exists():
                stale.unlink()
            print(f"synced -> {target.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

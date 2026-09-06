#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["requests", "beautifulsoup4"]
# ///
"""Import appointed readings from the UGCC Patriarchal Liturgical Commission.

Ukraine's new-style fixed feasts retain Julian Pascha. Royal Doors' fully Gregorian
calendar is a different usage and must not populate this table. Import references only,
never prayer or Scripture text. A checked-in source snapshot makes rebuilds offline.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import re
import shutil
from pathlib import Path

import requests
from bs4 import BeautifulSoup

TOOLS = Path(__file__).resolve().parent
SHARED = TOOLS.parent
ROOT = SHARED.parent
SOURCE = "https://ugcc.ua/data/tserkovnyy-kalendar-ugkts-na-2026-rik-8059/"
SNAPSHOT = TOOLS / "ugcc-readings-2026.json"
BOOKS = {
    "Мт": ("Mt.", "Matthew"), "Мр": ("Mk.", "Mark"), "Мк": ("Mk.", "Mark"), "Лк": ("Lk.", "Luke"),
    "Ів": ("Jn.", "John"), "Ді": ("Acts", "Acts"), "Рим": ("Rom.", "Romans"),
    "І Кор": ("1 Cor.", "1 Corinthians"), "ІІ Кор": ("2 Cor.", "2 Corinthians"),
    "Гал": ("Gal.", "Galatians"), "Еф": ("Eph.", "Ephesians"),
    "Флп": ("Phil.", "Philippians"), "Кол": ("Col.", "Colossians"),
    "І Сол": ("1 Thess.", "1 Thessalonians"), "ІІ Сол": ("2 Thess.", "2 Thessalonians"),
    "І Тим": ("1 Tim.", "1 Timothy"), "ІІ Тим": ("2 Tim.", "2 Timothy"),
    "Тит": ("Titus", "Titus"), "Флм": ("Phlm.", "Philemon"), "Євр": ("Heb.", "Hebrews"),
    "Як": ("Jas.", "James"), "І Пт": ("1 Pet.", "1 Peter"), "ІІ Пт": ("2 Pet.", "2 Peter"),
    "І Ів": ("1 Jn.", "1 John"), "ІІ Ів": ("2 Jn.", "2 John"), "ІІІ Ів": ("3 Jn.", "3 John"),
    "Юд": ("Jude", "Jude"), "Бт": ("Gen.", "Genesis"), "Прип": ("Prov.", "Proverbs"),
    "Іс": ("Isa.", "Isaiah"), "Вих": ("Exod.", "Exodus"), "Йов": ("Job", "Job"),
    "Єз": ("Ezek.", "Ezekiel"), "Єр": ("Jer.", "Jeremiah"), "І Нав": ("Josh.", "Joshua"),
    "Іс Нав": ("Josh.", "Joshua"), "І Цар": ("1 Sam.", "1 Samuel"),
    "ІІІ Цар": ("1 Kings", "1 Kings"), "IV Цар": ("2 Kings", "2 Kings"),
    "Дан": ("Dan.", "Daniel"), "Соф": ("Zeph.", "Zephaniah"), "Йон": ("Jon.", "Jonah"),
    "Зах": ("Zech.", "Zechariah"), "Муд": ("Wis.", "Wisdom"),
}
BOOK_PATTERN = "|".join(re.escape(x).replace(r"\ ", r"\s+") for x in sorted(BOOKS, key=len, reverse=True))
BOOK_START = rf"(?<!\w)(?:{BOOK_PATTERN})[.,;]*\s+"
BOOK_REFERENCE = re.compile(rf"(?<!\w)(?P<book>{BOOK_PATTERN})[.,;]*\s+(?P<rest>.*?)(?={BOOK_START}|$)")
PASSAGE = r"\d+(?:–(?:\d+:)?\d+)?"
CITATION = re.compile(rf"\d+:{PASSAGE}(?:, {PASSAGE})*(?:; \d+:{PASSAGE}(?:, {PASSAGE})*)*\Z")

# Narrow, reviewable repairs to the page's own omissions/typography. Original source
# strings always remain in the snapshot. A future upstream change fails these expectations
# instead of silently receiving an obsolete correction.
SOURCE_CORRECTIONS = {
    "2026-03-06": [("Прип. 6, 20-35-7, 1", "Прип. 6, 20–35; 7, 1",
        "The source joins the end of Proverbs 6 and Proverbs 7:1 with a stray dash; preserve both segments.")],
    "2026-03-13": [("Прип. 10, 31–32, 11, 1–12", "Прип. 10, 31–32; 11, 1–12",
        "The chapter boundary in Proverbs is comma-delimited in the source; retain 10:31–32 and 11:1–12.")],
    "2026-03-15": [("Ап. Єв. 311", "Ап. Євр. 311",
        "Apostolic lection 311 is Hebrews 4:14–5:6; the source abbreviates Hebrews as Єв. by mistake.")],
    "2026-04-01": [("Прип. 21, 23–31: 22, 1–4", "Прип. 21, 23–31; 22, 1–4",
        "The source uses a colon between two chapter segments; retain Proverbs 21:23–31 and 22:1–4.")],
    "2026-04-12": [("Ді. 1 зач.; 1–8", "Ді. 1 зач.; 1, 1–8",
        "Acts lection 1 is Acts 1:1–8; the source omitted chapter 1.")],
    "2026-06-23": [("Єв. 41 зач.; 11, 16–20", "Єв. Мт. 41 зач.; 11, 16–20",
        "Gospel lection 41 is Matthew 11:16–20; the source omitted the book. Confirmed in UGCC's daily homily collection (pdf.ugcc.ua/pub/files/7ad342728d3cdbee.pdf).")],
    "2026-10-26": [("Ап. Тим. 292", "Ап. ІІ Тим. 292",
        "Apostolic lection 292 is 2 Timothy 2:1–10, identified explicitly in this same calendar on February 28 and July 27; the source omitted the epistle number.")],
}
CORRECTION_SOURCES = {
    "2026-03-15": ["https://ecoburougcc.org.ua/index.php/initsiativi/velykoposna-initsiatyva-2020/propovidi"],
    "2026-06-23": ["https://pdf.ugcc.ua/pub/files/7ad342728d3cdbee.pdf"],
}


def corrected_source(date: str, text: str) -> tuple[str, list[str]]:
    normalized = text.replace("\xa0", " ")
    notes = []
    for old, new, note in SOURCE_CORRECTIONS.get(date, []):
        if normalized.count(old) != 1:
            raise ValueError(f"Review changed source correction for {date}: {old}")
        normalized = normalized.replace(old, new)
        notes.append(note)
    return normalized, notes


def normalize_reference(value: str) -> str:
    value = re.sub(r"^(?:зач\.\s*\d+|\d+\s*зач\.)(?:\s*\([^)]*\))?[\s;,]*", "", value)
    value = re.sub(r"\([^)]*\)", "", value)
    value = value.strip(" .;–—")
    value = re.sub(r"\s*[–—-]\s*", "–", value)
    # A chapter's first verse is sometimes redundantly included at a cross-chapter
    # range endpoint (Genesis 5,32–6,1–8). The same passage ends at 6:8.
    value = re.sub(r"–(\d+),\s*1–(\d+)", r"–\1, \2", value)
    # Only the beginning of a segment declares a chapter. Replacing every numeric
    # comma used to turn Mark 15,22,25,33–41 into an invented chapter 25.
    value = re.sub(r"(^|;\s*)(\d+)\s*,\s*(\d+)", r"\1\2:\3", value)
    # A range endpoint with two numbers is a chapter/verse pair. When the second
    # number starts another range it is instead a same-chapter verse list, such as
    # Hebrews 9,8–10,15–23 or Matthew 10,32–33,37–38.
    value = re.sub(r"–(\d+)\s*,\s*(\d+)(?!\d|\s*–)", r"–\1:\2", value)
    value = re.sub(r"\.\s*(?=\d)", ", ", value)
    value = re.sub(r"\s*,\s*", ", ", value)
    value = re.sub(r"(?<=\d)\s+(?=\d)", ", ", value)
    value = re.sub(r"\s*;\s*", "; ", value)
    # A semicolon without a new chapter keeps the current one (Luke 2,20–21;40–52).
    value = re.sub(r"; (?=\d+(?![\d:]))", ", ", value)
    return value


def source_readings(text: str) -> list[dict]:
    lines = [re.sub(r"\s+", " ", line).strip() for line in text.replace("\xa0", " ").splitlines() if line.strip()]
    # The source mixes Latin I/II/III and Ukrainian І/ІІ/ІІІ. Normalize before book
    # matching, otherwise the trailing Ів. becomes John's Gospel instead of an epistle.
    lines = [re.sub(r"(?<!\w)[IІ]{1,3}(?=\s+(?:Кор|Тим|Сол|Пт|Ів)\b)",
                    lambda match: match[0].replace("I", "І"), line) for line in lines]
    # These rows explicitly have no Divine Liturgy. They must not inherit yesterday's or
    # another calendar's readings.
    if any("Літургії не служимо" in line for line in lines):
        return []
    has_liturgy = any(re.search(r"Літ\.|Літургі[яїє]", line) for line in lines)
    result = []
    service = "unlabelled"
    for line in lines:
        if re.search(r"На осв\. води|На освячення|На вмиванні|По вмиванні", line):
            break
        if re.search(r"Утр\.", line):
            continue
        if re.search(r"Літ\.|Літургі[яїє]", line):
            service = "liturgy"
        elif re.search(r"Час шостий|Царські часи|На \d+-", line, re.IGNORECASE):
            service = "hours"
        elif re.search(r"вечірн", line, re.IGNORECASE):
            service = "vespers"
        if has_liturgy and service in {"hours", "vespers"}:
            continue
        matches = list(BOOK_REFERENCE.finditer(line))
        if not matches and re.search(r"(?:Ап|Єв)\..*\d", line):
            raise ValueError(f"Unrecognized Scripture book: {line}")
        for match in matches:
            book = re.sub(r"\s+", " ", match["book"])
            reference = normalize_reference(match["rest"])
            # Jude has one chapter. The source can therefore give verses without '1,'.
            if book == "Юд" and re.fullmatch(r"[\d –,.]+", reference):
                reference = "1:" + reference
            # Stop before subsequent labels, but retain all contiguous reference segments.
            numeric = re.match(r"\d+:[\d:;,. –]+", reference)
            if not numeric:
                if not reference:  # The book is repeated after a lection-only prefix.
                    continue
                raise ValueError(f"Unparsed reference for {book}: {match['rest']}")
            reference = numeric[0].rstrip(" ,.;–")
            if not CITATION.fullmatch(reference):
                raise ValueError(f"Ambiguous citation grammar for {book}: {reference}")
            short, full = BOOKS[book]
            entry = {"type": "gospel" if full in {"Matthew", "Mark", "Luke", "John"} else "reading",
                     "short": f"{short} {reference.split(':')[0]}", "full": f"{full} {reference}"}
            if entry["full"] not in {row["full"] for row in result}:
                result.append(entry)
    return result


def parse_calendar(html: str) -> dict:
    soup = BeautifulSoup(html, "html.parser")
    tables = soup.select("table.e-cal-table")
    if len(tables) != 12:
        raise ValueError(f"Expected 12 calendar months, got {len(tables)}")
    result = {}
    for month, table in enumerate(tables, 1):
        for tr in table.select("tr"):
            cells = tr.find_all("td", recursive=False)
            if len(cells) != 3:
                continue
            day = int(cells[0].get_text(strip=True))
            small = cells[2].find_all("small")
            for br in cells[2].find_all("br"):
                br.replace_with("\n")
            text = "\n".join(x.get_text() for x in small)
            date = dt.date(2026, month, day).isoformat()
            normalized, corrections = corrected_source(date, text)
            try:
                readings = source_readings(normalized)
            except ValueError as exc:
                raise ValueError(f"{date}: {exc}") from exc
            result[date] = {"sourceReferences": text.strip(), "readings": readings}
            if corrections:
                result[date]["sourceCorrection"] = " ".join(corrections)
                result[date]["sourceCorrectionSources"] = CORRECTION_SOURCES.get(date, [SOURCE])
    if len(result) != 365:
        raise ValueError(f"Incomplete calendar: {len(result)} days")
    return result


def self_test(snapshot: dict) -> None:
    cases = {
        "170 зач.; 1, 21–2, 4": "1:21–2:4",
        "68 зач.; 15, 22, 25, 33–41": "15:22, 25, 33–41",
        "38 зач.; 10, 32–33, 37–38; 19, 27–30": "10:32–33, 37–38; 19:27–30",
        "321 зач.; 9, 8–10, 15–23": "9:8–10, 15–23",
        "329 зач.; 11,17–23, 27–31": "11:17–23, 27–31",
        "105 зач.; 21, 8–9 25–27 33–36": "21:8–9, 25–27, 33–36",
        "6 зач.; 2, 20–21; 40–52": "2:20–21, 40–52",
        "5, 32–6, 1–8": "5:32–6:8",
        "49, 33–50, 1–26": "49:33–50:26",
        "233 зач., 6, 10–17": "6:10–17",
        "109 зач.; 22, 39–42. 45–23, 1": "22:39–42, 45–23:1",
    }
    for source, expected in cases.items():
        assert normalize_reference(source) == expected, (source, normalize_reference(source), expected)

    def fulls(date: str) -> list[str]:
        return [row["full"] for row in snapshot["days"][date]["readings"]]

    fixtures = {
        "2026-01-05": ["1 Corinthians 9:19–27", "Luke 3:1–18"],
        "2026-01-06": ["Titus 2:11–14; 3:4–7", "Matthew 3:13–17"],
        "2026-02-13": ["2 John 1:1–13", "Mark 15:22, 25, 33–41"],
        "2026-02-16": ["3 John 1:1–15", "Luke 19:29–40; 22:7–39"],
        "2026-02-18": [],
        "2026-02-20": [],
        "2026-02-23": ["Isaiah 1:1–20", "Genesis 1:1–13", "Proverbs 1:1–20"],
        "2026-03-06": ["Genesis 5:32–6:8", "Proverbs 6:20–35; 7:1"],
        "2026-03-13": ["Genesis 8:4–21", "Proverbs 10:31–32; 11:1–12"],
        "2026-03-15": ["Hebrews 4:14–5:6", "Mark 8:34–9:1"],
        "2026-04-01": ["Genesis 43:26–31; 45:1–16", "Proverbs 21:23–31; 22:1–4"],
        "2026-04-12": ["Acts 1:1–8", "John 1:1–17"],
        "2026-04-19": ["Acts 5:12–20", "John 20:19–31"],
        "2026-06-19": ["Jude 1:1–10", "John 14:21–24", "Hebrews 2:11–18", "John 3:13–17"],
        "2026-06-23": ["Romans 10:11–11:2", "Matthew 11:16–20"],
        "2026-06-27": ["Ephesians 6:10–17", "Matthew 10:16–22"],
        "2026-08-27": ["2 Corinthians 10:7–18", "Mark 3:28–35"],
        "2026-09-03": ["2 Corinthians 9:12–10:7", "Mark 3:20–27"],
        "2026-09-06": ["2 Corinthians 1:21–2:4", "Matthew 22:1–14"],
        "2026-11-17": ["2 Thessalonians 1:10–2:2", "Luke 12:42–48"],
        "2026-11-18": ["2 Thessalonians 2:1–12", "Luke 12:48–59"],
        "2026-11-19": ["2 Thessalonians 2:13–3:5", "Luke 13:1–9"],
        "2026-12-22": ["Hebrews 9:8–10, 15–23", "Mark 8:22–26"],
        "2026-12-24": ["Hebrews 1:1–12", "Luke 2:1–20"],
    }
    for date, expected in fixtures.items():
        assert fulls(date) == expected, (date, fulls(date), expected)
    assert "2 Timothy 2:1–10" in fulls("2026-10-26")
    assert fulls("2026-04-09") == ["1 Corinthians 11:23–32", "Matthew 26:1–20",
        "John 13:3–17", "Matthew 26:21–39", "Luke 22:43–45", "Matthew 26:40–27:2"]
    assert len(fulls("2026-04-10")) == 14  # Hours and Vespers; no Divine Liturgy that day.
    assert len(snapshot["days"]) == 365
    assert sum(bool(row["readings"]) for row in snapshot["days"].values()) == 363
    for date, row in snapshot["days"].items():
        normalized, corrections = corrected_source(date, row["sourceReferences"])
        assert source_readings(normalized) == row["readings"], f"Stale parsed snapshot: {date}"
        if corrections:
            assert row["sourceCorrection"] == " ".join(corrections)
        for reading in row["readings"]:
            reference = re.search(r"\d+:.*", reading["full"])[0]
            assert CITATION.fullmatch(reference), (date, reading)
    try:
        source_readings("Ап. Невідомо 123 зач.; 1, 1–10")
    except ValueError:
        pass
    else:
        raise AssertionError("Unknown books must fail import instead of silently dropping a reading")
    print(f"UGCC calendar checks passed: {len(cases)} punctuation cases, {len(fixtures)} dated fixtures, all 365 source rows and 363 reading days")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--html", type=Path)
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--sync", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.fetch or args.html:
        if args.html:
            html = args.html.read_text()
        else:
            response = requests.get(SOURCE, timeout=60)
            response.raise_for_status()
            html = response.text
        snapshot = {"$comment": "Appointed Scripture references transcribed from the UGCC Patriarchal Liturgical Commission 2026 new-style calendar. References only; source service labels retained for audit. No Scripture or prayer texts. Citations adapted and localized for Prosary.", "source": SOURCE,
                    "calendarUsage": "Ukraine: Gregorian fixed feasts, Julian Pascha",
                    "sourceHtmlSha256": hashlib.sha256(html.encode("utf-8")).hexdigest(), "days": parse_calendar(html)}
        SNAPSHOT.write_text(json.dumps(snapshot, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    snapshot = json.loads(SNAPSHOT.read_text())
    if args.self_test:
        self_test(snapshot)
        return
    spec = importlib.util.spec_from_file_location("readings", TOOLS / "fetch-readings.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    days = {date: {"readings": row["readings"], "sourceUrl": SOURCE} for date, row in snapshot["days"].items() if row["readings"]}
    missing = module.localize_hebrew_readings(days, json.loads(module.HEBREW_BOOKS_FILE.read_text())["books"])
    missing |= module.localize_reading_names(days, json.loads(module.LOCALIZED_BOOKS_FILE.read_text())["books"])
    if missing:
        raise ValueError(f"Missing sourced book labels: {sorted(missing)}")
    payload = {"$comment": snapshot["$comment"], "source": SOURCE, "generated": dt.date.today().isoformat(),
               "calendarUsage": snapshot["calendarUsage"], "days": days}
    target = SHARED / "data/readings-ugcc.json"
    target.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    if args.sync:
        for folder in module.TARGETS:
            shutil.copyfile(target, folder / target.name)
    print(f"Imported {len(days)} appointed reading days from official UGCC 2026 calendar")


if __name__ == "__main__":
    main()

#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pdfplumber", "requests"]
# ///
"""Import the supplied bilingual Saint James 2026–2027 calendar without guessing dates.

--pdf extracts the liturgical rows into a reproducible, hash-pinned source snapshot.
Personal contact and anniversary material is excluded. Without --pdf, use the snapshot.
The separate stjames calendar retains Great Advent and its own Mass appointments.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import re
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
DATA = TOOLS.parent / "data"
SNAPSHOT = TOOLS / "sources/stjames-calendar-2026-2027.json"
SOURCE = "https://s3-eu-west-1.amazonaws.com/catholic.co.il/12147_HebrewandEnglish20262027SA2.pdf"
PERSONAL_LINE = re.compile(r"^(?:Rev\.?(?=\s+[A-Za-z])|Rt\.\s*(?:Rev\.|Fr\.)|Fr\.|HE |H\.E\.|Bp\.|HB\s+Card\b|Pope\b)")


def module(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, TOOLS / filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def hebrew_line(visual: str) -> str:
    # PDF glyphs are placed in visual order. Reverse Hebrew lines, mirror brackets,
    # then restore digit runs. This transcribes existing text, never translates it.
    logical = visual[::-1]
    return re.sub(r"\d+", lambda m: m[0][::-1], logical).strip()


def extract(pdf: Path) -> dict:
    import pdfplumber
    days = {}
    expected = dt.date(2026, 10, 4)
    with pdfplumber.open(pdf) as document:
        for page_number, page in enumerate(document.pages, 1):
            if not 3 <= page_number <= 58:
                continue
            tables = page.find_tables()
            english = sorted((t for t in tables if t.bbox[0] < page.width / 2), key=lambda t: t.bbox[1])
            hebrew = sorted((t for t in tables if t.bbox[0] > page.width / 2), key=lambda t: t.bbox[1])
            en_rows = [row for table in english for row in table.rows if row.cells[0]
                       and re.search(r"(?m)^\d+(?:st|nd|rd|th)\b", page.crop(row.cells[0]).extract_text() or "")]
            he_rows = [row for table in hebrew for row in table.rows if row.cells[-1]
                       and re.match(r"\d+\b", page.crop(row.cells[-1]).extract_text() or "")]
            if len(en_rows) != len(he_rows):
                raise ValueError(f"Bilingual row count mismatch on page {page_number}")
            for en_row, he_row in zip(en_rows, he_rows):
                date_text = page.crop(en_row.cells[0]).extract_text()
                day_number = int(re.search(r"(?m)^(\d+)(?:st|nd|rd|th)\b", date_text)[1])
                weekday = re.search(r"(?m)^(Sun|Mon|Tue|Wed|Thu|Fri|Sat)$", date_text)[1]
                if day_number != expected.day or weekday != expected.strftime("%a"):
                    raise ValueError(f"Date/weekday mismatch: {expected} on page {page_number}: {date_text!r}")
                if int(re.match(r"\d+", page.crop(he_row.cells[-1]).extract_text())[0]) != expected.day:
                    raise ValueError(f"Hebrew date mismatch: {expected} on page {page_number}")
                en = page.crop(en_row.cells[1]).extract_text()
                he = "\n".join(hebrew_line(line) for line in
                               page.crop(he_row.cells[0]).extract_text().splitlines()
                               if not re.search(r"[A-Za-z]", line))
                # Anniversary names are irrelevant to liturgical appointments and are
                # excluded from the snapshot rather than copied into the app.
                en = "\n".join(line for line in en.splitlines()
                               if not PERSONAL_LINE.match(line))
                he = "\n".join(line for line in he.splitlines()
                               if not PERSONAL_LINE.search(line))
                days[expected.isoformat()] = {"pdfPage": page_number, "english": en,
                                              "hebrew": he, "colors": date_text.splitlines()[2:]}
                expected += dt.timedelta(days=1)
    if expected != dt.date(2027, 10, 25) or len(days) != 386:
        raise ValueError(f"Unexpected coverage: {expected}, {len(days)} rows")
    return {"source": SOURCE, "sha256": hashlib.sha256(pdf.read_bytes()).hexdigest(),
            "coverageStart": "2026-10-04", "coverageEnd": "2027-10-24", "days": days}


def title_before_readings(text: str) -> str:
    lines = []
    for line in text.splitlines():
        if re.search(r"\d+\s*:", line) or ";" in line:
            break
        lines.append(line)
    return " ".join(lines).strip()


RANK_PREFIX = re.compile(r"^(Optional Memorial|Memorial|Feast|Solemnity) of (?:the )?", re.I)
WEEKDAY = re.compile(r"^(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Satuday)\b")


def titles(row: dict) -> list[tuple[str, str, str]]:
    english = row["english"]
    # One printed line overflows the previous row. Preserve it in the snapshot,
    # but do not turn a continuation of the previous saint into this day's title.
    if english.startswith("Companions, Martyrs\n"):
        english = english.removeprefix("Companions, Martyrs\n")
    main = title_before_readings(english)
    he_main = title_before_readings(row["hebrew"])
    result = []
    if not WEEKDAY.match(main) and not re.match(r"^The (?:Fifth|Sixth|Seventh) Day", main):
        match = RANK_PREFIX.match(main)
        rank = match[1].title() if match else ("Sunday" if "Sunday" in main else "Holy Week")
        result.append((RANK_PREFIX.sub("", main), he_main, rank))
    pattern = r"(?m)^Optional Memorial[^\n]*(?:\n(?!.*\d+:|Optional Memorial|In |Additional reading)[^\n]+)*"
    en_optional = [" ".join(m[0].splitlines()) for m in re.finditer(pattern, english)]
    he_lines = row["hebrew"].splitlines()
    first_reference = next((i for i, line in enumerate(he_lines) if re.search(r"\d+\s*:", line) or ";" in line), len(he_lines))
    he_tail = "\n".join(he_lines[first_reference + 1:])
    he_pattern = r"(?m)^ז[יכ]*[כב]רון[^\n]*(?:\n(?!.*\d+:|ז[יכ]*[כב]רון|ב(?:חיפה|ירושלים|באר שבע))[^\n]+)*"
    he_optional = [" ".join(m[0].splitlines()) for m in re.finditer(he_pattern, he_tail)]
    if len(en_optional) != len(he_optional):
        raise ValueError(f"Bilingual optional observance count mismatch: {len(en_optional)} English, {len(he_optional)} Hebrew")
    for index, title in enumerate(en_optional):
        if index >= len(he_optional):
            raise ValueError(f"Missing source Hebrew optional observance: {title}")
        result.append((RANK_PREFIX.sub("", title), he_optional[index], "Optional Memorial"))
    return result


def title_key(text: str) -> str:
    text = RANK_PREFIX.sub("", text)
    text = re.sub(r"\bSt\.(?=\s)", "Saint", text)
    text = re.sub(r"\bSts\.(?=\s)", "Saints", text)
    return re.sub(r"\s+", " ", text).casefold().strip()


def catalog() -> dict[str, dict]:
    result = {}
    for path in sorted(DATA.glob("feasts*.json")):
        for row in json.loads(path.read_text())["days"].values():
            result.setdefault(title_key(row["title"]), {}).update(row.get("titleByLanguage", {}))
    for path in TOOLS.glob("feast-titles-*.json"):
        for title, values in json.loads(path.read_text()).get("titles", {}).items():
            result.setdefault(title_key(title), {}).update(values)
    return result


def appointments(text: str, readings_module) -> list[dict]:
    # Local community alternatives are preserved in the source snapshot. This table
    # presents Vicariate-wide appointments, including every printed Mass and choice.
    text = re.split(r"(?m)^In (?:Beer Sheva|Jerusalem|Haifa|Jaffa|Tiberias)", text)[0]
    text = "\n".join(line for line in text.splitlines() if not PERSONAL_LINE.match(line))
    names = {key: value for key, value in readings_module.EVANGELIZO_BOOKS.items() if "_" not in key}
    names.update({short.rstrip("."): (short, full) for short, full in readings_module.GENERIC_BOOKS.values()})
    names.update({"Gen": ("Gen.", "Genesis"), "Mk": ("Mk.", "Mark"),
                  "Prv": ("Prov.", "Proverbs"), "Ti": ("Titus", "Titus"),
                  "1 Thes": ("1 Thess.", "1 Thessalonians"), "2 Thes": ("2 Thess.", "2 Thessalonians"),
                  "1 Cor": ("1 Cor.", "1 Corinthians"), "2 Cor": ("2 Cor.", "2 Corinthians"),
                  "1 Tm": ("1 Tim.", "1 Timothy"), "2 Tm": ("2 Tim.", "2 Timothy"),
                  "1 Tim": ("1 Tim.", "1 Timothy"), "2 Tim": ("2 Tim.", "2 Timothy"),
                  "1 Jn": ("1 Jn.", "1 John"), "2 Jn": ("2 Jn.", "2 John"), "3 Jn": ("3 Jn.", "3 John"),
                  "1 Pt": ("1 Pet.", "1 Peter"), "2 Pt": ("2 Pet.", "2 Peter"),
                  "1 Pet": ("1 Pet.", "1 Peter"), "2 Pet": ("2 Pet.", "2 Peter"),
                  "1 Sm": ("1 Sam.", "1 Samuel"), "2 Sm": ("2 Sam.", "2 Samuel"),
                  "1 Kgs": ("1 Kgs.", "1 Kings"), "2 Kgs": ("2 Kgs.", "2 Kings"),
                  "Acts": ("Acts", "Acts"), "Rom": ("Rom.", "Romans"), "Bar": ("Bar.", "Baruch"),
                  "Wis": ("Wis.", "Wisdom"), "Sir": ("Sir.", "Sirach"),
                  "Rev": ("Rev.", "Revelation"),
                  # The supplied bilingual PDF defines these English abbreviations;
                  # Sg means Song of Songs here, not the French Evangelizo Wisdom code.
                  "Sg": ("Song", "Song of Songs"), "Zep": ("Zeph.", "Zephaniah"),
                  "Zec": ("Zech.", "Zechariah"), "Nm": ("Num.", "Numbers"),
                  "Jgs": ("Judg.", "Judges"), "Ru": ("Ruth", "Ruth"),
                  "Hbr": ("Heb.", "Hebrews")})
    # Numbered books may be printed compactly (1Cor) or wrapped (1 Cor).
    books = "|".join(re.escape(name).replace(r"\ ", r"\s*")
                     for name in sorted(names, key=len, reverse=True))
    number = r"\d+[a-z]?(?:\s*[-–—]+\s*(?:\d+\s*:\s*)?\d+[a-z]?)?"
    verses = rf"{number}(?:\s*[.,]\s*{number})*"
    reference = rf"(?:\d+\s*[:,]\s*{verses}|{verses})(?:;\s*\d+\s*:\s*{verses})*"
    pattern = re.compile(rf"(?<![\w])(?:(?P<book>{books})\s*:?[ \n]*(?P<ref>{reference})|(?P<inherit>\bor\s+)(?P<alternate>\d+\s*:\s*{verses}))\b")
    result, consumed = [], []
    previous_end, previous_book = 0, None
    mass_group = None
    single_chapter = {"Philemon", "2 John", "3 John", "Jude", "Obadiah"}
    for match in pattern.finditer(text):
        if match["book"] is None:
            if previous_book is None:
                raise ValueError(f"Bookless alternative without a preceding citation: {match[0]}")
            short, full = previous_book
            raw_ref = match["alternate"]
        else:
            key = re.sub(r"^(\d)\s*", r"\1 ", match["book"])
            short, full = names[key]
            raw_ref = match["ref"]
            previous_book = (short, full)
        ref = re.sub(r"[-–—]+", "–", re.sub(r"\s+", "", raw_ref))
        # Exact punctuation normalizations only; the original span is kept below.
        # Hebrew on the same PDF row confirms Gal 1:11 and Phil 3:17–4:1.
        if full == "Galatians" and ref == "1,11–20": ref = "1:11–20"
        if full == "Philippians" and ref == "3:17–4.1": ref = "3:17–4:1"
        if full in single_chapter and ":" not in ref:
            ref = "1:" + ref  # These books have one chapter; printed numbers are verses.
        elif ":" not in ref:
            # The PDF occasionally prints a comma/dot between chapter and verse
            # (2 Cor 5,6 and Dn 7.9); only its first separator names the chapter.
            ref = re.sub(r"^(\d+)[.,]", r"\1:", ref, count=1)
        ref = ref.replace(".", ",").replace(";", "; ")
        gap = text[previous_end:match.start()]
        heading = " ".join(gap.strip("; \n").splitlines()).strip()
        if (re.search(r"\b(?:Mass|Vigil)\b", heading) or (mass_group and re.search(r"[A-Za-z]", heading))) and not re.fullmatch(r"or", heading):
            mass_group = heading
        group = mass_group
        additional = re.search(r"(?s)(Additional reading[^\n]*(?:\n[^\n]*)*)$", gap)
        if additional:
            group = " ".join(additional[1].strip().rstrip(":").split())
        elif match["inherit"] or re.search(r"\bor\s*$", gap):
            group = "or"
        item = readings_module.citation(short, full, ref)
        item["sourceText"] = match[0]
        if group: item["sourceGroup"] = group
        result.append(item)
        consumed.append(match.span())
        previous_end = match.end()
    # A partially parsed row must never silently lose a Bible reference. This also
    # catches unknown book abbreviations and bookless alternatives we failed to parse.
    unconsumed = list(text)
    for begin, end in consumed:
        unconsumed[begin:end] = " " * (end - begin)
    leftovers = "".join(unconsumed)
    # Advent headings contain source ordinals (1st–4th); all other digits must
    # belong to a consumed reference. This catches malformed tails such as --11.
    if (re.search(r"\d", re.sub(r"\b\d+(?:st|nd|rd|th)\b", "", leftovers))
            or re.search(r"(?<![A-Za-z])[-–—]+(?![A-Za-z])", leftovers)):
        raise ValueError(f"Unconsumed sourced citation: {leftovers.strip()}")
    if not result or not any(item["type"] == "gospel" for item in result):
        raise ValueError(f"Incomplete sourced appointments: {text}")
    return result


def generate(source: dict) -> tuple[dict, dict]:
    localized = catalog()
    labels_path = TOOLS / "stjames-titles-localized.json"
    labels = json.loads(labels_path.read_text()) if labels_path.exists() else {"titles": {}, "aliases": {}}
    readings_module = module("stjames_readings", "fetch-readings.py")
    feasts, readings, missing = {}, {}, {}
    for date, row in source["days"].items():
        try:
            readings[date] = {"readings": appointments(row["english"], readings_module)}
        except ValueError as error:
            raise ValueError(f"{date}: {error}") from error
        components = []
        for english, hebrew, rank in titles(row):
            english_key = title_key(english)
            lookup = title_key(labels["aliases"].get(english, english))
            translations = dict(localized.get(lookup, {})) | labels["titles"].get(english, {})
            translations["he"] = labels["titles"].get(english, {}).get("he", hebrew)
            absent = {"ar", "ru", "tl", "fr", "it", "uk"} - translations.keys()
            if absent:
                missing[english] = sorted(absent)
            component = {"title": english, "identity": english_key, "rank": rank,
                         "titleByLanguage": translations}
            if translations["he"] != hebrew:
                component["sourceTitleByLanguage"] = {"he": hebrew}
            components.append(component)
        if components:
            feasts[date] = {"title": "; ".join(c["title"] for c in components), "rank": components[0]["rank"],
                            "titleByLanguage": {lang: "; ".join(c["titleByLanguage"].get(lang, c["title"]) for c in components)
                                                for lang in ("he", "ar", "ru", "tl", "fr", "it", "uk")},
                            "observances": components, "sourceUrl": source["source"], "sourcePage": row["pdfPage"]}
    if missing:
        Path("/tmp/prosary-stjames-missing-titles.json").write_text(json.dumps(missing, ensure_ascii=False, indent=2))
        raise ValueError(f"{len(missing)} titles need reviewed display labels; see /tmp/prosary-stjames-missing-titles.json")
    hebrew = json.loads(readings_module.HEBREW_BOOKS_FILE.read_text())["books"]
    other = json.loads(readings_module.LOCALIZED_BOOKS_FILE.read_text())["books"]
    if readings_module.localize_hebrew_readings(readings, hebrew) or readings_module.localize_reading_names(readings, other):
        raise ValueError("Missing sourced Bible book names")
    # Some source Psalms appoint a whole chapter without verse limits. The general
    # feed localizers expect a colon; these source citations still use the same
    # credited book-name catalogs and keep the printed chapter numbering.
    for row in readings.values():
        for item in row["readings"]:
            whole = re.fullmatch(r"(.+?) (\d+)", item["full"])
            if not whole:
                continue
            book, chapter = whole.groups()
            if book not in hebrew or book not in other:
                raise ValueError(f"Missing sourced whole-chapter book name: {book}")
            he_chapter = readings_module.hebrew_numeral(int(chapter))
            item.setdefault("shortByLanguage", {})["he"] = f"{hebrew[book]['short']} {he_chapter}"
            item.setdefault("fullByLanguage", {})["he"] = f"{hebrew[book]['full']} {he_chapter}"
            for language, names in other[book].items():
                numeric = f"\u2066{chapter}\u2069" if language == "ar" else chapter
                item["shortByLanguage"][language] = f"{names['short']} {chapter}"
                item["fullByLanguage"][language] = f"{names['full']} {numeric}"
    required_languages = {"he", "ar", "ru", "tl", "fr", "it", "uk"}
    for date, row in readings.items():
        for item in row["readings"]:
            for key in ("shortByLanguage", "fullByLanguage"):
                maps = item.get(key, {})
                absent = {language for language in required_languages if not maps.get(language)}
                if absent:
                    raise ValueError(f"{date}: {item['sourceText']!r} lacks {key} for {sorted(absent)}")
    from saint_descriptions import add_sourced_descriptions
    add_sourced_descriptions(feasts, "stjames")
    return feasts, readings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pdf", type=Path)
    parser.add_argument("--extract-only", action="store_true")
    parser.add_argument("--sync", action="store_true")
    args = parser.parse_args()
    if args.pdf:
        source = extract(args.pdf)
        SNAPSHOT.write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n")
    else:
        source = json.loads(SNAPSHOT.read_text())
    if args.extract_only:
        print(f"Extracted {len(source['days'])} bilingual liturgical rows")
        return
    feasts, readings = generate(source)
    for name, days in (("feasts-stjames", feasts), ("readings-stjames", readings)):
        payload = {"$comment": "Saint James Vicariate for Hebrew Speaking Catholics in Israel, supplied bilingual 2026–2027 liturgical calendar. "
                   "English and Hebrew observances, Great Advent, dates, source year labels and Mass appointments retain this calendar's choices. "
                   "Explicit Hebrew display terminology is normalized in stjames-titles-localized.json; differing printed titles remain in sourceTitleByLanguage. "
                   "Other languages use credited Prosary editorial display metadata, not official liturgical translations. "
                   "Source snapshot and reference punctuation review: Shared/tools/sources/stjames-calendar-2026-2027.json; "
                   "regenerate with Shared/tools/import-stjames-calendar.py. Missing dates never borrow General Roman appointments.",
                   "generated": dt.date.today().isoformat(), "years": [2026, 2027], "sourceUrl": source["source"],
                   "sourceSha256": source["sha256"], "coverageStart": source["coverageStart"],
                   "coverageEnd": source["coverageEnd"], "days": days}
        (DATA / f"{name}.json").write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n")
    if args.sync:
        module("stjames_feasts", "fetch-feasts.py").sync_datasets()
    print(f"Generated {len(feasts)} observance dates and {len(readings)} reading dates")


if __name__ == "__main__":
    main()

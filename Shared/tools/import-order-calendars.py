#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf", "requests"]
# ///
"""Import dated Conventual Franciscan and Discalced Augustinian annual ordos.

Use --franciscan-pdf and --augustinian-pdf to refresh the hash-pinned snapshots.
Without PDFs, regenerate from the reviewed snapshots. This does not derive dates
from fixed proper calendars, copy another calendar's readings, or infer future years.
Only liturgical headings and appointment facts are retained; personal anniversaries
and necrologies are excluded.
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
SOURCES = TOOLS / "sources"
FRANCISCAN_URL = "https://drive.google.com/file/d/1AwNdtFdwrtdXFSIyW2VuAvIhVGXzs0C4/view"
FRANCISCAN_PAGE = "https://www.francescaninorditalia.net/aggiornamenti/news/1075-calendario-liturgico-pisap-ofm-conv-2025-2026.html"
AUGUSTINIAN_URL = "https://oadnet.org/wp-content/uploads/2025/11/Calendario-2026-ENG-site.pdf"
MONTHS = "JANUARY FEBRUARY MARCH APRIL MAY JUNE JULY AUGUST SEPTEMBER OCTOBER NOVEMBER DECEMBER".split()
WEEKDAYS_IT = ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"]
WEEKDAYS_EN = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
WEEKDAY_LABELS = {
    "en": WEEKDAYS_EN,
    "ar": ["الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت", "الأحد"],
    "ru": ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"],
    "tl": ["Lunes", "Martes", "Miyerkules", "Huwebes", "Biyernes", "Sabado", "Linggo"],
    "fr": ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"],
    "it": WEEKDAYS_IT,
    "uk": ["Понеділок", "Вівторок", "Середа", "Четвер", "П’ятниця", "Субота", "Неділя"],
}
ORDINALS = ["", "First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh"]
SEASON_LABELS = {
    "advent": ["Advent", "المجيء", "Адвент", "Adbiyento", "Avent", "Avvento", "Адвент"],
    "lent": ["Lent", "الزمن الأربعيني", "Великий пост", "Kuwaresma", "Carême", "Quaresima", "Великий піст"],
    "easter": ["Easter", "الفصح", "Пасха", "Pasko ng Pagkabuhay", "Pâques", "Pasqua", "Великдень"],
    "ordinary": ["Ordinary Time", "الزمن العادي", "Рядовое время", "Karaniwang Panahon", "Temps ordinaire", "Tempo ordinario", "Звичайний час"],
    "christmas": ["Christmas Season", "زمن الميلاد", "Рождественское время", "Panahon ng Pasko", "Temps de Noël", "Tempo di Natale", "Різдвяний час"],
}


def compact(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def document_text(pdf: Path, first: int, last: int | None = None) -> tuple[str, list[tuple[int, int]]]:
    from pypdf import PdfReader
    pages = PdfReader(pdf).pages
    text, offsets = "", []
    for index in range(first - 1, last or len(pages)):
        offsets.append((len(text), index + 1))
        # Printed hyphenation is repaired only between letters. Numeric ranges survive.
        page = re.sub(r"([^\W\d_])\s*-\s*\n\s*([^\W\d_])", r"\1\2", pages[index].extract_text())
        text += page + "\n"
    return text, offsets


def page_at(offsets: list[tuple[int, int]], offset: int) -> int:
    return next(page for start, page in reversed(offsets) if start <= offset)


def snapshot(pdf: Path, source: str, start: str, end: str, days: dict) -> dict:
    expected = { (dt.date.fromisoformat(start) + dt.timedelta(days=i)).isoformat()
                 for i in range((dt.date.fromisoformat(end) - dt.date.fromisoformat(start)).days + 1) }
    if set(days) != expected:
        raise ValueError(f"Incomplete date coverage: {sorted(expected - days.keys())}")
    return {"sourceUrl": source, "sha256": hashlib.sha256(pdf.read_bytes()).hexdigest(),
            "coverageStart": start, "coverageEnd": end, "days": days}


def extract_franciscan(pdf: Path) -> dict:
    text, offsets = document_text(pdf, 16, 149)
    pattern = r"(?m)^\s*(\d{1,2})\s+@?\s*(" + "|".join(WEEKDAYS_IT) + r")\s*[:\s]"
    headings = list(re.finditer(pattern, text, re.I))
    days, expected = {}, dt.date(2025, 11, 29)
    for index, match in enumerate(headings):
        body = text[match.end():headings[index + 1].start() if index + 1 < len(headings) else len(text)]
        date = expected
        # Holy Thursday is printed twice: the morning office and the evening Mass.
        # The evening proper is the calendar entry; retain its own appointments.
        if int(match[1]) == 2 and expected == dt.date(2026, 4, 3):
            date = dt.date(2026, 4, 2)
        else:
            expected += dt.timedelta(days=1)
        if int(match[1]) != date.day or match[2].casefold() != WEEKDAYS_IT[date.weekday()].casefold():
            raise ValueError(f"Conventual date/weekday mismatch: {date}, {match[0]!r}")
        end = re.search(r"\((?:bianco|rosso|verde|viola|rosaceo)(?:[^)]*)\)", body, re.I)
        if not end and date == dt.date(2025, 11, 29):
            title = compact(body.splitlines()[0]).rstrip(" .")
        elif not end:
            raise ValueError(f"Missing Conventual heading boundary: {date}: {body[:200]}")
        else:
            title = compact(body[:end.start()]).rstrip(" .")
        if re.match(r"^(?:\d|di\b|dell[ae’']|delle\b|SANTO\b)", title, re.I):
            title = match[2].title() + " " + title
        # Only explicit passages, never a bare 'Lezionario feriale' or 'Messale serafico'.
        appointments = []
        for citation in re.finditer(r"(?:Lezionario[^\n(]*|Letture[^\n(]*|letture[^\n(]*)\(([^)]+)\)", body):
            if re.search(r"\d+\s*,\s*\d+", citation[1]):
                appointments.append(compact(citation[1]))
        for citation in re.finditer(r"(?m)^\s*Messa (?:della notte|dell’aurora|del giorno):\s*([^\n]+)", body):
            appointments.append(compact(citation[1]))
        days[date.isoformat()] = {"sourcePage": page_at(offsets, match.start(1)),
                                 "title": title, "appointments": appointments,
                                 "mainAppointment": appointments[-1] if appointments else ""}
    return snapshot(pdf, FRANCISCAN_URL, "2025-11-29", "2026-11-28", days)


def extract_augustinian(pdf: Path) -> dict:
    text, offsets = document_text(pdf, 17)
    pattern = r"(?m)^\s*(" + "|".join(WEEKDAYS_EN) + r")\s+"
    headings = list(re.finditer(pattern, text))
    days = {}
    for index, match in enumerate(headings):
        body = text[match.end():headings[index + 1].start() if index + 1 < len(headings) else len(text)]
        source_date = re.search(r"\b(\d{1,2})\s*\n\s*(" + "|".join(MONTHS) + r")\b", body)
        if not source_date:
            continue  # Section title such as 'Sunday and Special Days Lectionary'.
        date = dt.date(2026, MONTHS.index(source_date[2]) + 1, int(source_date[1]))
        if match[1] != WEEKDAYS_EN[date.weekday()]:
            raise ValueError(f"OAD date/weekday mismatch: {date}, {match[1]}")
        boundary = re.search(r"Mass\b|Liturgy of the Word|Service of Light|Lit\. Hours|Commemoration of Jesus", body)
        if not boundary:
            raise ValueError(f"Missing OAD title boundary: {date}")
        title = compact(body[:boundary.start()])
        # 'Morning Mass'/'Evening Mass' have a qualifier before the boundary.
        title = re.sub(r"\s+(?:Morning|Evening)$", "", title)
        if title.startswith(("of ", "after ", "before ", "in ")):
            title = match[1] + " " + title
        if title == "Weekday":
            title = match[1]
        appointment_end = re.search(r"Lit\. Hours|Veneration of the Cross", body[boundary.start():])
        appointments = compact(body[boundary.start():boundary.start() + appointment_end.start()
                                    if appointment_end else source_date.start()])
        if date.isoformat() in days and date != dt.date(2026, 4, 2):
            raise ValueError(f"Unexpected duplicate OAD date: {date}")
        days[date.isoformat()] = {"sourcePage": page_at(offsets, match.start(1)),
                                 "title": title, "appointments": [appointments]}
    return snapshot(pdf, AUGUSTINIAN_URL, "2026-01-01", "2026-12-31", days)


def module(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, TOOLS / filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def references(text: str, language: str, readings_module) -> list[dict]:
    names = dict(readings_module.EVANGELIZO_BOOKS)
    canonical = {full: (short, full) for short, full in names.values()}
    aliases = {"Nm": "Numbers", "Isa": "Isaiah", "Jer": "Jeremiah", "Ezek": "Ezekiel",
               "Wis": "Wisdom", "Sir": "Sirach", "Acts": "Acts", "Rom": "Romans", "Gal": "Galatians",
               "Eph": "Ephesians", "Phil": "Philippians", "Rev": "Revelation", "Mk": "Mark", "Lk": "Luke",
               "1Cor": "1 Corinthians", "2Cor": "2 Corinthians", "1Thes": "1 Thessalonians",
               "2Thes": "2 Thessalonians", "1Tim": "1 Timothy", "2Tim": "2 Timothy",
               "1Pt": "1 Peter", "2Pt": "2 Peter", "1Jn": "1 John", "2Jn": "2 John", "3Jn": "3 John",
               "Gv": "John", "At": "Acts", "Es": "Exodus", "Sal": "Psalm", "Eb": "Hebrews",
               "Ap": "Revelation", "1Ts": "1 Thessalonians", "2Ts": "2 Thessalonians",
               "1Tm": "1 Timothy", "2Tm": "2 Timothy", "Gc": "James", "Ger": "Jeremiah",
               "Bar": "Baruch", "Sl": "Psalm", "Ef": "Ephesians", "Fil": "Philippians",
               "Sap": "Wisdom", "Sof": "Zephaniah", "Gl": "Joel", "1Gv": "1 John",
               "1Re": "1 Kings", "2Re": "2 Kings", "1Sm": "1 Samuel", "2Sam": "2 Samuel", "1Cr": "1 Chronicles",
               "Eccl": "Ecclesiastes", "Est": "Esther", "Hos": "Hosea", "Jgs": "Judges",
               "Lam": "Lamentations", "Phlm": "Philemon", "Prv": "Proverbs", "Zec": "Zechariah", "Zep": "Zephaniah",
               "1Chr": "1 Chronicles", "2Chr": "2 Chronicles", "1Kgs": "1 Kings", "2Kgs": "2 Kings", "1Sam": "1 Samuel",
               "Mal": "Malachi", "MaI": "Malachi", "MI": "Malachi"}
    names.update({alias: canonical[full] for alias, full in aliases.items()})
    if language == "en":
        # OAD's Sg is the English Song of Songs, not Evangelizo's French Sagesse.
        names["Sg"] = canonical["Song of Songs"]
        if "Day:" in text:
            text = text.rsplit("Day:", 1)[1]  # Separate Christmas/Pentecost day Mass.
        text = re.split(r"\b2nd scheme\b", text, maxsplit=1)[0]
        text = re.sub(r"\b1st scheme\b", "", text)
    book_pattern = "|".join(re.escape(book).replace(r"\ ", r"\s*") for book in sorted(names, key=len, reverse=True))
    # Source references retain their numbering, including whole-psalm citations.
    numeric = r"\d+[a-z]?(?:\s*[:,.−–-]+\s*\d+[a-z]?)*(?:;\s*\d+\s*[:,]\s*\d+[a-z]?(?:\s*[:,.−–-]+\s*\d+[a-z]?)*)*(?:\s+and\s+\d+)?"
    matches = list(re.finditer(rf"(?<![\w])(?P<book>{book_pattern})\s*(?P<ref>{numeric})", text))
    if matches and re.search(r"\d", text[:matches[0].start()]):
        raise ValueError(f"Unrecognized leading source reference: {text[:matches[0].start()]!r}")
    result = []
    for index, match in enumerate(matches):
        tail = text[match.end():matches[index + 1].start() if index + 1 < len(matches) else len(text)]
        # Source-only variants may abbreviate the repeated book after »/or. All
        # other numeric remnants indicate a truncated or unrecognized reference.
        alternatives = re.split(r"»|\bo\b|\boppure\b", tail)
        for alternative_index, remainder in enumerate(alternatives):
            if alternative_index:
                # A bare numeric alternative inherits the explicit preceding book.
                remainder = re.sub(rf"^\s*(?:{numeric})", "", remainder, count=1)
            if re.search(r"\d", remainder):
                raise ValueError(f"Unconsumed source reference after {match[0]!r}: {tail!r}")
        gap = text[matches[index - 1].end():match.start()] if index else text[:match.start()]
        if re.search(r"»|\bo\b", gap) and ";" not in re.split(r"»|\bo\b", gap)[-1]:
            continue  # Select the first printed option; snapshot retains all alternatives.
        short, full = names[match["book"]]
        joined_psalms = re.fullmatch(r"(\d+)\s+and\s+(\d+)", match["ref"])
        if joined_psalms and (full != "Psalm" or int(joined_psalms[2]) != int(joined_psalms[1]) + 1):
            raise ValueError(f"Unsupported nonadjacent whole-psalm appointment: {match[0]}")
        ref = re.sub(r"\s+", "", match["ref"]).replace("−", "–")
        ref = ref.replace("and", "–")
        ref = re.sub(r",+", ",", ref)  # Printed duplicated commas are punctuation, not missing text.
        if language == "it":
            ref = re.sub(r"(^|[;–-])(\d+),", r"\1\2:", ref)
        else:
            ref = re.sub(r"([–-]\d+),", r"\1:", ref).replace(",", ".")
        if full != "Psalm":
            ref = re.sub(r"^(\d+)\.", r"\1:", ref)
        if full in {"Philemon", "Jude", "2 John", "3 John", "Obadiah"} and ":" not in ref:
            ref = "1:" + ref
        ref = ref.replace(";", "; ")
        kind = "psalm" if re.search(r"Ps\s*\($", gap) else None
        result.append(readings_module.citation(short, full, ref, kind) | {"sourceText": compact(match[0])})
    return result


def title_key(title: str) -> str:
    title = re.sub(r"\s*\([smf]\)\s*$", "", title)
    title = re.sub(r"\bSts?\.(?=\s)", lambda m: "Saints" if m[0] == "Sts." else "Saint", title)
    return compact(title).casefold().rstrip(" .")


def title_catalog() -> dict:
    result = {}
    for path in sorted(DATA.glob("feasts*.json")):
        if any(order in path.name for order in ("franciscan-conventual", "augustinian-discalced")):
            continue
        for row in json.loads(path.read_text())["days"].values():
            translations = row.get("titleByLanguage", {}) | {"en": row["title"]}
            for title in translations.values():
                result.setdefault(title_key(title), {}).update(translations)
    for path in TOOLS.glob("*feast-titles*.json"):
        for title, translations in json.loads(path.read_text()).get("titles", {}).items():
            result.setdefault(title_key(title), {}).update({lang: value for lang, value in translations.items()
                                                          if lang in {"he", "ar", "ru", "tl", "fr", "it", "uk"}} | {"en": title})
    # Prefer the existing General Roman display captions for the same exact identity.
    for row in json.loads((DATA / "feasts-roman.json").read_text())["days"].values():
        result[title_key(row["title"])] = row.get("titleByLanguage", {}) | {"en": row["title"]}
    return result


def rank(title: str, date: str, language: str) -> str:
    if any(word in title for word in ("Holy Thursday", "Lord’s Supper", "Good Friday", "Holy Saturday", "SANTO")):
        return "Holy Week"
    if language == "en":
        return {"s": "Solemnity", "f": "Feast", "m": "Memorial"}.get(
            (re.search(r"\(([sfm])\)$", title) or [None, ""])[1],
            "Sunday" if dt.date.fromisoformat(date).weekday() == 6 else "Feria")
    if "Solennità" in title:
        return "Solemnity"
    if "Festa" in title:
        return "Feast"
    if "Memoria" in title:
        return "Memorial"
    return "Sunday" if dt.date.fromisoformat(date).weekday() == 6 else "Feria"


def temporal_labels(original: str, date: str, catalog: dict) -> dict:
    """Translate interface date/season metadata; reuse published Sunday identities."""
    main = original.split(" » ")[0]
    main = main.replace("East er", "Easter").replace("Easte r", "Easter").replace("Adven t", "Advent").replace("Wee k", "Week")
    weekday = dt.date.fromisoformat(date).weekday()
    season = next((name for name, pattern in [("advent", r"Avvento|Advent"), ("lent", r"Quaresima|Lent"),
                                              ("easter", r"Pasqua|Easter"), ("ordinary", r"TEMPO ORDINARIO|O\.T\."),
                                              ("christmas", r"Natale|Christmas")]
                   if re.search(pattern, main, re.I)), None)
    number_match = re.search(r"\b(\d+)(?:ª|a|°|st|nd|rd|th)?\b", main)
    number = int(number_match[1]) if number_match else (4 if main.startswith("IV of Advent") else None)
    if weekday == 6 and season and number:
        if season == "ordinary":
            suffix = "th" if 10 <= number % 100 <= 20 else {1: "st", 2: "nd", 3: "rd"}.get(number % 10, "th")
            target = f"{number}{suffix} Sunday of Ordinary Time"
        elif season == "christmas":
            target = "2nd Sunday after Christmas"
        else:
            target = f"{ORDINALS[number]} Sunday of {dict(advent='Advent', lent='Lent', easter='Easter')[season]}"
            if season == "easter" and number == 2:
                target = "Second Sunday of Easter or Divine Mercy Sunday"
        if title_key(target) in catalog:
            return dict(catalog[title_key(target)])
        candidates = [value for key, value in catalog.items() if key.startswith(title_key(target))
                      and not re.search(r"year [abc]|;", key)]
        if candidates:
            return dict(min(candidates, key=lambda item: len(item["en"])))
    if "Ottava di Pasqua" in main or "Octave of Easter" in main:
        target = f"{WEEKDAYS_EN[weekday]} of the Octave of Easter"
        if title_key(target) in catalog:
            return dict(catalog[title_key(target)])
    if main == "Feria":
        return {lang: labels[weekday] for lang, labels in WEEKDAY_LABELS.items()}
    if main.startswith(tuple(WEEKDAYS_EN)) or re.match(r"^(?:Lunedì|Martedì|Mercoledì) \d", main):
        result = {lang: labels[weekday] for lang, labels in WEEKDAY_LABELS.items()}
        if season:
            season_labels = dict(zip(WEEKDAY_LABELS, SEASON_LABELS[season]))
            week_terms = dict(zip(WEEKDAY_LABELS, ["Week", "الأسبوع", "неделя", "Linggo", "semaine", "settimana", "тиждень"]))
            for lang in result:
                result[lang] += f" · {season_labels[lang]}" + (f" · {week_terms[lang]} {number}" if number and "Week" in main else "")
        return result
    if main.startswith("I Vespri della"):
        return dict(zip(WEEKDAY_LABELS, ["First Vespers of the First Sunday of Advent", "صلاة الغروب الأولى للأحد الأول من المجيء",
                    "Первая вечерня первого воскресенья Адвента", "Unang Panalangin sa Takipsilim ng Unang Linggo ng Adbiyento",
                    "Premières vêpres du premier dimanche de l’Avent", main, "Перша вечірня першої неділі Адвенту"]))
    if re.match(r"^[567](?:th)? Day in the Octave of Christmas", main):
        number = int(main[0])
        return dict(zip(WEEKDAY_LABELS, [f"Day {number} in the Octave of Christmas", f"اليوم {number} من ثمانية الميلاد",
                    f"День {number} в октаве Рождества", f"Ika-{number} Araw sa Oktaba ng Pasko", f"Jour {number} dans l’octave de Noël",
                    f"Giorno {number} nell’ottava di Natale", f"День {number} в октаві Різдва"]))
    return {}


def generate(source: dict, identifier: str, language: str) -> tuple[dict, dict]:
    from saint_descriptions import add_sourced_descriptions
    readings_module = module("order_readings", "fetch-readings.py")
    catalog = title_catalog()
    labels = json.loads((TOOLS / "order-calendar-titles.json").read_text())
    feasts, readings = {}, {}
    for date, row in source["days"].items():
        original = row["title"]
        alias = labels["aliases"][identifier].get(original, original)
        translations = dict(catalog.get(title_key(alias), {})) or temporal_labels(original, date, catalog)
        translations.update(labels["editorialTitles"][identifier].get(original, {}))
        title = translations.pop("en", original)
        if language == "it":
            translations[language] = original
        absent = {"ar", "ru", "tl", "fr", "it", "uk"} - translations.keys()
        if absent:
            raise ValueError(f"Missing {identifier} display labels {absent}: {original}")
        feasts[date] = {"title": title, "rank": rank(original, date, language),
                        "titleByLanguage": translations, "sourceUrl": source["sourceUrl"],
                        "sourcePage": row["sourcePage"], "sourceOnlyLanguages": [] if "he" in translations else ["he"],
                        "observances": [{"identity": title_key(alias), "title": title,
                                         "titleByLanguage": translations, "sourceTitleByLanguage": {language: original}}]}
        appointment_text = [row.get("mainAppointment", "")] if language == "it" else row["appointments"]
        # Three printed references require publisher clarification. Preserve them
        # in the source snapshot, but do not present an inferred correction.
        review_gaps = {"2026-05-31": "Unresolved source book abbreviation Dm",
                       "2026-10-02": "Printed Ez 23 on Guardian Angels requires publisher clarification",
                       "2026-11-09": "Printed 1Cor 3,9c11 has an unresolved missing separator"}
        if language == "it" and date in review_gaps:
            feasts[date]["readingSourceReview"] = review_gaps[date]
            continue
        if language == "en" and date == "2026-05-30":
            feasts[date]["readingSourceReview"] = "Printed Jgs 17.20–25 has an unresolved book/reference mismatch"
            continue
        appointed = [item for text in appointment_text for item in references(text, language, readings_module)]
        if appointed:
            if not any(item["type"] == "gospel" for item in appointed):
                raise ValueError(f"Partial {identifier} appointments on {date}: {row['appointments']}")
            readings[date] = {"readings": appointed, "sourceUrl": source["sourceUrl"], "sourcePage": row["sourcePage"]}
    hebrew = json.loads(readings_module.HEBREW_BOOKS_FILE.read_text())["books"]
    localized = json.loads(readings_module.LOCALIZED_BOOKS_FILE.read_text())["books"]
    if readings_module.localize_hebrew_readings(readings, hebrew) or readings_module.localize_reading_names(readings, localized):
        raise ValueError("Missing sourced Bible book metadata")
    for date, day in readings.items():
        for item in day["readings"]:
            for field in ("shortByLanguage", "fullByLanguage"):
                if {"he", "ar", "ru", "tl", "fr", "it", "uk"} - item.get(field, {}).keys():
                    raise ValueError(f"Incomplete citation captions {identifier}/{date}/{field}: {item['full']}")
    add_sourced_descriptions(feasts, identifier)
    return feasts, readings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--franciscan-pdf", type=Path)
    parser.add_argument("--augustinian-pdf", type=Path)
    parser.add_argument("--extract-only", action="store_true")
    parser.add_argument("--sync", action="store_true", help="copy canonical data into all three native asset directories")
    args = parser.parse_args()
    specs = [("franciscan-conventual-italy", "2025-2026", "it", args.franciscan_pdf, extract_franciscan,
              "Conventual Franciscan Ordo, Province of Saint Anthony of Padua, Italy; Advent 2025–Advent 2026. "
              "Dates and precedence follow this dated annual Ordo, including Francis on Sunday 4 October. "
              "Only printed explicit passages are included; a separate Seraphic Missal or ferial lectionary reference does not supply citations."),
             ("augustinian-discalced", "2026", "en", args.augustinian_pdf, extract_augustinian,
              "Order of Discalced Augustinians general Ordo for January–December 2026. "
              "General appointments are retained, including fixed January 6 Epiphany; national/local variants are not substituted. "
              "Where the source prints alternatives, the first printed appointment is selected; alternatives remain in the source snapshot.")]
    for identifier, edition, language, pdf, extract, comment in specs:
        path = SOURCES / f"{identifier}-{edition}.json"
        if pdf:
            source = extract(pdf)
            path.write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n")
        else:
            source = json.loads(path.read_text())
        if args.extract_only:
            print(f"{identifier}: extracted {len(source['days'])} dated rows")
            continue
        feasts, readings = generate(source, identifier, language)
        for kind, days in (("feasts", feasts), ("readings", readings)):
            payload = {"$comment": comment + " Source Psalm/chapter numbering is preserved. "
                       "Only exact identities reuse existing credited title catalogs; original printed headings remain in sourceTitleByLanguage. "
                       "New non-Hebrew captions are editorial interface metadata; sourceOnlyLanguages identifies Hebrew title gaps using the English heading. "
                       "No prayer or liturgical Hebrew is translated. Missing dates/readings never borrow another calendar. "
                       f"Regenerate from Shared/tools/sources/{path.name} with Shared/tools/import-order-calendars.py.",
                       "generated": dt.date.today().isoformat(), "years": sorted({int(day[:4]) for day in source["days"]}),
                       "sourceUrl": source["sourceUrl"], "sourceSha256": source["sha256"],
                       "sourcePageUrl": FRANCISCAN_PAGE if language == "it" else "https://oadnet.org/calendario_liturgico/",
                       "sourceSnapshot": f"Shared/tools/sources/{path.name}", "sourceLanguage": language,
                       "importer": "Shared/tools/import-order-calendars.py",
                       "coverageStart": source["coverageStart"], "coverageEnd": source["coverageEnd"], "days": days}
            (DATA / f"{kind}-{identifier}.json").write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n")
        print(f"{identifier}: {len(feasts)} calendar dates, {len(readings)} sourced reading dates")
    if args.sync and not args.extract_only:
        module("order_feasts", "fetch-feasts.py").sync_datasets()


if __name__ == "__main__":
    main()

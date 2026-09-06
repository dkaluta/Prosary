#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["requests"]
# ///
"""Bundle Eretz Israel's upcoming Sabbath Torah readings from Hebcal (CC BY 4.0).

Every civil date maps to the following Saturday, inclusive. A festival reading replaces
the weekly portion on holiday Sabbaths; we never skip ahead to a later regular portion.
Only names and citations are copied, never Scripture text. No runtime network is needed.
"""

from __future__ import annotations

import argparse
import datetime as dt
import importlib.util
import json
import shutil
from pathlib import Path

import requests

TOOLS = Path(__file__).resolve().parent
SHARED = TOOLS.parent
ROOT = SHARED.parent
API = "https://www.hebcal.com/hebcal"
LOCALES = {"en": "s", "he": "he-x-NoNikud", "fr": "fr", "ru": "ru"}


def reading_tools():
    spec = importlib.util.spec_from_file_location("prosary_readings", TOOLS / "fetch-readings.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def upcoming_saturday(day: dt.date) -> dt.date:
    return day + dt.timedelta(days=(5 - day.weekday()) % 7)


def build_days(start: dt.date, end: dt.date, payloads: dict) -> dict:
    readings = reading_tools()
    books_he = json.loads(readings.HEBREW_BOOKS_FILE.read_text())["books"]
    books_localized = json.loads(readings.LOCALIZED_BOOKS_FILE.read_text())["books"]
    by_language = {
        language: {item["date"]: item for item in payload["items"]
                   if dt.date.fromisoformat(item["date"]).weekday() == 5
                   and item.get("leyning", {}).get("torah")}
        for language, payload in payloads.items()
    }
    sabbaths = {}
    for date, item in by_language["en"].items():
        titles = {language: entries[date]["title"] for language, entries in by_language.items() if date in entries}
        # These interfaces use the source's proper-name transliteration. The row caption and
        # biblical book names are localized in all seven languages; names are not invented.
        for language in ("ar", "tl", "it"):
            titles[language] = item["title"].removeprefix("Parashat ")
        row = {
            "saturday": date,
            "title": item["title"],
            "titleByLanguage": titles,
            "isHoliday": item["category"] != "parashat",
            # Hebcal can append a festival Megillah in this field. This option is explicitly
            # the Torah portion, so keep the five books of Moses only.
            "readings": [citation for citation in readings.generic_citations(item["leyning"]["torah"])
                         if citation["full"].split(" ", 1)[0] in
                         {"Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy"}],
            "sourceUrl": item["link"],
        }
        if not row["readings"]:
            raise ValueError(f"No Torah citation for {date}: {item['title']}")
        missing_he = readings.localize_hebrew_readings({date: row}, books_he)
        missing_localized = readings.localize_reading_names({date: row}, books_localized)
        if missing_he or missing_localized:
            raise ValueError(f"Missing book names on {date}: {missing_he | missing_localized}; {row['readings']}")
        sabbaths[date] = row
    result = {}
    day = start
    while day <= end:
        saturday = upcoming_saturday(day).isoformat()
        if saturday not in sabbaths:
            raise ValueError(f"Missing Israel Sabbath {saturday}; refusing a partial calendar")
        result[day.isoformat()] = sabbaths[saturday]
        day += dt.timedelta(days=1)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--years", type=int, nargs="+", default=[2026, 2027])
    parser.add_argument("--cache", type=Path, default=Path("/tmp/prosary-torah-cache"))
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--sync", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert upcoming_saturday(dt.date(2026, 9, 5)) == dt.date(2026, 9, 5)
        assert upcoming_saturday(dt.date(2026, 9, 6)) == dt.date(2026, 9, 12)
        assert upcoming_saturday(dt.date(2027, 12, 31)) == dt.date(2028, 1, 1)
        path = SHARED / "data/torah-portions.json"
        if path.exists():
            data = json.loads(path.read_text())
            days = data["days"]
            start, end = map(dt.date.fromisoformat, (data["startDate"], data["endDate"]))
            assert len(days) == (end - start).days + 1
            for date, row in days.items():
                assert row["saturday"] == upcoming_saturday(dt.date.fromisoformat(date)).isoformat()
                assert row["readings"] and row["titleByLanguage"]["he"]
                for citation in row["readings"]:
                    assert set(citation["fullByLanguage"]) >= {"he", "ar", "ru", "tl", "fr", "it"}
            assert days["2026-09-06"]["isHoliday"]  # Rosh Hashanah, not Haazinu a week later.
            assert "Rosh Hashana" in days["2026-09-06"]["title"]
            assert days["2026-05-23"]["title"] == "Parashat Nasso"  # Israel; diaspora is Shavuot II.
        print("Torah portion checks passed")
        return
    start, end = dt.date(min(args.years), 1, 1), dt.date(max(args.years), 12, 31)
    args.cache.mkdir(parents=True, exist_ok=True)
    payloads, sources = {}, {}
    for language, locale in LOCALES.items():
        params = {"v": "1", "cfg": "json", "start": start.isoformat(),
                  "end": upcoming_saturday(end).isoformat(), "s": "on", "maj": "on",
                  "i": "on", "lg": locale}
        path = args.cache / f"{start.year}-{end.year}-{language}.json"
        url = requests.Request("GET", API, params=params).prepare().url
        if not args.offline:
            response = requests.get(url, timeout=60)
            response.raise_for_status()
            path.write_text(response.text, encoding="utf-8")
        payloads[language] = json.loads(path.read_text(encoding="utf-8"))
        sources[language] = url
    payload = {
        "$comment": "Eretz Israel only. Hebcal.com, CC BY 4.0. Names and citations adapted for Prosary; no Scripture text. Each civil day maps to the next Saturday inclusive, including festival replacements. Refresh with Shared/tools/fetch-torah-portions.py --sync.",
        "generated": dt.date.today().isoformat(), "startDate": start.isoformat(), "endDate": end.isoformat(),
        "region": "IL", "source": "https://www.hebcal.com", "license": "https://creativecommons.org/licenses/by/4.0/",
        "sources": sources, "days": build_days(start, end, payloads),
    }
    path = SHARED / "data/torah-portions.json"
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    if args.sync:
        for target in (ROOT / "iOS/Prosary/Data", ROOT / "Android/app/src/main/assets/data", ROOT / "Windows/Prosary/Data"):
            shutil.copyfile(path, target / path.name)
    print(f"Generated {len(payload['days'])} civil dates, Eretz Israel, {start}–{end}")


if __name__ == "__main__":
    main()

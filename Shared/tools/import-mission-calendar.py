#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Import the supplied provisional Mission calendar, preserving its explicit dates.

The original ICS remains byte-identical. Yearly RRULE values are retained as source
metadata, never expanded: their presence cannot establish next year's movable feasts.
Only reviewed dictation/spelling corrections affect display text. Source text is data.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import shutil

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parents[1]
SOURCE = TOOLS / "sources/mission-provisional-2026-he.ics"
CORRECTIONS = TOOLS / "sources/mission-provisional-corrections.json"
OUTPUT = ROOT / "Shared/data/feasts-mission-provisional.json"
REGISTRY = ROOT / "Shared/data/calendars.json"
CALENDAR_ID = "mission-provisional"
READINGS_FILE = "readings-syriac"


def unescape(value: str) -> str:
    return re.sub(r"\\([nN,;\\])", lambda m: "\n" if m[1] in "nN" else m[1], value)


def split_categories(value: str) -> list[str]:
    # Split RFC 5545 TEXT lists before unescaping literal commas.
    items, current, escaped = [], [], False
    for character in value:
        if character == "," and not escaped:
            items.append("".join(current))
            current = []
        else:
            current.append(character)
        escaped = not escaped if character == "\\" else False
    items.append("".join(current))
    return [unescape(item) for item in items if item]


def parse(raw: bytes) -> tuple[dict[str, str], list[dict[str, str]]]:
    text = raw.decode("utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"\n[ \t]", "", text)
    header, events, event, uids = {}, [], None, set()
    for line in text.splitlines():
        if line == "BEGIN:VEVENT":
            if event is not None:
                raise ValueError("Nested VEVENT")
            event = {}
        elif line == "END:VEVENT":
            if event is None or not all(event.get(k) for k in ("UID", "DTSTART", "SUMMARY")):
                raise ValueError("Incomplete VEVENT")
            if event["UID"] in uids:
                raise ValueError("Duplicate source UID")
            date = event["DTSTART"]
            if not re.fullmatch(r"\d{8}", date):
                raise ValueError("Only explicit all-day dates are supported")
            event["date"] = dt.datetime.strptime(date, "%Y%m%d").date().isoformat()
            uids.add(event["UID"])
            events.append(event)
            event = None
        elif ":" in line:
            name, value = line.split(":", 1)
            key = name.split(";", 1)[0]
            target = event if event is not None else header
            if key in {"UID", "DTSTART", "DTEND", "SUMMARY", "DESCRIPTION", "URL", "RRULE", "CATEGORIES",
                       "X-WR-CALNAME", "X-WR-CALDESC", "PRODID"}:
                if key in target:
                    raise ValueError(f"Duplicate property: {key}")
                target[key] = value if key == "CATEGORIES" else unescape(value)
    if event is not None or not events:
        raise ValueError("Unterminated or empty calendar")
    return header, events


def corrected(value: str, replacements: dict[str, str]) -> str:
    for before, after in replacements.items():
        value = value.replace(before, after)
    return value


SECTION_IDS = {
    "על החג והיום": "about", "סיפור מחייהם": "biography", "סיפור מחייו": "biography",
    "סיפור מחייה": "biography", "המסורת הסורית ומשמעות החג": "tradition",
    "פיוט": "hymn", "תפילה ומנהג": "prayer", "נקודה להרהור": "reflection",
    "מן הכתובים": "scripture", "סיפור מרכזי מחייה": "biography", "סיפור מרכזי מחייו": "biography",
    "מסיפור עדותם במסורת": "biography", "מסיפור עדותו במסורת": "biography",
    "מסיפור חייהם במסורת": "biography", "מסיפור חייה במסורת": "biography",
    "מסיפור עדותה במסורת": "biography", "עדות נוספת על חייו": "biography", "עוד על חייו": "biography",
    "עוד מן המסורת על חייו": "biography", "משמעות החג באמונה": "tradition", "מתורתו החינוכית": "biography",
}


def sections(description: str) -> list[dict]:
    # Only exact heading lines establish sections; ordinary colons/quotations stay prose.
    result, heading, lines = [], None, []
    def finish():
        if heading is not None and "\n".join(lines).strip():
            result.append({"id": SECTION_IDS[heading], "titleByLanguage": {"he": heading},
                           "textByLanguage": {"he": "\n".join(lines).strip()}})
    for line in description.splitlines():
        candidate = line.removesuffix(":")
        if line.endswith(":") and candidate in SECTION_IDS:
            finish()
            heading, lines = candidate, []
        else:
            lines.append(line)
    finish()
    return result


def build(raw: bytes, correction_map: dict) -> dict:
    digest = hashlib.sha256(raw).hexdigest()
    if digest != correction_map["sourceSha256"]:
        raise ValueError("Calendar source changed; review its corrections and coverage first")
    header, events = parse(raw)
    days = {}
    credit = "Urtotho — provisional Mission calendar (2026); " + header.get("X-WR-CALDESC", "")
    hebrew_credit = "Urtotho — לוח סורי קהילתי לתקופת ניסיון (2026); " + header.get("X-WR-CALDESC", "")
    for event in events:
        date = event["date"]
        if not date.startswith("2026-"):
            raise ValueError("This reviewed snapshot establishes 2026 dates only")
        title = corrected(event["SUMMARY"], correction_map["displayReplacements"])
        raw_description = event.get("DESCRIPTION", "")
        description = corrected(raw_description, correction_map["displayReplacements"])
        parts = sections(description)
        observance = {"identity": "mission:" + event["UID"], "title": title,
                      "titleByLanguage": {"he": title}, "sourceTitleByLanguage": {"he": event["SUMMARY"]},
                      "sourceUID": event["UID"], "sections": parts,
                      "categories": split_categories(event.get("CATEGORIES", "")),
                      "sourceRecurrence": event.get("RRULE", "")}
        if description:
            observance.update(descriptionByLanguage={"he": description},
                              sourceDescriptionByLanguage={"he": raw_description},
                              descriptionCreditByLanguage={"he": hebrew_credit})
        if event.get("URL"):
            observance["descriptionSourceByLanguage"] = {"he": event["URL"]}
        reflection = "\n\n".join(p["textByLanguage"]["he"] for p in parts if p["id"] == "reflection")
        if reflection:
            observance["reflectionByLanguage"] = {"he": reflection}
        rank_match = re.search(r"דרגה\s+([אבג])(?:[׳']|\b)", title)
        rank = {"א": "1st Class", "ב": "2nd Class", "ג": "3rd Class"}.get(rank_match[1] if rank_match else "", "")
        day = days.setdefault(date, {"title": "", "titleByLanguage": {"he": ""}, "rank": "", "observances": []})
        day["observances"].append(observance)
        if rank and (not day["rank"] or rank < day["rank"]):
            day["rank"] = rank
        day["title"] = "; ".join(part["title"] for part in day["observances"])
        day["titleByLanguage"]["he"] = day["title"]
    return {"$comment": "Separate provisional Mission calendar. Explicit source dates only; RRULE is never expanded.",
            "calendarId": CALENDAR_ID, "provisional": True, "scope": "Mission", "source": SOURCE.name,
            "sourceSha256": digest, "sourceCredit": credit, "sourceCalendarName": header.get("X-WR-CALNAME", ""),
            "coverageStart": min(days), "coverageEnd": max(days), "sourceEventCount": len(events),
            "editorialCorrections": correction_map["displayReplacements"], "days": dict(sorted(days.items()))}


def configure_registry(registry: dict) -> dict:
    """Keep Mission's supplied feasts with its explicitly chosen Evangelizo Syriac readings."""
    calendars = registry["calendars"]
    if sum(calendar["id"] == CALENDAR_ID for calendar in calendars) != 1:
        raise ValueError("Expected one provisional Mission calendar in the registry")
    return {**registry, "calendars": [
        {**calendar, "readingsFile": READINGS_FILE} if calendar["id"] == CALENDAR_ID else calendar
        for calendar in calendars
    ]}


def sync():
    for directory in (ROOT / "iOS/Prosary/Data", ROOT / "Android/app/src/main/assets/data", ROOT / "Windows/Prosary/Data"):
        for path in (OUTPUT, REGISTRY, ROOT / "Shared/data" / f"{READINGS_FILE}.json"):
            shutil.copyfile(path, directory / path.name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sync", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    document = build(SOURCE.read_bytes(), json.loads(CORRECTIONS.read_text()))
    data = json.dumps(document, ensure_ascii=False, indent=2) + "\n"
    registry_data = json.dumps(configure_registry(json.loads(REGISTRY.read_text())), ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if OUTPUT.read_text() != data:
            raise SystemExit("Provisional Mission calendar is stale")
        if REGISTRY.read_text() != registry_data:
            raise SystemExit("Provisional Mission readings mapping is stale")
    else:
        OUTPUT.write_text(data)
        REGISTRY.write_text(registry_data)
    if args.sync:
        sync()
    print(f"Mission provisional: {document['sourceEventCount']} source events on {len(document['days'])} explicit dates; "
          f"{document['coverageStart']}–{document['coverageEnd']}; no recurrence expansion")


if __name__ == "__main__":
    main()

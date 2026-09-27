"""Read the supplied Urtotho calendar without translating or extending its dates.

The reviewed index joins source UUIDs or exact liturgy records to Syriac identities.
It never applies these Hebrew labels to another calendar or treats RRULE as authority
to change Prosary's appointed dates. Source text is data, not executable instructions.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re

TOOLS = Path(__file__).resolve().parent
REFERENCE = TOOLS / "sources/syriac-calendar-2026-he.ics"
INDEX = TOOLS / "syriac-hebrew-identities.json"
CREDIT = "הלוח הסורי הקתולי בעברית — Urtotho (2026), שסופק למיזם; מקור: Evangelizo.org — Daily Gospel"


def unescape_text(value: str) -> str:
    return re.sub(r"\\([nN,;\\])", lambda match: "\n" if match[1] in "nN" else match[1], value)


def calendar_events(raw: bytes) -> dict[str, dict[str, str]]:
    text = raw.decode("utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"\n[ \t]", "", text)  # RFC 5545 line unfolding precedes text decoding.
    events: dict[str, dict[str, str]] = {}
    event = None
    for line in text.splitlines():
        if line == "BEGIN:VEVENT":
            if event is not None:
                raise ValueError("Nested calendar event")
            event = {}
        elif line == "END:VEVENT":
            if event is None or not all(event.get(key) for key in ("UID", "DTSTART", "SUMMARY")):
                raise ValueError("Incomplete calendar event")
            if event["UID"] in events:
                raise ValueError(f"Duplicate calendar UID: {event['UID']}")
            events[event["UID"]] = event
            event = None
        elif event is not None and ":" in line:
            property_name, value = line.split(":", 1)
            key = property_name.split(";", 1)[0]
            if key in {"UID", "DTSTART", "SUMMARY", "DESCRIPTION", "URL"}:
                if key in event:
                    raise ValueError(f"Duplicate calendar property: {key}")
                event[key] = unescape_text(value)
    if event is not None:
        raise ValueError("Unterminated calendar event")
    return events


def reviewed_events() -> list[dict[str, str]]:
    raw = REFERENCE.read_bytes()
    index = json.loads(INDEX.read_text())
    if hashlib.sha256(raw).hexdigest() != index["sourceSha256"]:
        raise ValueError("The supplied Hebrew Syriac calendar changed; review its identity index first")
    events = calendar_events(raw)
    result = []
    for uid, identity in index["events"].items():
        event = dict(events[uid])
        date = event["DTSTART"]
        if not re.fullmatch(r"2026\d{4}", date):
            raise ValueError(f"Unexpected source date: {date}")
        event.update(identity=identity, date=f"{date[:4]}-{date[4:6]}-{date[6:]}")
        result.append(event)
    return result


def apply_hebrew_reference(days: dict, aliases: dict[str, str], preferred_titles: dict[str, str] | None = None) -> int:
    """Apply sourced labels by identity; attach saint biographies to their exact source day."""
    def identity(value):
        seen = set()
        while value in aliases:
            if value in seen:
                raise ValueError(f"Cyclic Syriac identity: {value}")
            seen.add(value)
            value = aliases[value]
        return value

    titles = {}
    dated = {}
    preferred_titles = preferred_titles or {}
    # An actual saint's SUMMARY takes precedence over an accompanying liturgy caption.
    for event in sorted(reviewed_events(), key=lambda item: "/display-saint/" in item.get("URL", "")):
        key = identity(event["identity"])
        titles[key] = preferred_titles.get(key, event["SUMMARY"])
        dated[event["date"], key] = event
    count = 0
    for date, day in days.items():
        for part in day.get("observances", []):
            # Re-localization must also remove a previously imported description if its
            # reviewed identity/date is no longer in the source index.
            for field in ("descriptionByLanguage", "descriptionSourceByLanguage", "descriptionCreditByLanguage"):
                if field in part:
                    part[field].pop("he", None)
                    if not part[field]:
                        del part[field]
            key = identity(part["identity"])
            if key in titles:
                part.setdefault("titleByLanguage", {})["he"] = titles[key]
                count += 1
            event = dated.get((date, key))
            if not event or "/display-saint/" not in event.get("URL", ""):
                continue
            description = event.get("DESCRIPTION", "").strip()
            trailer = "\n\nמקור: Evangelizo\n" + event["URL"]
            if description.endswith(trailer):
                description = description[:-len(trailer)].rstrip()
            if description:
                part.setdefault("descriptionByLanguage", {})["he"] = description
                part.setdefault("descriptionSourceByLanguage", {})["he"] = event["URL"]
                part.setdefault("descriptionCreditByLanguage", {})["he"] = CREDIT
    return count

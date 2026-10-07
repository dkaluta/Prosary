#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Offline source-boundary and exact-day biography checks for the supplied Hebrew ICS."""
from copy import deepcopy
import hashlib
import json
from unittest.mock import patch
import syriac_hebrew_calendar as calendar


def rejects(raw):
    try:
        calendar.calendar_events(raw)
    except ValueError:
        return
    raise AssertionError("Malformed calendar accepted")


raw = ("BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:fixture\r\nDTSTART;VALUE=DATE:20260101\r\n"
       "SUMMARY:שם\\, ראשון\r\nDESCRIPTION:פסקה\\nשנייה\\; המשך\r\n מקופל\r\n"
       "URL:https://example.org/display-saint/one\r\nRRULE:FREQ=YEARLY\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n").encode()
parsed = calendar.calendar_events(raw)["fixture"]
assert parsed["SUMMARY"] == "שם, ראשון"
assert parsed["DESCRIPTION"] == "פסקה\nשנייה; המשךמקופל"
assert "RRULE" not in parsed
for invalid in (b"BEGIN:VEVENT\n", b"BEGIN:VEVENT\nBEGIN:VEVENT\n", b"BEGIN:VEVENT\nEND:VEVENT\n",
                raw.replace(b"UID:fixture", b"UID:fixture\nUID:duplicate"),
                raw + raw):
    rejects(invalid)

reviewed = calendar.reviewed_events()  # Also pins source bytes to the reviewed index hash.
assert reviewed and all(event["date"].startswith("2026-") for event in reviewed)
source = {event["date"]: event for event in reviewed
          if event["identity"] == "St. Thomas" and "/display-saint/" in event.get("URL", "")}
assert "2026-07-03" in source and "2026-10-06" in source
assert source["2026-07-03"]["URL"] != source["2026-10-06"]["URL"]
assert source["2026-07-03"]["DESCRIPTION"] != source["2026-10-06"]["DESCRIPTION"]

def part(identity="St. Thomas"):
    return {"title": "St. Thomas", "identity": identity}

days = {date: {"observances": [part()]} for date in ("2026-07-03", "2026-10-06", "2026-10-07", "2027-10-06")}
days["2026-07-03"]["observances"].append(part("Different saint"))
calendar.apply_hebrew_reference(days, {})
for date in source.keys() & days.keys():
    saint = days[date]["observances"][0]
    expected = source[date]["DESCRIPTION"].strip()
    trailer = "\n\nמקור: Evangelizo\n" + source[date]["URL"]
    if expected.endswith(trailer):
        expected = expected[:-len(trailer)].rstrip()
    assert saint["descriptionByLanguage"] == {"he": expected}
    assert saint["descriptionSourceByLanguage"] == {"he": source[date]["URL"]}
    assert saint["descriptionCreditByLanguage"] == {"he": calendar.CREDIT}
for date in ("2026-10-07", "2027-10-06"):
    assert "descriptionByLanguage" not in days[date]["observances"][0]
assert "descriptionByLanguage" not in days["2026-07-03"]["observances"][1]
before = deepcopy(days)
calendar.apply_hebrew_reference(days, {})
assert days == before
# Re-reviewing an identity clears obsolete Hebrew attribution without erasing other sources.
stale = {"2026-10-07": {"observances": [{**part(), "descriptionByLanguage": {"he": "old", "fr": "kept"},
    "descriptionSourceByLanguage": {"he": "old URL"}, "descriptionCreditByLanguage": {"he": "old credit"}}]}}
calendar.apply_hebrew_reference(stale, {})
saint = stale["2026-10-07"]["observances"][0]
assert saint["descriptionByLanguage"] == {"fr": "kept"}
assert "descriptionSourceByLanguage" not in saint and "descriptionCreditByLanguage" not in saint
# A liturgy description is not silently repurposed as a saint biography.
with patch.object(calendar, "reviewed_events", return_value=[{
    "date": "2026-01-01", "identity": "Fixture", "SUMMARY": "שם", "DESCRIPTION": "not a saint", "URL": "https://example.org/liturgy/day"}]):
    case = {"2026-01-01": {"observances": [part("Fixture")]}}
    calendar.apply_hebrew_reference(case, {}, {"Fixture": "Existing sourced title"})
    assert case["2026-01-01"]["observances"][0]["titleByLanguage"]["he"] == "Existing sourced title"
    assert "descriptionByLanguage" not in case["2026-01-01"]["observances"][0]
# The reviewed companion stays in Syriac. The separately supplied Mission calendar keeps
# its own provisional scope and source pin rather than sharing this biography projection.
for path in (calendar.TOOLS.parent / "data").glob("feasts*.json"):
    dataset = json.loads(path.read_text())
    if path.name == "feasts-mission-provisional.json":
        assert dataset["calendarId"] == "mission-provisional"
        assert dataset["provisional"] is True and dataset["scope"] == "Mission"
        assert dataset["source"] == "mission-provisional-2026-he.ics"
        supplied = calendar.TOOLS / "sources" / dataset["source"]
        assert dataset["sourceSha256"] == hashlib.sha256(supplied.read_bytes()).hexdigest()
        assert all(date.startswith("2026-") for date in dataset["days"])
        continue
    if path.name != "feasts-syriac.json":
        assert "Urtotho" not in json.dumps(dataset), path.name
        continue
    for date, day in dataset["days"].items():
        for saint in day["observances"]:
            if "he" not in saint.get("descriptionByLanguage", {}):
                continue
            url = saint["descriptionSourceByLanguage"]["he"]
            matches = [event for event in reviewed if event["date"] == date and event["URL"] == url]
            assert len(matches) == 1, (date, saint)
            assert saint["descriptionByLanguage"]["he"] in matches[0]["DESCRIPTION"], (date, saint)
            assert saint["descriptionCreditByLanguage"]["he"] == calendar.CREDIT
print("Hebrew ICS parsing, source hash, exact dates/identities, Thomas biographies, refresh and Syriac-only scope passed.")

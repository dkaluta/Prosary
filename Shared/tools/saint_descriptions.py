# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Attach reviewed source excerpts by exact calendar, date and observance identity.

This module is shared by the calendar importers. It never fetches prose, translates
it, normalizes saint names or infers that two saints on the same date are identical.
The small reviewed catalogue records the provider's per-language UUID and credit.
"""
from __future__ import annotations

import argparse
import copy
import json
import re
import shutil
from pathlib import Path
from urllib.parse import urlparse
from uuid import UUID

TOOLS_DIR = Path(__file__).resolve().parent
SHARED_DIR = TOOLS_DIR.parent
ROOT_DIR = SHARED_DIR.parent
CATALOGUE_PATH = TOOLS_DIR / "saint-descriptions-reviewed.json"
OWNED_CREDIT_PREFIX = "Prosary source excerpt — "
LANGUAGES = {"en", "he", "ar", "ru", "tl", "fr", "it", "uk"}
DESCRIPTION_FIELDS = (
    "descriptionByLanguage", "descriptionSourceByLanguage", "descriptionCreditByLanguage"
)


def load_catalogue(path: Path = CATALOGUE_PATH) -> dict:
    catalogue = json.loads(path.read_text(encoding="utf-8"))
    validate_catalogue(catalogue)
    return catalogue


def validate_catalogue(catalogue: dict) -> None:
    """Reject ambiguous joins and incomplete source provenance before changing data."""
    joins: dict[tuple[str, str, str, str], str] = {}
    for key, event in catalogue["events"].items():
        if not event.get("identity") or not event.get("descriptions"):
            raise ValueError(f"{key}: identity and descriptions are required")
        for date in event["dates"]:
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
                raise ValueError(f"{key}: explicit ISO dates are required")
            for calendar in event["calendars"]:
                for field in ("reviewedExactTitles", "reviewedExactIdentities"):
                    for spelling in event[field]:
                        join = (calendar, date, field, spelling)
                        if join in joins and joins[join] != key:
                            raise ValueError(f"Ambiguous saint-description join: {join}")
                        joins[join] = key
        for language, description in event["descriptions"].items():
            if language not in LANGUAGES:
                raise ValueError(f"{key}: unsupported description language {language}")
            text = description["text"]
            if not text.strip() or len(text.split()) > 25:
                raise ValueError(f"{key}/{language}: only reviewed short excerpts are allowed")
            source = urlparse(description["sourceURL"])
            subject_id = str(UUID(description["sourceSubjectID"]))
            if source.scheme != "https" or source.netloc != "publication.evangelizo.ws":
                raise ValueError(f"{key}/{language}: source must be the HTTPS publication page")
            if subject_id not in source.path and description["sourceField"] != "description":
                raise ValueError(f"{key}/{language}: source UUID must identify the source page")
            if not description["sourceTitle"] or not description["sourceEdition"]:
                raise ValueError(f"{key}/{language}: source subject and edition are required")
            if not re.fullmatch(r"[0-9a-f]{64}", description["sourceTextSHA256"]):
                raise ValueError(f"{key}/{language}: original source digest is required")
            if not description["credit"].startswith(OWNED_CREDIT_PREFIX):
                raise ValueError(f"{key}/{language}: provider credit must accompany prose")


def _clear_owned_descriptions(observance: dict) -> None:
    """Remove only our previous excerpts, preserving independently credited prose."""
    owned = {
        language for language, credit in observance.get("descriptionCreditByLanguage", {}).items()
        if credit.startswith(OWNED_CREDIT_PREFIX)
    }
    for field in DESCRIPTION_FIELDS:
        values = observance.get(field)
        if values is not None:
            for language in owned:
                values.pop(language, None)
            if not values:
                observance.pop(field, None)


def add_sourced_descriptions(days: dict, calendar_id: str, catalogue: dict | None = None) -> int:
    """Enrich data in place; return the number of exactly matched observances.

    A legacy day becomes one observance only when its entire original title is an
    explicitly reviewed spelling. Compound days are never split heuristically.
    Existing independent descriptions win when a language already has prose.
    """
    catalogue = load_catalogue() if catalogue is None else catalogue
    validate_catalogue(catalogue)
    matched = 0
    for date, day in days.items():
        events = [event for event in catalogue["events"].values()
                  if calendar_id in event["calendars"] and date in event["dates"]]
        observances = day.get("observances")
        if not observances:
            event = next((event for event in events
                          if day["title"] in event["reviewedExactTitles"]), None)
            if event is None:
                continue
            observance = {"title": day["title"], "identity": event["identity"]}
            if day.get("titleByLanguage"):
                observance["titleByLanguage"] = copy.deepcopy(day["titleByLanguage"])
            observances = day["observances"] = [observance]
        for observance in observances:
            _clear_owned_descriptions(observance)
            matching = [event for event in events
                        if observance["title"] in event["reviewedExactTitles"]
                        or observance.get("identity") in event["reviewedExactIdentities"]]
            if len(matching) > 1:
                raise ValueError(f"Ambiguous observance {calendar_id}/{date}/{observance['title']}")
            if not matching:
                continue
            if len(observances) == 1 and observance["title"] == day["title"] and day.get("titleByLanguage"):
                # The generic localizer updates the assembled day after a fetch.
                # A one-observance day has the same sourced title and must keep
                # those refreshed labels when it exposes its description.
                observance.setdefault("titleByLanguage", {}).update(copy.deepcopy(day["titleByLanguage"]))
            matched += 1
            for language, source in matching[0]["descriptions"].items():
                if observance.get("descriptionByLanguage", {}).get(language):
                    continue
                for field, source_key in zip(DESCRIPTION_FIELDS, ("text", "sourceURL", "credit")):
                    observance.setdefault(field, {})[language] = source[source_key]
    return matched


def enrich_existing(sync: bool) -> None:
    catalogue = load_catalogue()
    registry = json.loads((SHARED_DIR / "data/calendars.json").read_text(encoding="utf-8"))
    supported = {calendar for event in catalogue["events"].values() for calendar in event["calendars"]}
    for calendar in registry["calendars"]:
        if calendar["id"] not in supported:
            continue
        path = SHARED_DIR / "data" / f"{calendar['file']}.json"
        if not path.exists():
            continue
        payload = json.loads(path.read_text(encoding="utf-8"))
        matched = add_sourced_descriptions(payload["days"], calendar["id"], catalogue)
        note = " Optional exact-language saint/feast excerpts: Shared/tools/saint-descriptions-reviewed.json; reviewed source UUID/date/identity joins only."
        if matched and note not in payload.get("$comment", ""):
            payload["$comment"] = payload.get("$comment", "") + note
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        if sync:
            for directory in ("iOS/Prosary/Data", "Android/app/src/main/assets/data", "Windows/Prosary/Data"):
                destination = ROOT_DIR / directory / path.name
                if not destination.parent.exists():
                    raise ValueError(f"Missing native data directory: {destination.parent}")
                shutil.copyfile(path, destination)
        print(f"{calendar['id']}: {matched} reviewed observances")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--enrich-existing", action="store_true", help="Enrich canonical datasets listed in calendars.json")
    parser.add_argument("--sync", action="store_true", help="Copy enriched canonical datasets to all three native ports")
    args = parser.parse_args()
    if not args.enrich_existing:
        parser.error("Select --enrich-existing (importers call add_sourced_descriptions directly)")
    enrich_existing(args.sync)

#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Exact citation and calendar reviews, tied to inspected source payloads.

A review is not a general versification declaration. The builder must retain its
normal corpus completeness checks and refuse editions outside reviewedEditionIds.
No Scripture is fetched or altered here.
"""
from __future__ import annotations

from functools import lru_cache
import json
from pathlib import Path
import re

from reading_versification import SUPPORTED_BOOKS, SYSTEMS

TOOLS = Path(__file__).resolve().parent
REVIEWS = TOOLS / "reading-appointment-reviews.json"
SOURCE_LOCK = TOOLS / "reading-text-sources.json"
CALENDARS = frozenset({"roman", "roman1962", "ugcc", "ugcc-gregorian", "syriac", "maronite", "torah"})


def load_reviews(path: Path = REVIEWS, source_lock_path: Path = SOURCE_LOCK) -> dict[str, dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    source_lock = json.loads(source_lock_path.read_text(encoding="utf-8"))
    if data.get("schemaVersion") != 1 or not isinstance(data.get("appointments"), dict):
        raise ValueError("Unsupported appointment review manifest")
    source_pins = {source["id"]: source["sha256"] for source in source_lock["sources"]}
    editions = {edition["id"]: edition for edition in source_lock["editions"]}
    for key, review in data["appointments"].items():
        contexts = review.get("contexts", [])
        ids = review.get("reviewedEditionIds", [])
        pins = review.get("sourcePins", {})
        references = review.get("editionReferences", {})
        if (not key.startswith(("daily|", "torah|")) or not contexts
                or len(contexts) != len(set(contexts)) or not set(contexts) <= CALENDARS
                or review.get("sourceSystem") not in {*SYSTEMS, "reviewed"}
                or type(review.get("includesWholeVerses")) is not bool
                or not ids or len(ids) != len(set(ids)) or not set(ids) <= editions.keys()
                or set(references) != set(ids) or not pins):
            raise ValueError(f"Invalid appointment review scope: {key}")
        for source_id, sha256 in pins.items():
            if (not re.fullmatch(r"[0-9a-f]{64}", sha256)
                    or source_pins.get(source_id) != sha256):
                raise ValueError(f"Appointment review source changed: {source_id}; review boundaries again")
        for edition_id, values in references.items():
            if not any(source["id"] in pins for source in editions[edition_id]["sources"]):
                raise ValueError(f"Appointment review has no pinned source for {edition_id}")
            if not values or any(
                not isinstance(value, list) or len(value) != 3
                or value[0] not in SUPPORTED_BOOKS
                or any(type(number) is not int or number < 1 for number in value[1:])
                for value in values
            ):
                raise ValueError(f"Invalid reviewed verse sequence: {edition_id}")
            sequence = [tuple(value) for value in values]
            if (len(sequence) != len(set(sequence))
                    or len({value[0] for value in sequence}) != 1
                    or sequence != sorted(sequence)):
                raise ValueError(f"Overlapping or unordered reviewed verse sequence: {edition_id}")
    return data["appointments"]


@lru_cache(maxsize=1)
def _reviews() -> dict[str, dict]:
    return load_reviews()


def reviewed_appointment(key: str, contexts: set[str]) -> dict | None:
    review = _reviews().get(key)
    if review is None or not contexts or not contexts <= set(review["contexts"]):
        return None
    return review


def has_appointment_review(key: str) -> bool:
    """Known boundaries must not fall back when a new calendar adds the citation."""
    return key in _reviews()


def reviewed_references(review: dict | None, edition_id: str) -> list[tuple[str, int, int]] | None:
    if review is None or edition_id not in review["reviewedEditionIds"]:
        return None
    return [tuple(value) for value in review["editionReferences"][edition_id]]


if __name__ == "__main__":
    print(f"Verified {len(load_reviews())} bounded appointment review(s).")

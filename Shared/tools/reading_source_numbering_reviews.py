#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Bounded source-numbering evidence; no edition words or target verse overrides."""
from functools import lru_cache
import json
from pathlib import Path
import re
from urllib.parse import urlparse

from reading_appointment_reviews import CALENDARS

PATH = Path(__file__).with_name("reading-source-numbering-reviews.json")


def load_reviews(path: Path = PATH) -> dict:
    data = json.loads(path.read_text())
    if set(data) != {"schemaVersion", "appointments"} or data["schemaVersion"] != 1:
        raise ValueError("Unsupported source-numbering review manifest")
    if not isinstance(data["appointments"], dict):
        raise ValueError("Invalid source-numbering appointments")
    for key, review in data["appointments"].items():
        if (not key.startswith("daily|") or set(review) != {"contexts", "sourceSystem", "reviewedOn", "evidence"}
                or review["sourceSystem"] != "nabre"
                or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", review["reviewedOn"])):
            raise ValueError("Invalid source-numbering review scope")
        contexts = review["contexts"]
        if (not isinstance(contexts, list) or not contexts or len(contexts) != len(set(contexts))
                or not set(contexts) <= CALENDARS - {"torah"}):
            raise ValueError("Invalid source-numbering calendar contexts")
        evidence = review["evidence"]
        if set(evidence) != {"appointmentURL", "appointmentSHA256", "readingCode",
                             "corroboratingURL", "corroboratingSHA256", "corroboratingReference", "scope"}:
            raise ValueError("Unexpected source-numbering evidence fields")
        for field in ("appointmentSHA256", "corroboratingSHA256"):
            if not re.fullmatch(r"[a-f0-9]{64}", evidence[field]):
                raise ValueError("Missing source-numbering evidence checksum")
        for field in ("appointmentURL", "corroboratingURL"):
            url = urlparse(evidence[field])
            if url.scheme != "https" or not url.netloc or url.username or url.password:
                raise ValueError("Invalid source-numbering evidence URL")
        if any(not isinstance(evidence[field], str) or not evidence[field].strip()
               for field in ("readingCode", "corroboratingReference", "scope")):
            raise ValueError("Missing source-numbering evidence")
    return data["appointments"]


@lru_cache(maxsize=1)
def _reviews() -> dict:
    return load_reviews()


def reviewed_numbering(key: str, contexts: set[str]) -> dict | None:
    review = _reviews().get(key)
    if review is None or not contexts or not contexts <= set(review["contexts"]):
        return None
    return review


if __name__ == "__main__":
    print(f"Verified {len(load_reviews())} exact source-numbering reviews; no Scripture text.")

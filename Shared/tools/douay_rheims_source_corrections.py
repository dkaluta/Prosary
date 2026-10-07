#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Source-witnessed corrections to named omissions in the eBible DRA import."""
import hashlib
import json
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
REVIEW_PATH = TOOLS / "douay-rheims-source-corrections.json"


def apply_source_corrections(source: dict, corpus: dict) -> dict:
    if source.get("id") != "engDRA":
        return corpus
    review = json.loads(REVIEW_PATH.read_text(encoding="utf-8"))
    if (review.get("schemaVersion") != 1 or review.get("sourceId") != source["id"]
            or review.get("sourceSHA256") != source.get("sha256")):
        raise ValueError("Douay–Rheims correction belongs to another source revision")
    corrected = {chapter: dict(rows) for chapter, rows in corpus.items()}
    seen = set()
    for row in review["corrections"]:
        book, chapter, verse = row["reference"]
        reference = book, chapter, verse
        current = corrected.get((book, chapter), {}).get(verse)
        if (reference in seen or current != row["originalText"]
                or hashlib.sha256((current or "").encode()).hexdigest() != row["originalTextSHA256"]):
            raise ValueError("Douay–Rheims omission no longer matches the reviewed original verse")
        text = row["correctedText"]
        witnesses = row["witnesses"]
        if (hashlib.sha256(text.encode()).hexdigest() != row["correctedTextSHA256"]
                or len(witnesses) < 2 or len({witness["url"] for witness in witnesses}) != len(witnesses)
                or any(witness["excerpt"] != text or not witness["url"].startswith("https://")
                       or len(witness["payloadSHA256"]) != 64 for witness in witnesses)):
            raise ValueError("Douay–Rheims correction lacks matching independent textual witnesses")
        corrected[book, chapter][verse] = text
        seen.add(reference)
    return corrected

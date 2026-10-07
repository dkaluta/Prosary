#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Exact Psalm119 daily excerpts from unchanged website Psalm118 source units.

Source-native Bible browsing omits the marker at91 and marks the chapter partial.
This bounded path permits seven independently inspected appointments that never
request91. It neither fills the missing verse nor opens the incomplete chapter
for general reference conversion. Both native display scripts remain paired.
"""
from dataclasses import dataclass
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import re

from peshitta_eu_source import VerseParser
from peshitta_reading_source import paired_text

TOOLS = Path(__file__).resolve().parent
REVIEWS = TOOLS / "peshitta-daily-psalm-reviews.json"
SOURCE_ID = "peshitta-eu-2020-psa-118"
SOURCE_SHA256 = "b3c8873c6e70f33801d054d7db03773e0216a04393114b5ad722d190cdd8f7d1"


class Unavailable(ValueError):
    pass


@dataclass(frozen=True)
class Passage:
    verses: list[dict]
    includes_whole_verses: bool
    # Paired editions use their existing edition credit; no foreign unpaired source wrapper.
    source: None = None


class _Psalm118Parser(VerseParser):
    def __init__(self):
        super().__init__("psalms", 118)
        self.omission_seen = False

    def handle_endtag(self, tag):
        if self.current != 91:
            return super().handle_endtag(tag)
        if (tag != "span" or self.omission_seen
                or "".join(self.words).strip() != "91 (ܠܝܬ)"):
            raise ValueError("Peshitta Psalm118 omission marker differs from its review")
        self.omission_seen = True
        self.current = None


def source_rows(raw: bytes, *, expected_sha256: str = SOURCE_SHA256) -> dict[int, str]:
    if hashlib.sha256(raw).hexdigest() != expected_sha256:
        raise ValueError("Peshitta Psalm118 source changed; review its actual units again")
    parser = _Psalm118Parser()
    parser.feed(raw.decode("utf-8-sig"))
    parser.close()
    if (parser.current is not None or not parser.omission_seen
            or list(parser.values) != [verse for verse in range(1, 177) if verse != 91]):
        raise ValueError("Peshitta Psalm118 source inventory differs from its bounded review")
    # Every accepted row must support both existing scripts, independently of selection.
    for value in parser.values.values():
        paired_text(value)
    return parser.values


def load_reviews(path: Path = REVIEWS) -> dict:
    value = json.loads(path.read_text())
    if (value.get("schemaVersion") != 1 or value.get("editionId") != "peshitta-1905"
            or value.get("sourceId") != SOURCE_ID or value.get("sourceSHA256") != SOURCE_SHA256
            or not isinstance(value.get("appointments"), dict) or not value["appointments"]):
        raise ValueError("Peshitta daily Psalm review differs from its primary source pin")
    for key, review in value["appointments"].items():
        labels = review.get("sourceVerses", [])
        hashes = review.get("sourceVerseSHA256", [])
        if (not key.startswith("daily|Psalm 119:") or review.get("contexts") != ["roman"]
                or review.get("sourceChapter") != 118 or type(review.get("includesWholeVerses")) is not bool
                or not labels or any(type(verse) is not int or not 1 <= verse <= 176 or verse == 91 for verse in labels)
                or labels != sorted(set(labels)) or len(hashes) != len(labels)
                or any(not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest) for digest in hashes)
                or not review.get("boundaryReview") or not review.get("evidenceURLs")):
            raise ValueError(f"Malformed or incomplete bounded Peshitta Psalm appointment: {key}")
    return value["appointments"]


class Resolver:
    def __init__(self, raw: bytes, reviews: dict, *, expected_sha256: str = SOURCE_SHA256):
        self.rows = source_rows(raw, expected_sha256=expected_sha256)
        self.reviews = reviews
        for review in reviews.values():
            if any(verse not in self.rows or hashlib.sha256(self.rows[verse].encode()).hexdigest() != digest
                   for verse, digest in zip(review["sourceVerses"], review["sourceVerseSHA256"], strict=True)):
                raise ValueError("A reviewed Peshitta Psalm unit changed or is unavailable")

    def handles(self, key: str) -> bool:
        return key in self.reviews

    def resolve(self, key: str, contexts: set[str]) -> Passage:
        review = self.reviews.get(key)
        if review is None or not contexts or not contexts <= set(review["contexts"]):
            raise Unavailable("Peshitta Psalm outside its exact reviewed appointment/calendar")
        result = []
        for verse in review["sourceVerses"]:
            primary, syriac = paired_text(self.rows[verse])
            result.append({"chapter": 118, "verse": verse, "text": primary, "transliteratedText": syriac})
        return Passage(result, review["includesWholeVerses"])


@lru_cache(maxsize=1)
def default_resolver() -> Resolver:
    lock = json.loads((TOOLS / "reading-text-sources.json").read_text())
    source = next(row for row in lock["sources"] if row["id"] == SOURCE_ID)
    if (source["sha256"] != SOURCE_SHA256 or source["format"] != "peshitta-eu-2020"
            or source["book"] != "PSA" or source["chapter"] != 118):
        raise ValueError("Peshitta Psalm118 lock changed; renew its bounded review")
    cache = TOOLS / ".scripture-cache"
    path = cache / source["cache"]
    if not path.resolve().is_relative_to(cache.resolve()):
        raise ValueError("Peshitta source cache escapes its folder")
    return Resolver(path.read_bytes(), load_reviews())

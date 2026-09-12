#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Edition-specific whole-verse correspondences, using numeric metadata only.

The public mapper never opens a Bible text file. Its numeric inventories are
generated from the same source pins as the reader, and each profile separately
reviews numbering families, local boundaries and incomplete source chapters.
"""
from __future__ import annotations

from functools import lru_cache
import hashlib
import json
from pathlib import Path
import re

from reading_step_mapping import StepMapper, Unavailable

TOOLS = Path(__file__).resolve().parent
DIRECTORY = TOOLS / "versification/editions"
INVENTORIES = DIRECTORY / "inventories.json"
EDITION_IDS = frozenset({"douay-rheims-1899", "masoretic-delitzsch", "synodal-1876",
    "ang-dating-biblia-1905", "crampon-1923", "martini", "kulish-1905", "jesuit-arabic-1897"})
METHOD = "pinned-imported-verse-word-counts-v1"
REVIEW_FILES = (
    "reading-text-sources.json", "build-reading-texts.py", "build-edition-mappings.py",
    "reading_edition_mapping.py", "reading_edition_reviews_hebrew.py",
    "reading_edition_reviews_western.py", "reading_edition_reviews_arabic.py",
    "reading_step_mapping.py", "reading_psalm_mapping.py", "reading_boundary_groups.py",
    "reading_versification.py", "delitzsch_numbering.py", "versification/sources.json",
    "versification/step/sources.json", "versification/step/rules.json",
    "versification/org.vrs.txt", "versification/eng.vrs.txt", "versification/vul.vrs.txt", "versification/rso.vrs.txt",
)
_HASH = re.compile(r"[0-9a-f]{64}")
BOOK_CODES = frozenset("GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH EST JOB PSA PRO ECC SNG ISA JER LAM EZK DAN HOS JOL AMO OBA JON MIC NAM HAB ZEP HAG ZEC MAL MAT MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM HEB JAS 1PE 2PE 1JN 2JN 3JN JUD REV TOB JDT WIS SIR BAR 1MA 2MA".split())
STANDARD_BOOK_CODES = BOOK_CODES | {"SUS", "BEL", "ESG", "S3Y", "1ES", "2ES", "3MA", "4MA", "MAN", "PS2"}


def source_pin_digest(pins: dict[str, str]) -> str:
    return hashlib.sha256(json.dumps(pins, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def corpus_digest(corpus: dict) -> str:
    """Bind an imported corpus without retaining its words in the metadata."""
    digest = hashlib.sha256()
    for (book, chapter), values in sorted(corpus.items()):
        for verse, text in sorted(values.items()):
            digest.update((json.dumps([book, chapter, verse, text], ensure_ascii=False,
                                      separators=(",", ":")) + "\n").encode())
    return digest.hexdigest()


def profile_for(edition_id: str) -> dict:
    if edition_id == "douay-rheims-1899":
        from reading_psalm_mapping import DRA_PSALM_SOURCE_OVERLAPS
        return {"source_pin_digest": source_pin_digest({"engDRA":
            "96282bfa7c89a74680cea66fe873aafa5e7cd446407f0ff2531a723e19eee2c2"}),
            "source_types": None, "overrides": DRA_PSALM_SOURCE_OVERLAPS,
            "blocked_chapters": set(), "reviewed_inventory_exceptions": set()}
    from reading_edition_reviews_hebrew import PROFILES as hebrew
    from reading_edition_reviews_western import PROFILES as western
    from reading_edition_reviews_arabic import PROFILES as arabic
    profiles = hebrew | western | arabic
    if edition_id not in profiles:
        raise ValueError("Bible edition has no reviewed reference profile")
    return profiles[edition_id]


def validate_record(record: dict) -> dict:
    allowed = {"sourcePins", "corpusSHA256", "chapters", "systems", "arabicMetadata"}
    if (not isinstance(record, dict) or not set(record) <= allowed
            or not allowed.difference({"arabicMetadata"}) <= record.keys()):
        raise ValueError("Unexpected edition inventory fields")
    pins = record["sourcePins"]
    if (not isinstance(pins, dict) or not pins or any(not isinstance(key, str)
            or not isinstance(value, str) or not _HASH.fullmatch(value) for key, value in pins.items())
            or not isinstance(record["corpusSHA256"], str) or not _HASH.fullmatch(record["corpusSHA256"])):
        raise ValueError("Invalid edition inventory provenance")
    if (not isinstance(record["systems"], dict) or set(record["systems"]) != {"ot", "nt"}
            or any(not isinstance(value, str) or value not in {"org", "eng", "vul", "rso", "delitzsch-1901"}
                   for value in record["systems"].values())):
        raise ValueError("Invalid edition inventory baseline")
    if not isinstance(record["chapters"], list) or not record["chapters"]:
        raise ValueError("Missing edition chapter inventory")
    corpus = {}
    for row in record["chapters"]:
        if (not isinstance(row, list) or len(row) != 3 or not isinstance(row[0], str)
                or row[0] not in BOOK_CODES
                or type(row[1]) is not int or row[1] < 1 or not isinstance(row[2], list)):
            raise ValueError("Invalid edition chapter")
        book, chapter, verses = row
        if (book, chapter) in corpus or not verses:
            raise ValueError("Duplicated or empty edition chapter")
        values = {}
        for pair in verses:
            if (not isinstance(pair, list) or len(pair) != 2 or type(pair[0]) is not int
                    or pair[0] < 1 or type(pair[1]) is not int or not 0 <= pair[1] <= 10000
                    or pair[0] in values):
                raise ValueError("Invalid, duplicated or nonnumeric verse metadata")
            values[pair[0]] = pair[1]
        corpus[book, chapter] = values
    return corpus


@lru_cache(maxsize=1)
def load_inventory() -> dict:
    raw = INVENTORIES.read_bytes()
    provenance = json.loads((DIRECTORY / "sources.json").read_text())
    if (not isinstance(provenance, dict) or type(provenance.get("schemaVersion")) is not int
            or provenance.get("schemaVersion") != 1
            or set(provenance) != {"schemaVersion", "inventorySHA256", "reviewFiles", "coverage"}
            or not isinstance(provenance["reviewFiles"], dict)
            or set(provenance["reviewFiles"]) != set(REVIEW_FILES)
            or hashlib.sha256(raw).hexdigest() != provenance.get("inventorySHA256")):
        raise ValueError("Edition reference inventory checksum changed")
    for name, expected in provenance["reviewFiles"].items():
        path = TOOLS / name
        if not path.resolve().is_relative_to(TOOLS) or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError("Edition review changed; regenerate its numeric inventory")
    data = json.loads(raw)
    if (not isinstance(data, dict) or set(data) != {"schemaVersion", "standard", "method", "editions"}
            or type(data["schemaVersion"]) is not int or data["schemaVersion"] != 1
            or data["standard"] != "STEP" or data["method"] != METHOD
            or not isinstance(data["editions"], dict) or set(data["editions"]) != EDITION_IDS):
        raise ValueError("Unsupported edition reference inventory")
    for record in data["editions"].values():
        validate_record(record)
    return data["editions"]


def excluded_chapters(edition_id: str, corpus: dict, systems: dict, profile: dict) -> set:
    """Retain old completeness guards unless a chapter has a specific review."""
    from reading_versification import chapter_matches
    from delitzsch_numbering import chapter_matches as delitzsch_matches
    nt = set("MAT MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM HEB JAS 1PE 2PE 1JN 2JN 3JN JUD REV".split())
    excluded = set(profile.get("blocked_chapters", ()))
    exceptions = set(profile.get("reviewed_inventory_exceptions", ()))
    for (book, chapter), values in corpus.items():
        if (not values or any(not value for value in values.values())
                or set(values) != set(range(1, max(values) + 1))):
            excluded.add((book, chapter))
            continue
        if edition_id == "douay-rheims-1899" or (book, chapter) in exceptions:
            continue
        system = systems["nt" if book in nt else "ot"]
        # The existing validators inspect verse keys, so synthetic nonempty
        # values preserve their exact behavior without reading Scripture words.
        synthetic = {verse: "present" for verse in values}
        complete = (delitzsch_matches(book, chapter, synthetic) if system == "delitzsch-1901"
                    else chapter_matches(system, book, chapter, synthetic))
        if not complete:
            excluded.add((book, chapter))
    return excluded


class EditionMapper:
    def __init__(self, edition_id: str, record: dict, *, profile: dict | None = None):
        self.edition_id = edition_id
        self.record = record
        self.corpus = validate_record(record)
        profile = profile if profile is not None else profile_for(edition_id)
        if source_pin_digest(record["sourcePins"]) != profile["source_pin_digest"]:
            raise ValueError("Edition sources differ from their reviewed mapping profile")
        self.excluded_chapters = set()
        if edition_id == "jesuit-arabic-1897":
            from reading_edition_reviews_arabic import ReviewedArabicMapper
            self.converter = ReviewedArabicMapper.from_metadata(record["arabicMetadata"])
            arabic = record["arabicMetadata"]
            numeric = {tuple(row["reference"]): row["wordCount"] for row in arabic["verses"]}
            if (self.converter.source_pins != record["sourcePins"] or numeric != {
                    (book, chapter, verse): count for (book, chapter), verses in self.corpus.items()
                    for verse, count in verses.items()}):
                raise ValueError("Arabic unit metadata and edition inventory differ")
        else:
            self.excluded_chapters = excluded_chapters(edition_id, self.corpus, record["systems"], profile)
            overrides = {key: targets for key, targets in profile.get("overrides", {}).items()
                         if key[:2] not in self.excluded_chapters}
            self.converter = StepMapper(self.corpus, edition_id,
                source_types=profile["source_types"], overrides=overrides,
                subverse_labels=(), excluded_chapters=self.excluded_chapters,
                local_rule_lines=profile.get("local_rule_lines"),
                excluded_rule_lines=profile.get("excluded_rule_lines", ()))

    def validate_source(self, corpus: dict, source_pins: dict[str, str]) -> None:
        if source_pins != self.record["sourcePins"] or corpus_digest(corpus) != self.record["corpusSHA256"]:
            raise ValueError("Bible text differs from the source reviewed for its reference mapping")

    def chapter_available(self, book: str, chapter: int) -> bool:
        return (self.edition_id != "jesuit-arabic-1897" and
                (book, chapter) in self.corpus and (book, chapter) not in self.excluded_chapters)

    @staticmethod
    def _references(refs):
        result = list(refs)
        if not result or any(not isinstance(ref, (tuple, list)) or len(ref) != 3
                or not isinstance(ref[0], str) or ref[0] not in STANDARD_BOOK_CODES
                or not (type(ref[1]) is int and ref[1] > 0 or
                        isinstance(ref[1], str) and ref[1] in "ABCDEF" and len(ref[1]) == 1)
                or type(ref[2]) is not int or ref[2] < 0 for ref in result):
            raise Unavailable("Empty or malformed edition reference sequence")
        return [tuple(ref) for ref in result]

    def to_standard(self, refs):
        return self.converter.to_standard(self._references(refs))

    def from_standard(self, refs):
        return self.converter.from_standard(self._references(refs))

    def coverage(self) -> dict:
        labels = {(book, chapter, verse) for (book, chapter), values in self.corpus.items() for verse in values}
        if self.edition_id == "jesuit-arabic-1897":
            return {"labels": len(labels), "mapped": len(labels), "policy": "reviewed-units",
                    "blockedChapters": []}
        available = {ref for ref in labels if self.converter.forward.get(ref)
                     and ref not in self.converter.blocked_sources}
        return {"labels": len(labels), "mapped": len(available), "policy": "whole-verses",
                "blockedChapters": [list(ref) for ref in sorted(self.excluded_chapters)]}


@lru_cache(maxsize=8)
def mapper(edition_id: str) -> EditionMapper:
    if edition_id not in EDITION_IDS:
        raise ValueError("Unknown Bible edition")
    return EditionMapper(edition_id, load_inventory()[edition_id])


def convert_references(source_edition: str, target_edition: str, references) -> tuple[list, bool]:
    """Map supported editions through Standard, preserving complete verse units."""
    if source_edition == "NABRE":
        from reading_nabre_mapping import mapper as nabre
        standard, whole = nabre().to_standard(references)
    else:
        standard, whole = mapper(source_edition).to_standard(references)
    target, target_whole = mapper(target_edition).from_standard(standard)
    return target, whole or target_whole

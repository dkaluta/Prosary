#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Reference-only adapter for the bounded, reviewed 1897 Jesuit Arabic corpus.

The existing canonical transcription and ARABIC-SCRIPTURE-SOURCES.markdown establish
72 indivisible passage envelopes, containing 239 distinct verses. The source and
STEP Standard labels agree for those complete envelopes; this does NOT establish
individual verse boundaries inside them. In particular, Luke 1:32-33 and 22:43-44
divide their clauses differently in the inspected printing.

No Latin/Greek family rules or chapter-completeness predicates are selected.
AllBibles empty-verse notices (27491, 27492, 27495) do not authorize losing words;
a sparse transcription cannot prove absence. ARABIC-REFERENCE-REVIEW.markdown
records the eight added units' printed clause boundaries and KJV Standard
witnesses, including Isaiah 9:2's distinction from Hebrew numbering. Those manual
reviews, not a Vulgate label, establish the explicit units below. No new wording,
OCR, or transcription is introduced by this adapter.

reference_metadata() extracts references, page evidence, counts and hashes at build
time. from_metadata() reads only that exported, hash-pinned metadata and never
opens the transcription. The builder constructor also checks the supplied source
words against their hashes whenever it resolves a complete unit.
"""
from __future__ import annotations

from collections import defaultdict
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import re
from typing import Iterable

from reading_step_mapping import Unavailable

Reference = tuple[str, int, int]
EDITION_ID = "jesuit-arabic-1897"
SOURCE_ID = "old-jesuit-arabic-1897"
SOURCE_SHA256 = "9495719b3f1573e7a446dc22dbeb3014e913d69b5bfff71239dd9602c0efeda8"
SOURCE_PIN_DIGEST = "c6d5d35959ddd11e9f44d01098d32a2bcd127ebf734b4519ff3b01e3613e7a96"
SOURCE_PATH = Path(__file__).resolve().parents[1] / "content/arabic-jesuit-1897.json"
_BOOKS = {"Isaiah": "ISA", "Matthew": "MAT", "Mark": "MRK", "Luke": "LUK",
          "John": "JHN", "Acts": "ACT", "Revelation": "REV"}
_ORDER = {book: index for index, book in enumerate(_BOOKS.values())}

# These are the existing reviewUnits in their pinned review order, not individual
# source-to-Standard verse edges. Omissions inside a unit remain explicit.
_SPANS = (
    ("MAT", 2, ((9, 11),)), ("LUK", 1, ((26, 38),)),
    ("LUK", 1, ((39, 45),)), ("LUK", 2, ((6, 7),)),
    ("LUK", 2, ((22, 24),)), ("LUK", 2, ((46, 49),)),
    ("LUK", 22, ((41, 44),)), ("JHN", 19, ((1, 1),)),
    ("JHN", 19, ((2, 3),)), ("JHN", 19, ((17, 17),)),
    ("LUK", 23, ((44, 46),)), ("MAT", 28, ((5, 6),)),
    ("ACT", 1, ((9, 11),)), ("ACT", 2, ((2, 4),)),
    ("REV", 12, ((1, 1),)), ("MAT", 3, ((16, 17),)),
    ("JHN", 2, ((7, 11),)), ("MRK", 1, ((14, 15),)),
    ("MAT", 17, ((1, 2), (5, 5))), ("MAT", 26, ((26, 28),)),
    ("LUK", 2, ((34, 35),)), ("MAT", 2, ((13, 14),)),
    ("LUK", 2, ((43, 45),)), ("JHN", 19, ((25, 27),)),
    ("JHN", 19, ((38, 40),)), ("JHN", 19, ((41, 42),)),
    ("ISA", 53, ((8, 8),)), ("ISA", 53, ((4, 4),)),
    ("ISA", 53, ((5, 5),)), ("ISA", 66, ((13, 13),)),
    ("MRK", 15, ((21, 22),)), ("ISA", 53, ((6, 6),)),
    ("LUK", 23, ((27, 28),)), ("JHN", 1, ((29, 29),)),
    ("JHN", 19, ((23, 24),)), ("JHN", 3, ((14, 15),)),
    ("MRK", 15, ((46, 46),)), ("LUK", 23, ((50, 56),)),
    ("MRK", 14, ((32, 36),)), ("MRK", 14, ((45, 46),)),
    ("MRK", 14, ((55, 55), (60, 64))), ("MRK", 14, ((66, 72),)),
    ("MRK", 15, ((14, 15),)), ("MRK", 15, ((17, 19),)),
    ("MRK", 15, ((20, 20),)), ("MRK", 15, ((21, 21),)),
    ("MRK", 15, ((24, 24),)), ("LUK", 23, ((39, 42),)),
    ("JHN", 19, ((26, 27),)), ("MRK", 15, ((33, 39),)),
    ("MAT", 28, ((1, 7),)), ("JHN", 20, ((3, 9),)),
    ("JHN", 20, ((11, 18),)), ("LUK", 24, ((13, 16), (25, 27))),
    ("LUK", 24, ((28, 35),)), ("LUK", 24, ((36, 43),)),
    ("JHN", 20, ((19, 23),)), ("JHN", 20, ((24, 29),)),
    ("JHN", 21, ((1, 7),)), ("JHN", 21, ((15, 17),)),
    ("MAT", 28, ((16, 20),)), ("ACT", 1, ((6, 11),)),
    ("ACT", 1, ((12, 14),)), ("ACT", 2, ((1, 6),)),
    ("LUK", 1, ((46, 55),)), ("ISA", 11, ((2, 3),)),
    ("ISA", 11, ((4, 5),)), ("ISA", 11, ((10, 10),)),
    ("ISA", 22, ((22, 22),)), ("ISA", 9, ((2, 2),)),
    ("ISA", 28, ((16, 16),)), ("ISA", 7, ((14, 14),)),
)
REVIEWED_UNITS = tuple(tuple((book, chapter, verse)
                            for start, end in spans for verse in range(start, end + 1))
                       for book, chapter, spans in _SPANS)
_REFERENCES = frozenset(ref for unit in REVIEWED_UNITS for ref in unit)

PROFILES = {
    EDITION_ID: {
        "source_types": set(), "local_rule_lines": set(), "overrides": {},
        "blocked_chapters": set(), "source_pin_digest": SOURCE_PIN_DIGEST,
        "notes": [
            "Dispatch through ReviewedArabicMapper; never a generic StepMapper.",
            "239 source verses in 72 indivisible reviewed units; no unreviewed text.",
            "Empty broad STEP selections do not authorize identity outside those units.",
            "Luke 1:32-33 and 22:43-44 retain their entire previously reviewed envelopes.",
            "Sparse inventory does not establish chapter Last or a missing verse.",
        ],
    },
}


def _order(ref: Reference) -> tuple[int, int, int]:
    return _ORDER[ref[0]], ref[1], ref[2]


def _reference(value) -> Reference:
    if (not isinstance(value, (tuple, list)) or len(value) != 3
            or value[0] not in _ORDER
            or any(type(number) is not int or number < 1 for number in value[1:])):
        raise Unavailable("Reference is outside the reviewed Arabic source")
    return tuple(value)


def _parse_unit(citation: str) -> tuple[Reference, ...]:
    match = re.fullmatch(r"(.+) ([1-9]\d*):([1-9]\d*(?:[–-][1-9]\d*)?(?:,[1-9]\d*(?:[–-][1-9]\d*)?)*)", citation)
    if not match or match[1] not in _BOOKS:
        raise ValueError("Arabic review unit requires an explicit chapter-local review")
    result = []
    for part in match[3].replace("–", "-").split(","):
        numbers = [int(number) for number in part.split("-")]
        start, end = numbers[0], numbers[-1]
        if start > end:
            raise ValueError("Reversed Arabic review unit")
        result.extend((_BOOKS[match[1]], int(match[2]), verse) for verse in range(start, end + 1))
    return tuple(result)


def reference_metadata(source_path: Path = SOURCE_PATH) -> dict:
    """Export the existing source's reference evidence, never its wording."""
    raw = source_path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != SOURCE_SHA256:
        raise ValueError("Arabic source changed; review its words and boundaries before updating the adapter")
    data = json.loads(raw)
    if (data["edition"]["id"] != EDITION_ID
            or tuple(_parse_unit(citation) for citation in data["reviewUnits"]) != REVIEWED_UNITS):
        raise ValueError("Arabic reviewed units differ from their pinned mapping")
    verses = []
    for name, chapters in data["verses"].items():
        for chapter, values in chapters.items():
            for verse, words in values.items():
                ref = (_BOOKS[name], int(chapter), int(verse))
                pages = data["pages"][name][chapter][verse]
                pages = pages if isinstance(pages, list) else [pages]
                if not isinstance(words, str) or not words.strip():
                    raise ValueError("Arabic reviewed source has unavailable words")
                verses.append({"reference": list(ref), "wordCount": len(words.split()),
                               "textSHA256": hashlib.sha256(words.encode("utf-8")).hexdigest(),
                               "pdfPages": list(pages)})
    metadata = {
        "schemaVersion": 1, "editionId": EDITION_ID,
        "sourcePins": {SOURCE_ID: SOURCE_SHA256}, "sourcePinDigest": SOURCE_PIN_DIGEST,
        "coveragePolicy": "reviewed-units", "verseCount": 239, "unitCount": 72,
        "verses": sorted(verses, key=lambda row: _order(tuple(row["reference"]))),
        "units": [{"source": [list(ref) for ref in unit], "standard": [list(ref) for ref in unit]}
                  for unit in REVIEWED_UNITS],
    }
    ReviewedArabicMapper.from_metadata(metadata)  # Check the exported contract itself.
    return metadata


@lru_cache(maxsize=1)
def _canonical_metadata() -> dict:
    return reference_metadata()


class ReviewedArabicMapper:
    """Map exact ordered units; partial requests never widen into other words."""

    def __init__(self, corpus: dict, source_pins: dict[str, str] | None = None):
        self._initialise(_canonical_metadata(), corpus)
        pins = source_pins if source_pins is not None else getattr(corpus, "source_pins", self.source_pins)
        if pins != self.source_pins:
            raise ValueError("Arabic adapter requires its reviewed, unmixed source pin")
        if (getattr(corpus, "edition_id", None) != EDITION_ID
                or tuple(getattr(corpus, "review_units", ())) != REVIEWED_UNITS):
            raise ValueError("Arabic adapter requires its matching reviewed corpus and complete unit inventory")
        actual = {(book, chapter, verse) for (book, chapter), values in corpus.items() for verse in values}
        if not actual <= _REFERENCES:
            raise ValueError("Arabic source contains references outside its reviewed inventory")

    @classmethod
    def from_metadata(cls, metadata: dict) -> ReviewedArabicMapper:
        """Load only hash-pinned reference metadata; do not open any Bible text."""
        result = cls.__new__(cls)
        result._initialise(metadata, None)
        return result

    def _initialise(self, metadata: dict, corpus: dict | None) -> None:
        pins = metadata.get("sourcePins")
        digest = hashlib.sha256(json.dumps(pins, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        if (metadata.get("schemaVersion") != 1 or metadata.get("editionId") != EDITION_ID
                or metadata.get("coveragePolicy") != "reviewed-units"
                or pins != {SOURCE_ID: SOURCE_SHA256} or digest != SOURCE_PIN_DIGEST
                or metadata.get("sourcePinDigest") != digest
                or metadata.get("verseCount") != 239 or metadata.get("unitCount") != 72):
            raise ValueError("Arabic reference metadata differs from its reviewed source pin")
        units = metadata.get("units", [])
        if (len(units) != 72
                or any(tuple(_reference(ref) for ref in row.get("source", ())) != expected
                       or tuple(_reference(ref) for ref in row.get("standard", ())) != expected
                       for row, expected in zip(units, REVIEWED_UNITS, strict=True))):
            raise ValueError("Arabic reference metadata changes an indivisible reviewed unit")
        evidence = {}
        for row in metadata.get("verses", []):
            ref = _reference(row.get("reference"))
            count, sha, pages = row.get("wordCount"), row.get("textSHA256"), row.get("pdfPages")
            if (ref in evidence or type(count) is not int or count < 1
                    or not isinstance(sha, str) or re.fullmatch(r"[0-9a-f]{64}", sha) is None
                    or not isinstance(pages, list) or not pages
                    or any(type(page) is not int or not 1 <= page <= 570 for page in pages)):
                raise ValueError("Arabic reference metadata has invalid or missing source evidence")
            evidence[ref] = (count, sha, tuple(pages))
        if set(evidence) != _REFERENCES or len(evidence) != 239:
            raise ValueError("Arabic reference metadata must retain all 239 reviewed verse records")
        self.source_pins = dict(pins)
        self.source_pin_digest = digest
        self.unit_mappings = tuple((unit, unit) for unit in REVIEWED_UNITS)
        inventory = defaultdict(set)
        for book, chapter, verse in evidence:
            inventory[book, chapter].add(verse)
        self.verse_inventory = {key: frozenset(values) for key, values in inventory.items()}
        self._evidence = evidence
        self._corpus = corpus

    def _map(self, references: Iterable[Reference], *, from_standard: bool) -> tuple[list[Reference], bool]:
        requested = tuple(_reference(ref) for ref in references)
        if (not requested or len(set(requested)) != len(requested)
                or tuple(sorted(requested, key=_order)) != requested):
            raise Unavailable("Arabic reviewed units require a nonempty, ordered, nonoverlapping request")
        reachable = {0: ()}
        for position in range(len(requested)):
            if position not in reachable:
                continue
            for source, standard in self.unit_mappings:
                wanted, target = (standard, source) if from_standard else (source, standard)
                if requested[position:position + len(wanted)] != wanted:
                    continue
                end = position + len(wanted)
                result = reachable[position] + target
                if end in reachable and reachable[end] != result:
                    raise Unavailable("Arabic request has conflicting reviewed unit mappings")
                reachable[end] = result
        result = reachable.get(len(requested))
        if result is None:
            raise Unavailable("Appointment is not a complete reviewed Arabic passage unit")
        source_refs = result if from_standard else requested
        if self._corpus is not None:
            for book, chapter, verse in source_refs:
                words = self._corpus.get((book, chapter), {}).get(verse)
                count, sha, _ = self._evidence[book, chapter, verse]
                if (not isinstance(words, str) or not words.strip()
                        or len(words.split()) != count
                        or hashlib.sha256(words.encode("utf-8")).hexdigest() != sha):
                    raise Unavailable("Reviewed Arabic source verse unavailable or changed")
        return list(result), False

    def from_standard(self, references: Iterable[Reference]) -> tuple[list[Reference], bool]:
        return self._map(references, from_standard=True)

    def to_standard(self, references: Iterable[Reference]) -> tuple[list[Reference], bool]:
        return self._map(references, from_standard=False)

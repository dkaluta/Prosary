#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Conservative, offline verse-number conversion through SIL's Original system.

Only whole verses with a unique mapping in both directions are returned. This is
not a Scripture parser and does not certify an edition's numbering: callers must
check the actual chapter's verse keys with chapter_matches before using its text.
An edition label and even matching chapter lengths are necessary evidence, not a
guarantee of textual identity. Unsupported books, segments, splits and merges are
unavailable. Same-system requests also follow this rule.

The bundled SIL tables and MIT notice are pinned in versification/sources.json.
No network or ignored source cache is needed. Run this script to check the pins.
"""
from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import re
from typing import Iterable

Reference = tuple[str, int, int]
Chapter = tuple[str, int]
SYSTEMS = ("org", "eng", "vul", "rso")
SUPPORTED_BOOKS = frozenset((
    "GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH EST JOB PSA PRO "
    "ECC SNG ISA JER LAM EZK DAN HOS JOL AMO OBA JON MIC NAM HAB ZEP HAG ZEC MAL MAT "
    "MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM HEB JAS 1PE "
    "2PE 1JN 2JN 3JN JUD REV"
).split())
TABLE_DIRECTORY = Path(__file__).resolve().parent / "versification"
_SPAN = re.compile(r"([A-Z1-9]{3})\s+(\d+):(\d+)([a-z]*)(?:-{1,2}(?:(\d+):)?(\d+)([a-z]*))?")
_CHAPTER_LINE = re.compile(r"([A-Z1-9]{3})\s+((?:\d+:\d+\s*)+)")


@dataclass
class _Table:
    maxima: dict[Chapter, int]
    explicit: dict[Reference, set[Reference]]
    blocked_source: set[Reference]
    blocked_original: set[Reference]


def _expand(match: re.Match, maxima: dict[Chapter, int]) -> list[Reference]:
    book, start_chapter, start_verse = match[1], int(match[2]), int(match[3])
    end_chapter = int(match[5]) if match[5] else start_chapter
    end_verse = int(match[6]) if match[6] else start_verse
    if (end_chapter, end_verse) < (start_chapter, start_verse):
        raise ValueError(f"Reversed versification span: {match[0]}")
    result = []
    for chapter in range(start_chapter, end_chapter + 1):
        maximum = maxima.get((book, chapter))
        # Zero is a Psalm superscription in these tables, never an emitted verse.
        start = start_verse if chapter == start_chapter else 1
        end = end_verse if chapter == end_chapter else maximum
        if maximum is None or end is None or start < 0 or end > maximum:
            raise ValueError(f"Versification span exceeds chapter: {match[0]}")
        result.extend((book, chapter, verse) for verse in range(start, end + 1))
    return result


def _maxima(text: str) -> dict[Chapter, int]:
    result = {}
    for raw_line in text.splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line or "=" in line:
            continue
        match = _CHAPTER_LINE.fullmatch(line)
        if not match:
            raise ValueError(f"Unsupported versification declaration: {line}")
        book = match[1]
        for item in match[2].split():
            chapter, maximum = map(int, item.split(":"))
            if chapter < 1 or maximum < 1 or (book, chapter) in result:
                raise ValueError(f"Invalid or duplicate versification chapter: {book} {item}")
            result[book, chapter] = maximum
    return result


def _comment_refs(text: str, maxima: dict[Chapter, int]) -> set[Reference]:
    """Whole-verse envelope of commented segment/merge notes; never infer a cut."""
    result = set()
    for match in _SPAN.finditer(text):
        if match[1] not in SUPPORTED_BOOKS:
            continue
        try:
            result.update(_expand(match, maxima))
        except ValueError:
            # A stale/irregular note is not permission to assume identity. Deny
            # every mentioned chapter when its complete span cannot be read.
            start, end = int(match[2]), int(match[5] or match[2])
            for chapter in range(min(start, end), max(start, end) + 1):
                result.update((match[1], chapter, verse)
                              for verse in range(1, maxima.get((match[1], chapter), 0) + 1))
    return result


def _parse(text: str, original_maxima: dict[Chapter, int], system: str) -> _Table:
    maxima = _maxima(text)
    explicit = defaultdict(set)
    blocked_source, blocked_original = set(), set()
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line.startswith("#"):
            # SIL records some unsupported splits only in comments (e.g.
            # English Num 26:1 and Vulgate Matt 17:14). Those are NOT identities.
            parts = re.split(r"=|<-|->", line, maxsplit=1)
            if len(parts) == 2:
                blocked_source.update(_comment_refs(parts[0], maxima))
                blocked_original.update(_comment_refs(parts[1], original_maxima))
            continue
        line = line.split("#", 1)[0].strip()
        if not line or "=" not in line:
            continue
        left, right = [side.strip() for side in line.split("=", 1)]
        lhs, rhs = _SPAN.fullmatch(left), _SPAN.fullmatch(right)
        # Mapping aliases for books outside the supported set are intentionally
        # not candidates for a reverse lookup (DAG must not shadow DAN).
        if lhs and lhs[1] not in SUPPORTED_BOOKS:
            continue
        if not lhs or not rhs:
            raise ValueError(f"Unsupported versification mapping: {line}")
        try:
            sources = _expand(lhs, maxima)
            targets = _expand(rhs, original_maxima)
        except ValueError:
            # The pinned data has a few stale active rows (for example an old
            # Jonah boundary against a newer chapter declaration). Deny their
            # affected envelopes rather than repair them or assume identity.
            blocked_source.update(_comment_refs(left, maxima))
            blocked_original.update(_comment_refs(right, original_maxima))
            continue
        if lhs[4] or lhs[7] or rhs[4] or rhs[7] or len(sources) != len(targets):
            blocked_source.update(sources)
            blocked_original.update(targets)
            # Explicitly suppress identity even when the mapping is unsupported.
            for source in sources:
                explicit[source]
            continue
        for source, target in zip(sources, targets, strict=True):
            explicit[source].add(target)
    if system == "vul":
        # SIL documents this EST table as Nova Vulgata's Greek Esther rather
        # than the Hebrew book, with unrepresented segment numbering. Chapter
        # lengths alone cannot establish the mapping of its ordinary verses.
        blocked_source.update((book, chapter, verse)
                              for (book, chapter), maximum in maxima.items()
                              if book == "EST" for verse in range(1, maximum + 1))
        blocked_original.update((book, chapter, verse)
                                for (book, chapter), maximum in original_maxima.items()
                                if book == "EST" for verse in range(1, maximum + 1))
    return _Table(maxima, dict(explicit), blocked_source, blocked_original)


class Versification:
    """Load hash-checked tables once and retain only reversible whole-verse edges."""

    def __init__(self, directory: Path = TABLE_DIRECTORY):
        manifest = json.loads((directory / "sources.json").read_text(encoding="utf-8"))
        if manifest.get("schemaVersion") != 1 or set(manifest.get("files", {})) != {
            "org.vrs.txt", "eng.vrs.txt", "vul.vrs.txt", "rso.vrs.txt", "LICENSE"
        }:
            raise ValueError("Unsupported versification source manifest")
        texts = {}
        for filename, source in manifest["files"].items():
            raw = (directory / filename).read_bytes()
            if hashlib.sha256(raw).hexdigest() != source["sha256"]:
                raise ValueError(f"Versification checksum changed: {filename}")
            texts[filename] = raw.decode("utf-8-sig")
        original_maxima = _maxima(texts["org.vrs.txt"])
        self.tables = {system: _parse(texts[f"{system}.vrs.txt"], original_maxima, system)
                       for system in SYSTEMS}
        self.to_original, self.from_original = {}, {}
        original_refs = {(book, chapter, verse)
                         for (book, chapter), maximum in original_maxima.items()
                         if book in SUPPORTED_BOOKS for verse in range(1, maximum + 1)}
        for system, table in self.tables.items():
            candidates = {}
            for (book, chapter), maximum in table.maxima.items():
                if book not in SUPPORTED_BOOKS:
                    continue
                for verse in range(1, maximum + 1):
                    source = (book, chapter, verse)
                    candidates[source] = table.explicit.get(source, {source})
            # Include explicit verse-zero edges when finding collisions, even
            # though superscriptions can never be returned as a Bible verse.
            candidates.update(table.explicit)
            inverse = defaultdict(set)
            for source, targets in candidates.items():
                for target in targets:
                    inverse[target].add(source)
            valid = {}
            for source, targets in candidates.items():
                if len(targets) != 1 or source[2] < 1 or source in table.blocked_source:
                    continue
                target = next(iter(targets))
                if (target not in original_refs or target in table.blocked_original
                        or len(inverse[target]) != 1):
                    continue
                valid[source] = target
            self.to_original[system] = valid
            self.from_original[system] = {target: source for source, target in valid.items()}

    def expected_chapter_max(self, system: str, book: str, chapter: int) -> int | None:
        if system not in self.tables or book not in SUPPORTED_BOOKS:
            return None
        return self.tables[system].maxima.get((book, chapter))

    def chapter_matches(self, system: str, book: str, chapter: int,
                        verse_numbers: Iterable[int]) -> bool:
        """Require exact, unique, contiguous integer keys, not just the maximum.

        The SIL declaration is a maximum, not a count. If an edition omits,
        splits, merges or includes a superscription at zero, this conservative
        check rejects its chapter. Never replace gaps with another edition.
        """
        maximum = self.expected_chapter_max(system, book, chapter)
        if maximum is None:
            return False
        keys = list(verse_numbers)
        return (all(type(key) is int for key in keys) and len(keys) == maximum
                and set(keys) == set(range(1, maximum + 1)))

    def map_reference(self, book: str, chapter: int, verse: int,
                      source_system: str, target_system: str) -> list[Reference] | None:
        if (source_system not in self.tables or target_system not in self.tables
                or book not in SUPPORTED_BOOKS or type(chapter) is not int
                or type(verse) is not int or chapter < 1 or verse < 1):
            return None
        original = self.to_original[source_system].get((book, chapter, verse))
        target = self.from_original[target_system].get(original)
        return [target] if target is not None else None


@lru_cache(maxsize=1)
def _default() -> Versification:
    return Versification()


def expected_chapter_max(system: str, book: str, chapter: int) -> int | None:
    return _default().expected_chapter_max(system, book, chapter)


def chapter_verse_count(book: str, chapter: int, system: str) -> int | None:
    """Compatibility name: returns SIL's maximum verse number, not edition size."""
    return expected_chapter_max(system, book, chapter)


def chapter_matches(system: str, book: str, chapter: int, verse_numbers: Iterable[int]) -> bool:
    return _default().chapter_matches(system, book, chapter, verse_numbers)


def map_reference(book: str, chapter: int, verse: int,
                  source_system: str, target_system: str) -> list[Reference] | None:
    return _default().map_reference(book, chapter, verse, source_system, target_system)


if __name__ == "__main__":
    converter = _default()
    print("Verified pinned SIL tables and MIT license; reversible verses by system:")
    for name in SYSTEMS:
        print(f"  {name}: {len(converter.to_original[name])}")

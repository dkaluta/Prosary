#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Reference-only STEP tradition crosswalks over a pinned source inventory.

The hub is STEP's English Standard, not an assertion that NABRE, SIL Original,
or every English edition shares its numbering. All emitted values are references.
Whole source verses remain indivisible; partial overlaps set the envelope flag.
"""
from __future__ import annotations

from collections import defaultdict
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import re
from typing import Iterable

Reference = tuple[str, int | str, int]
Atom = tuple[str, int | str, int, str]
DIRECTORY = Path(__file__).resolve().parent / "versification/step"
# The pinned DRA source follows these local Greek/NRSV divisions despite its
# predominantly Latin numbering: 2 Corinthians 13:12-13 and Philippians 1:16-17.
# The complete DRA inventory and published STEP predicates were checked before
# selecting these original source lines. Do not enable Greek rules globally.
DRA_LOCAL_RULE_LINES = frozenset({27448, 27449, 27450, 27451, 27455, 27456})
# STEP has no expanded rows for Sirach 33. Equal chapter maxima do not establish
# correspondence: even two 33-verse editions divide several clauses differently.
# Reviewed against every verse of the pinned engDRA source (SHA256 recorded in
# reading-text-sources.json) and https://ebible.org/eng-kjv/SIR33.htm. Each target
# is an overlap with the complete Standard KJV verse, never a new text boundary.
DRA_SIRACH_33_TARGETS = {
    1: (1,), 2: (2,), 3: (3,), 4: (4,), 5: (5,), 6: (6,), 7: (7,),
    8: (8,), 9: (8,), 10: (9, 10), 11: (11,), 12: (12,),
    13: (13,), 14: (13,), 15: (14, 15), 16: (16,), 17: (16,),
    18: (17,), 19: (18,), 20: (19,), 21: (20,), 22: (21,),
    23: (22,), 24: (22, 23), 25: (24,), 26: (25,), 27: (26,),
    28: (26, 27), 29: (27,), 30: (28, 29), 31: (30, 31),
    32: (31,), 33: (31,),
}
BOOK_ALIASES = {"ESG": "EST"}
_SINGLE = re.compile(r"(?P<book>[A-Za-z1-9]{3})\.(?P<chapter>\d+|[A-F]):(?P<verse>\d+|Title)(?P<segment>[!.*][a-z0-9]+)?", re.I)
_SPAN = re.compile(r"(?P<book>[A-Za-z1-9]{3})\.(?P<chapter>\d+|[A-F]):(?P<first>\d+)(?P<segment>[!.*][a-z0-9]+)?-(?:(?P<endchapter>\d+|[A-F]):)?(?P<last>\d+)(?P<lastsegment>[!.*][a-z0-9]+)?", re.I)


class Unavailable(ValueError):
    """The source cannot be mapped without guessing or inventing source text."""


def _book(value: str) -> str:
    value = value.upper()
    return BOOK_ALIASES.get(value, value)


def _chapter(value: str) -> int | str:
    return int(value) if value.isdecimal() else value.upper()


def _reference_order(reference: Reference) -> tuple:
    book, chapter, verse = reference
    return book, isinstance(chapter, str), chapter, verse


def reference_atoms(value: str) -> tuple[Atom, ...]:
    """Expand a numeric metadata reference; retain subverse and addition markers.

    Chapter-local rows need no corpus. Source cross-chapter summaries are expanded
    separately by StepMapper from its complete inventory. Lettered Esther chapters
    keep their labels rather than being coerced into a guessed numeric offset.
    """
    value = value.strip()
    if ";" in value or "," in value:
        result = []
        book = None
        for part in re.split(r"[;,]", value):
            part = part.strip()
            prefix = re.match(r"([A-Za-z1-9]{3})\.", part)
            if prefix:
                book = prefix[1]
            elif book is not None:
                part = f"{book}.{part}"
            result.extend(reference_atoms(part))
        return tuple(result)
    match = _SINGLE.fullmatch(value)
    if match:
        return ((_book(match["book"]), _chapter(match["chapter"]),
                 0 if match["verse"].lower() == "title" else int(match["verse"]), match["segment"] or ""),)
    match = _SPAN.fullmatch(value)
    if match and not match["segment"] and not match["lastsegment"]:
        chapter = _chapter(match["chapter"])
        if match["endchapter"] and _chapter(match["endchapter"]) != chapter:
            raise Unavailable("unreviewed STEP cross-chapter metadata range")
        first, last = int(match["first"]), int(match["last"])
        if first > last:
            raise Unavailable("reversed STEP metadata range")
        return tuple((_book(match["book"]), chapter, verse, "") for verse in range(first, last + 1))
    # An addition range belongs outside the ordinary Standard verse. It must not
    # be folded into the numbered base verse when a caller requests that verse.
    addition = re.fullmatch(r"([A-Za-z1-9]{3})\.(\d+):(\d+)\*([a-z]+)-([a-z]+)", value)
    if addition:
        return ((_book(addition[1]), int(addition[2]), int(addition[3]), "*" + addition[4] + "-" + addition[5]),)
    raise Unavailable("unreviewed STEP metadata reference")


@lru_cache(maxsize=1)
def load_rules() -> tuple[tuple, ...]:
    raw = (DIRECTORY / "rules.json").read_bytes()
    source = json.loads((DIRECTORY / "sources.json").read_text())
    if hashlib.sha256(raw).hexdigest() != source["rulesSHA256"]:
        raise ValueError("STEP reference metadata checksum differs")
    data = json.loads(raw)
    if data.get("schemaVersion") != 1 or len(data["rules"]) != source["ruleCount"]:
        raise ValueError("Unsupported STEP reference metadata")
    return tuple(tuple(row) for row in data["rules"])


def rules_for_source_type(source_type: str, *, unconditional_only: bool = False) -> tuple[tuple, ...]:
    """Expose the numeric rules without a corpus, including their source lines."""
    return tuple(row for row in load_rules() if source_type in row[1].split("+")
                 and (not unconditional_only or not row[5]))


def _default_types(edition_id: str | None) -> set[str]:
    if edition_id == "douay-rheims-1899":
        # Two tokens are misspelled in the pinned upstream table. Retain their
        # provenance verbatim while selecting their Latin-family rules.
        return {"Latin", "Latin2", "Latin2-DRA", "3Latin", "Latin=", "LatinUndivided", "GrkTitleSeparate", "GrkTitleSeparate2", "GrkTitleMerged"}
    # A language or a historical tradition does not prove that an edition uses
    # every variant in that family. Other editions retain the existing reviewed
    # mapper until their STEP selections have been independently established.
    raise ValueError("Provide an audited edition or explicit STEP source types")


class StepMapper:
    def __init__(self, corpus: dict, edition_id: str | None = None, *,
                 source_types: Iterable[str] | None = None,
                 overrides: dict[Reference, Iterable[Reference]] | None = None,
                 subverse_labels: Iterable[Atom] | None = None,
                 local_rule_lines: Iterable[int] | None = None,
                 excluded_rule_lines: Iterable[int] = (),
                 excluded_chapters: Iterable[tuple[str, int | str]] = ()):
        self.corpus = corpus
        self.excluded_chapters = frozenset(excluded_chapters)
        self.excluded_rule_lines = frozenset(excluded_rule_lines)
        self.local_rule_lines = (frozenset(local_rule_lines) if local_rule_lines is not None else
            DRA_LOCAL_RULE_LINES if edition_id == "douay-rheims-1899" and source_types is None else frozenset())
        self.source_types = set(source_types) if source_types is not None else _default_types(edition_id)
        self.source_types.add("AllBibles")
        # The audited DRA VPL import strictly accepts complete integer verse
        # labels. STEP's .1/.2 tests distinguish separately tagged subverses from
        # undivided source verses; they do not imply an extra word boundary.
        # Other source formats must supply their complete label inventory before
        # absence can be established. None means unknown, not an empty inventory.
        if subverse_labels is None and edition_id == "douay-rheims-1899":
            if any(type(verse) is not int for verses in corpus.values() for verse in verses):
                raise ValueError("The audited DRA source requires integer verse labels")
            subverse_labels = ()
        self.subverse_labels = None if subverse_labels is None else frozenset(subverse_labels)
        self.forward: dict[Reference, set[Reference]] = {}
        self.additions: set[Reference] = set()
        self.blocked_sources: set[Reference] = set()
        self.blocked_targets: set[Reference] = set()
        self.rule_lines: dict[Reference, set[int]] = defaultdict(set)
        self._build()
        if edition_id == "douay-rheims-1899" and source_types is None:
            self._dra_sirach_boundaries()
        if overrides:
            for reference, targets in overrides.items():
                if not self._exists(reference):
                    raise ValueError("STEP override source verse does not exist")
                self.forward[reference] = set(targets)
                self.blocked_sources.discard(reference)
        self._align_variable_boundaries()
        self.reverse: dict[Reference, set[Reference]] = defaultdict(set)
        for source, targets in self.forward.items():
            if source in self.blocked_sources:
                continue
            for target in targets:
                self.reverse[target].add(source)

    def _dra_sirach_boundaries(self) -> None:
        chapter = self.corpus.get(("SIR", 33))
        if chapter is None:
            return
        if set(chapter) != set(DRA_SIRACH_33_TARGETS) or any(
                not self._exists(("SIR", 33, verse)) for verse in chapter):
            self.blocked_sources.update(("SIR", 33, verse) for verse in chapter)
            self.blocked_targets.update(("SIR", 33, verse) for verse in range(1, 32))
            return
        for verse, targets in DRA_SIRACH_33_TARGETS.items():
            reference = ("SIR", 33, verse)
            self.forward[reference] = {("SIR", 33, target) for target in targets}
            self.blocked_sources.discard(reference)

    def _align_variable_boundaries(self) -> None:
        """Keep pairs whose internal divisions STEP intentionally does not map."""
        from reading_boundary_groups import alignment_groups
        by_standard: dict[Reference, set[Reference]] = defaultdict(set)
        for source, targets in self.forward.items():
            for target in targets:
                by_standard[target].add(source)
        for group in alignment_groups():
            sources = set().union(*(by_standard[target] for target in group))
            if not sources:
                continue
            if (any(not by_standard[target] for target in group)
                    or bool(sources & self.blocked_sources)
                    or bool(group & self.blocked_targets)):
                self.blocked_sources.update(sources)
                self.blocked_targets.update(group)
                continue
            for source in sources:
                self.forward[source].update(group)

    def _exists(self, reference: Reference) -> bool:
        if reference[:2] in self.excluded_chapters:
            return False
        value = self.corpus.get(reference[:2], {}).get(reference[2])
        return value is not None and (bool(value.strip()) if isinstance(value, str) else bool(value))

    def _test_atom(self, value: str) -> Atom | None:
        try:
            atoms = reference_atoms(value)
            return atoms[0] if len(atoms) == 1 else None
        except Unavailable:
            return None

    def _length(self, expression: str) -> int | None:
        total = 0
        for term in expression.split("+"):
            multiplier = 1
            scaled = re.fullmatch(r"(.+)\*(\d+)", term)
            if scaled:
                term, multiplier = scaled[1], int(scaled[2])
            atom = self._test_atom(term)
            if atom is None or atom[3] or atom[:2] in self.excluded_chapters:
                return None
            value = self.corpus.get(atom[:2], {}).get(atom[2])
            if value is None:
                return None
            # Integer values may be supplied by a reference-only inventory with
            # transiently measured word counts. STEP predicates compare words,
            # not characters. No source text is required in stored metadata.
            total += multiplier * (len(value.split()) if isinstance(value, str) else int(value))
        return total

    def _source_atoms(self, value: str) -> tuple[Atom, ...]:
        """Expand source spans only from complete, available chapter inventories."""
        match = _SPAN.fullmatch(value.strip())
        if (match and match["endchapter"] and not match["segment"]
                and not match["lastsegment"] and match["chapter"].isdecimal()
                and match["endchapter"].isdecimal()
                and int(match["endchapter"]) > int(match["chapter"])):
            book = _book(match["book"])
            first_chapter, last_chapter = int(match["chapter"]), int(match["endchapter"])
            result = []
            for chapter in range(first_chapter, last_chapter + 1):
                verses = self.corpus.get((book, chapter), {})
                positive = {verse for verse in verses if type(verse) is int and verse > 0}
                if (not positive or (book, chapter) in self.excluded_chapters
                        or positive != set(range(1, max(positive) + 1))
                        or any(not self._exists((book, chapter, verse)) for verse in positive)):
                    raise Unavailable("incomplete STEP cross-chapter source range")
                start = int(match["first"]) if chapter == first_chapter else 1
                end = int(match["last"]) if chapter == last_chapter else max(positive)
                if start > end or start not in positive or end not in positive:
                    raise Unavailable("missing STEP cross-chapter source endpoint")
                result.extend((book, chapter, verse, "") for verse in range(start, end + 1))
            return tuple(result)
        return reference_atoms(value)

    def test(self, conditions: str, *, default_book: str | None = None) -> bool | None:
        """Evaluate STEP's numeric existence/word-count predicates; never eval."""
        uncertain = False
        for raw in conditions.split("&"):
            raw = raw.strip().replace(" ", "")
            if not raw:
                continue
            # A few pinned Sirach rows abbreviate the first predicate to 33:31.
            # It inherits only the rule's explicit source book, never a guessed
            # book from neighboring rows.
            if default_book and re.match(r"(?:\d+|[A-F]):", raw):
                raw = f"{default_book}.{raw}"
            predicate = re.fullmatch(r"(.+)=(Exist|NotExist|Last)", raw)
            if predicate:
                label, kind = predicate.groups()
                if label.endswith(":TextBeforeV1"):
                    # Optional verse 0 represents canonical pre-verse title text;
                    # a verse-per-line corpus without it has no separate title.
                    atom = self._test_atom(label.replace(":TextBeforeV1", ":Title"))
                    if atom is not None and atom[:2] in self.excluded_chapters:
                        uncertain = True
                        continue
                    exists = atom is not None and self._exists(atom[:3])
                    result = exists if kind == "Exist" else not exists if kind == "NotExist" else False
                else:
                    atom = self._test_atom(label)
                    if atom is None:
                        uncertain = True
                        continue
                    if atom[:2] in self.excluded_chapters:
                        uncertain = True
                        continue
                    if atom[3]:
                        if self.subverse_labels is None:
                            uncertain = True
                            continue
                        exists = atom in self.subverse_labels
                        result = exists if kind == "Exist" else (
                            not exists and self._exists(atom[:3]) if kind == "NotExist" else False)
                        if not result:
                            return False
                        continue
                    exists = self._exists(atom[:3])
                    if kind == "Exist": result = exists
                    elif kind == "NotExist":
                        # STEP requires the previous verse to exist: a missing
                        # chapter or truncated corpus is not numbering evidence.
                        result = not exists and (atom[2] <= 1 or self._exists((atom[0], atom[1], atom[2] - 1)))
                    else:
                        keys = self.corpus.get(atom[:2], {})
                        result = exists and max(keys) == atom[2] and all(
                            self._exists((atom[0], atom[1], verse)) for verse in range(1, atom[2] + 1))
                if not result:
                    return False
                continue
            comparison = re.fullmatch(r"(.+)([<>])(.+)", raw)
            if comparison:
                left, op, right = comparison.groups()
                lhs, rhs = self._length(left), self._length(right)
                if lhs is None or rhs is None:
                    uncertain = True
                elif not (lhs < rhs if op == "<" else lhs > rhs):
                    return False
                continue
            uncertain = True
        return None if uncertain else True

    def _build(self) -> None:
        for (book, chapter), values in self.corpus.items():
            for verse in values:
                reference = (book, chapter, verse)
                if self._exists(reference): self.forward[reference] = {reference}
        active = []
        malformed = []
        for row in load_rules():
            line, kinds, source, standard, action, tests = row
            if line in self.excluded_rule_lines:
                continue
            if (not self.source_types.intersection(part.strip() for part in kinds.split("+"))
                    and line not in self.local_rule_lines):
                continue
            # IfEmpty creates an empty placeholder after renumbering. It is not
            # a claim that source text overlaps the same-number Standard verse.
            if action.startswith("IfEmpty"):
                continue
            condition = self.test(tests, default_book=source[:3])
            if condition is False:
                continue
            try:
                sources, targets = self._source_atoms(source), reference_atoms(standard)
            except Unavailable:
                malformed.append((source, standard, action))
                continue
            if condition is None:
                self.blocked_sources.update(atom[:3] for atom in sources)
                self.blocked_targets.update(atom[:3] for atom in targets)
                continue
            if not all(self._exists(atom[:3]) for atom in sources):
                # Generic Keep annotations document ordinary labels; their
                # absence cannot invalidate a specific edition's moved verse.
                # Unknown/excluded chapter evidence is still blocked above.
                if (kinds == "AllBibles" and action == "Keep verse"
                        and not any(atom[:2] in self.excluded_chapters for atom in sources)):
                    continue
                self.blocked_sources.update(atom[:3] for atom in sources)
                self.blocked_targets.update(atom[:3] for atom in targets)
                continue
            active.append((line, sources, targets, action, kinds == "AllBibles"))

        # Concatenation rows summarize the detailed segment rows. Prefer the
        # latter, retaining a summary only if it supplies otherwise missing edges.
        detailed = {atom[:3] for _, sources, _, action, generic in active
                    if not generic and not action.startswith("Concatenation") for atom in sources}
        for source, standard, action in malformed:
            try:
                sources = self._source_atoms(source)
            except Unavailable:
                sources = ()
            if action.startswith("Concatenation") and sources and all(atom[:3] in detailed for atom in sources):
                continue
            # A malformed detail is not a license to apply a guessed offset.
            # Block its directly named ordinary source/target verses.
            for label, blocked in ((source, self.blocked_sources), (standard, self.blocked_targets)):
                for book, chapter, verse in re.findall(r"([A-Za-z1-9]{3})\.(\d+):(\d+)", label):
                    blocked.add((_book(book), int(chapter), int(verse)))
        summary_details = {atom[:3] for _, sources, _, action, _ in active
                    if not action.startswith("Concatenation") for atom in sources}
        by_atom: dict[Atom, list[set[Atom]]] = defaultdict(list)
        for line, sources, targets, action, generic in active:
            if action.startswith("Concatenation") and all(atom[:3] in summary_details for atom in sources):
                continue
            for atom in sources:
                if generic and atom[:3] in detailed:
                    continue
                by_atom[atom].append(set(targets))
                self.rule_lines[atom[:3]].add(line)
        mapped: dict[Reference, set[Reference]] = defaultdict(set)
        for atom, choices in by_atom.items():
            smallest = min(choices, key=len)
            if not all(smallest <= choice for choice in choices):
                self.blocked_sources.add(atom[:3])
                self.blocked_targets.update(target[:3] for choice in choices for target in choice)
                continue
            for target in smallest:
                if target[3].startswith("*"):
                    self.additions.add(atom[:3])
                else:
                    mapped[atom[:3]].add(target[:3])
        for atom in by_atom:
            self.forward[atom[:3]] = mapped.get(atom[:3], set())

    def to_standard(self, source_refs: Iterable[Reference]) -> tuple[list[Reference], bool]:
        requested = list(dict.fromkeys(source_refs))
        result = []
        envelope = False
        for source in requested:
            if source in self.blocked_sources or not self._exists(source):
                raise Unavailable("unreviewed or missing STEP source verse")
            targets = self.forward.get(source, set())
            if not targets:
                raise Unavailable("source verse has no ordinary STEP Standard counterpart")
            result.extend(sorted(targets, key=_reference_order))
            envelope |= source in self.additions
            envelope |= any(not self.reverse[target] <= set(requested) for target in targets)
        return list(dict.fromkeys(result)), envelope

    def from_standard(self, standard_refs: Iterable[Reference]) -> tuple[list[Reference], bool]:
        requested = list(dict.fromkeys(standard_refs))
        wanted = set(requested)
        result = []
        envelope = False
        for target in requested:
            if target in self.blocked_targets:
                raise Unavailable("unreviewed STEP Standard verse")
            sources = self.reverse.get(target, set())
            if not sources:
                raise Unavailable("STEP Standard verse unavailable in source")
            for source in sorted(sources, key=_reference_order):
                result.append(source)
                envelope |= bool(self.forward[source] - wanted) or source in self.additions
        return list(dict.fromkeys(result)), envelope

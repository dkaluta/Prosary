#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""NABRE reference labels to the pinned STEP Standard reference graph.

Published chapter/verse markers and separately measured numeric word counts are
the inputs. STEP's documented structural predicates select the local numbering
tradition; the edition's language and a guessed chapter offset never select it.
The count file is pinned to the complete inventory and official source pages.
Missing measurements and conflicting correspondences are withheld. No NABRE
Scripture wording is read or retained here.

STEP TVTMS methodology lines 106-120 defines this predicate-based selection:
https://github.com/STEPBible/STEPBible-Data/tree/master/Versification
All numeric rules and the attribution/license are pinned in versification/step.
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

from nabre_versification import BOOKS, INVENTORY_PATH, NabreInventory, inventory
from reading_boundary_groups import alignment_groups
from reading_psalm_mapping import nabre_psalm_to_standard
from reading_step_mapping import Unavailable, load_rules

SourceReference = tuple[str, str, str]
StandardReference = tuple[str, int, int]
WORD_COUNTS_PATH = Path(__file__).resolve().parent / "versification/nabre/word-counts.json"
_REF = re.compile(r"([A-Za-z1-9]{3})\.([1-9][0-9]*|[A-F]):([0-9]+|Title)([!.*][a-z0-9]+)?", re.I)

@dataclass(frozen=True)
class Atom:
    book: str
    chapter: str
    verse: str
    part: str = ""

    @property
    def source(self) -> SourceReference:
        return self.book, self.chapter, self.verse

    @property
    def standard(self) -> StandardReference:
        if not self.chapter.isdigit() or self.part.startswith(("*", ".")):
            raise Unavailable("STEP addition has no ordinary whole-verse counterpart")
        return self.book, int(self.chapter), int(self.verse)


def atom(value: str) -> Atom:
    match = _REF.fullmatch(value.strip())
    if match is None:
        raise Unavailable("Unsupported STEP numeric reference")
    book, chapter, verse, part = match.groups()
    book = {"ESG": "EST"}.get(book.upper(), book.upper())
    return Atom(book, chapter.upper(), "0" if verse.lower() == "title" else verse, part or "")


def atoms(value: str) -> tuple[Atom, ...]:
    """Expand the table's numeric ranges, retaining conceptual verse parts."""
    result = []
    previous = None
    for raw in re.split(r"\s*[;,]\s*", value.strip()):
        if previous and not re.match(r"[A-Za-z1-9]{3}\.", raw):
            raw = previous.book + "." + raw
        if "-" not in raw:
            result.append(atom(raw))
            previous = result[-1]
            continue
        first, end = raw.split("-", 1)
        start = atom(first)
        match = re.fullmatch(r"(?:(\d+|[A-F]):)?(\d+)", end)
        if match is None or start.part or (match[1] and match[1] != start.chapter):
            raise Unavailable("Unsupported STEP numeric range")
        last = int(match[2])
        if int(start.verse) > last:
            raise Unavailable("Reversed STEP numeric range")
        result.extend(Atom(start.book, start.chapter, str(v)) for v in range(int(start.verse), last + 1))
        previous = result[-1]
    return tuple(result)


def load_word_counts(source: NabreInventory, path: Path = WORD_COUNTS_PATH) -> dict[SourceReference, int]:
    """Read only pinned numeric measurements for STEP's structural predicates."""
    if not path.exists():
        return {}
    data = json.loads(path.read_text())
    if (set(data) != {"schemaVersion", "edition", "method", "structureSHA256", "measurements"}
            or data["schemaVersion"] != 1 or data["edition"] != "NABRE"
            or data["method"] != "whitespace-delimited-verse-body-tokens-v1"
            or data["structureSHA256"] != hashlib.sha256(source.path.read_bytes()).hexdigest()
            or not isinstance(data["measurements"], list)):
        raise ValueError("Invalid or stale NABRE word-count metadata")
    result = {}
    for item in data["measurements"]:
        if not isinstance(item, dict) or set(item) != {"reference", "words", "sourcePages"}:
            raise ValueError("Unexpected NABRE measurement fields")
        ref = item["reference"]
        if (not isinstance(ref, list) or len(ref) != 3 or not all(isinstance(v, str) for v in ref)
                or type(item["words"]) is not int or not 1 <= item["words"] <= 10000):
            raise ValueError("Invalid NABRE word-count measurement")
        reference = tuple(ref)
        if reference in result or not source.contains(*reference):
            raise ValueError("NABRE measurement reference is duplicated or absent")
        published = source.chapter(ref[0], ref[1])["sourcePages"]
        if (not isinstance(item["sourcePages"], list) or not item["sourcePages"]
                or any(page not in published for page in item["sourcePages"])):
            raise ValueError("NABRE measurement lacks matching chapter provenance")
        result[reference] = item["words"]
    return result


class NabreMapper:
    """A source-validated, many-to-many reference graph for all 73 books.

    Having an inventory entry does not promise an exact translation match.
    ``unavailable`` identifies labels needing additional correspondence evidence.
    A successful mapping can include a wider whole-verse envelope, reported by
    the boolean result. Output text must still be checked in the target edition.
    """

    def __init__(self, source: NabreInventory | None = None, *,
                 word_counts: dict[SourceReference, int] | None = None):
        self.inventory = source or inventory()
        self.word_counts = word_counts if word_counts is not None else (
            load_word_counts(self.inventory) if self.inventory.path.resolve() == INVENTORY_PATH.resolve() else {})
        if any(not isinstance(ref, tuple) or len(ref) != 3 or
               not all(isinstance(part, str) for part in ref) or type(count) is not int or count < 1
               for ref, count in self.word_counts.items()):
            raise ValueError("Invalid numeric NABRE word-count dictionary")
        self.labels: set[SourceReference] = set()
        for book, data in self.inventory.books.items():
            for chapter, metadata in data["chapters"].items():
                self.labels.update((book, chapter, verse) for verse in metadata["verseOrder"]
                                   if verse not in metadata["duplicateVerses"])
        self.forward: dict[SourceReference, set[StandardReference]] = {}
        self.unavailable: dict[SourceReference, str] = {}
        self.evidence: dict[SourceReference, set[int]] = defaultdict(set)
        self._build()
        self.reverse: dict[StandardReference, set[SourceReference]] = defaultdict(set)
        for source, targets in self.forward.items():
            if source not in self.unavailable:
                for target in targets:
                    self.reverse[target].add(source)

    def _exists(self, value: Atom) -> bool:
        # !a is a conceptual fraction of a printed whole verse. Decimal markers
        # describe separate published additions in STEP and are not inferred
        # from the mere presence of the surrounding whole verse.
        if value.part.startswith((".", "*")):
            return False
        return value.source in self.labels

    def test(self, expression: str, default_book: str | None = None) -> bool | None:
        unknown = False
        for clause in expression.split("&"):
            clause = clause.strip().replace(" ", "")
            if not clause:
                continue
            if "<" in clause or ">" in clause:
                comparison = re.fullmatch(r"(.+)([<>])(.+)", clause)
                if comparison is None:
                    unknown = True
                    continue
                left, operator, right = comparison.groups()
                lhs, rhs = self._length(left, default_book), self._length(right, default_book)
                if lhs is None or rhs is None:
                    unknown = True
                elif not (lhs < rhs if operator == "<" else lhs > rhs):
                    return False
                continue
            match = re.fullmatch(r"(.+)=(Exist|NotExist|Last)", clause)
            if not match:
                unknown = True
                continue
            label, kind = match.groups()
            if default_book and not re.match(r"[A-Za-z1-9]{3}\.", label):
                label = default_book + "." + label
            try:
                ref = atom(label.replace(":TextBeforeV1", ":Title"))
            except Unavailable:
                unknown = True
                continue
            exists = self._exists(ref)
            try:
                chapter = self.inventory.chapter(ref.book, ref.chapter)
            except ValueError:
                # The published chapter navigation proves that a chapter label
                # is absent. STEP also tests the separate SUS/BEL books when
                # their material is integrated in Daniel; NABRE's 73-book
                # inventory establishes that those standalone books are absent.
                book = self.inventory.books.get(ref.book)
                complete_book = book is not None and ("pageOrder" not in book or
                    set(book["pageOrder"]) == set(book.get("pageSources", {})))
                absent = ref.book not in BOOKS or (complete_book and
                    ref.chapter not in book["chapterOrder"])
                if absent:
                    if kind != "NotExist":
                        return False
                    continue
                # A chapter listed in navigation but not crawled yet cannot
                # establish a NotExist condition.
                unknown = True
                continue
            if kind == "Exist":
                success = exists
            elif kind == "NotExist":
                success = not exists and (bool(ref.part) or int(ref.verse) <= 1 or
                    (ref.book, ref.chapter, str(int(ref.verse) - 1)) in self.labels)
            else:
                book = self.inventory.books[ref.book]
                if "pageOrder" in book and set(book["pageOrder"]) != set(book.get("pageSources", {})):
                    # A later source page may carry the tail of this chapter.
                    unknown = True
                    continue
                numbered = [int(v) for v in chapter["verseOrder"] if v.isdigit()]
                success = exists and not ref.part and numbered and max(numbered) == int(ref.verse)
            if not success:
                return False
        return None if unknown else True

    def _length(self, expression: str, default_book: str | None) -> int | None:
        total = 0
        for term in expression.split("+"):
            scaled = re.fullmatch(r"(.+)\*(\d+)", term)
            factor = int(scaled[2]) if scaled else 1
            label = scaled[1] if scaled else term
            if default_book and not re.match(r"[A-Za-z1-9]{3}\.", label):
                label = default_book + "." + label
            try:
                ref = atom(label)
            except Unavailable:
                return None
            if ref.part or ref.source not in self.word_counts:
                return None
            total += factor * self.word_counts[ref.source]
        return total

    def _block_named(self, label: str, reason: str) -> None:
        for match in _REF.finditer(label):
            try:
                ref = atom(match[0]).source
            except Unavailable:
                continue
            if ref in self.labels:
                self.unavailable[ref] = reason

    def _source_atoms(self, value: str) -> tuple[Atom, ...]:
        # Cross-chapter source spans use the actual published sequence. A range
        # such as 1Sa.20:42-21:1 cannot be expanded by guessing chapter maxima.
        cross = re.fullmatch(r"([A-Za-z1-9]{3})\.(\d+):(\d+)-(\d+):(\d+)", value)
        if cross and cross[2] != cross[4]:
            book, first_chapter, first_verse, last_chapter, last_verse = cross.groups()
            try:
                return tuple(Atom(*ref) for ref in self.inventory.span(
                    book.upper(), first_chapter, first_verse, last_chapter, last_verse))
            except ValueError as error:
                raise Unavailable("Unsupported STEP source range") from error
        return atoms(value)

    def _build(self) -> None:
        for source in self.labels:
            book, chapter, verse = source
            if chapter.isdigit() and verse.isdigit():
                self.forward[source] = {(book, int(chapter), int(verse))}
            else:
                self.forward[source] = set()
        active = []
        for line, types, source, standard, action, tests in load_rules():
            if source.upper().startswith("PSA.") or action.startswith("IfEmpty"):
                continue
            condition = self.test(tests, source[:3])
            if condition is False:
                continue
            try:
                sources, targets = self._source_atoms(source), atoms(standard)
            except Unavailable:
                self._block_named(source, "unsupported STEP reference relation")
                continue
            # Irrelevant rules from books or printed additions absent from this
            # inventory cannot weaken a correspondence that actually exists.
            if not any(self._exists(ref) for ref in sources):
                continue
            if condition is None:
                for ref in sources:
                    if self._exists(ref):
                        self.unavailable[ref.source] = "STEP condition needs evidence beyond verse markers"
                continue
            if not all(self._exists(ref) for ref in sources):
                for ref in sources:
                    if self._exists(ref):
                        self.unavailable[ref.source] = "STEP relation includes an absent source verse"
                continue
            active.append((line, sources, targets, action, types == "AllBibles"))
        local = {ref.source for _, sources, _, _, generic in active if not generic for ref in sources}
        active = [row for row in active if not row[4] or not any(ref.source in local for ref in row[1])]
        detailed = {ref.source for _, sources, _, action, _ in active
                    if not action.startswith("Concatenation") for ref in sources}
        choices: dict[Atom, list[set[Atom]]] = defaultdict(list)
        for line, sources, targets, action, _ in active:
            if action.startswith("Concatenation") and all(ref.source in detailed for ref in sources):
                continue
            for ref in sources:
                choices[ref].append(set(targets))
                self.evidence[ref.source].add(line)
        mapped: dict[SourceReference, set[StandardReference]] = defaultdict(set)
        for source, alternatives in choices.items():
            smallest = min(alternatives, key=len)
            if not all(smallest <= choice for choice in alternatives):
                self.unavailable[source.source] = "conflicting STEP correspondence candidates"
                continue
            try:
                mapped[source.source].update(target.standard for target in smallest)
            except Unavailable:
                self.unavailable[source.source] = "STEP correspondence includes an unnumbered addition"
        for ref in choices:
            self.forward[ref.source] = mapped.get(ref.source, set())
        self._nabre_boundaries()
        for ref in self.labels:
            if ref[0] == "PSA":
                try:
                    mapped, _ = nabre_psalm_to_standard([(ref[0], int(ref[1]), int(ref[2]))])
                    self.forward[ref] = set(mapped)
                except ValueError:
                    self.unavailable[ref] = "unreviewed NABRE Psalm marker"
            if not self.forward[ref]:
                self.unavailable.setdefault(ref, "no whole-verse STEP counterpart")
        self._align_variable_boundaries()

    def _align_variable_boundaries(self) -> None:
        by_standard: dict[StandardReference, set[SourceReference]] = defaultdict(set)
        for source, targets in self.forward.items():
            for target in targets:
                by_standard[target].add(source)
        for group in alignment_groups():
            sources = set().union(*(by_standard[target] for target in group))
            if not sources:
                continue
            if any(not by_standard[target] for target in group):
                for source in sources:
                    self.unavailable[source] = "incomplete whole-verse boundary group"
                continue
            if any(source in self.unavailable for source in sources):
                for source in sources:
                    self.unavailable[source] = "unreviewed whole-verse boundary group"
                continue
            for source in sources:
                self.forward[source].update(group)

    def _nabre_boundaries(self) -> None:
        # STEP does not include NABRE's Acts 10:48 split. The official USCCB
        # page publishes 48 and 49; the reference-only reversify source also
        # records the NAB/NABRE split from its default 10:48.
        # https://bible.usccb.org/bible/acts/10
        # https://github.com/curiousdannii/reversify/blob/master/src/transformations.data
        if ("ACT", "10", "49") in self.labels:
            for verse in ("48", "49"):
                ref = ("ACT", "10", verse)
                if ref in self.labels:
                    self.forward[ref] = {("ACT", 10, 48)}
                    self.unavailable.pop(ref, None)

        # These printed parts are rearranged within their numbered verses. The
        # official labels, compared with STEP's Standard KJV verse boundaries,
        # establish the complete envelopes; the suffix is not guessed away.
        # https://bible.usccb.org/bible/sirach/33
        # https://bible.usccb.org/bible/sirach/41
        # https://bible.usccb.org/bible/sirach/47
        # https://ebible.org/eng-kjv/SIR41.htm
        groups = [(41, ("14a", "14b"), 14), (41, ("16a", "16b"), 16),
                  (41, ("20a", "20b"), 20), (41, ("21", "21c"), 21),
                  (47, ("9", "9b"), 9), (47, ("10", "10b"), 10)]
        # The official 36:13 note explicitly explains that 14-15 are unused
        # labels: 13 and 16 form one complete bicolon, with no missing wording.
        # STEP lines 23880/23883 map its two printed halves to Standard 36:11.
        # https://bible.usccb.org/bible/sirach/36
        if self.test("Sir.36:31=Last & Sir.36:14=NotExist & Sir.36:16<Sir.36:17"):
            groups.append((36, ("13", "16"), 11))
        # STEP 24517's concatenation incorrectly includes source 44:24 while
        # requiring 44:23=Last. Its detailed 24496-24497/24518-24519 agree on
        # the two actual printed halves; retain that supported correspondence.
        # https://bible.usccb.org/bible/sirach/44
        if self.test("Sir.44:23=Last"):
            groups.append((44, ("22", "23"), 22))
        for chapter, verses, standard_verse in groups:
            sources = {("SIR", str(chapter), verse) for verse in verses}
            if sources <= self.labels:
                for ref in sources:
                    self.forward[ref] = {("SIR", chapter, standard_verse)}
                    self.unavailable.pop(ref, None)

        # STEP omits the internal Sirach 33 corrections and merges only its
        # last three source verses. The official NABRE body and the published
        # KJV chapter establish these actual Standard boundaries, including
        # the rearranged 20a/20b and the overlapping final source 31-33.
        # https://bible.usccb.org/bible/sirach/33
        # https://ebible.org/eng-kjv/SIR33.htm
        if self.test("Sir.33:33=Last"):
            reviewed = {"16": (16,), "17": (16,), "18": (17,), "19": (18,),
                        "20a": (19,), "20b": (19,), "21": (20,), "22": (21,),
                        "23": (22,), "24": (23,), "25": (24,), "26": (25,),
                        "27": (26,), "28": (27,), "29": (27,), "30": (28, 29),
                        "31": (30, 31), "32": (31,), "33": (31,)}
            for verse, targets in reviewed.items():
                ref = ("SIR", "33", verse)
                if ref in self.labels:
                    self.forward[ref] = {("SIR", 33, target) for target in targets}
                    self.unavailable.pop(ref, None)

    def to_standard(self, references: Iterable[tuple]) -> tuple[list[StandardReference], bool]:
        requested = list(dict.fromkeys((book, str(chapter), str(verse)) for book, chapter, verse in references))
        if not requested:
            raise Unavailable("Empty NABRE appointment")
        selected = set(requested)
        result = []
        envelope = False
        for ref in requested:
            if ref not in self.labels:
                raise Unavailable("NABRE verse is absent, omitted, or duplicated")
            if ref in self.unavailable:
                raise Unavailable(self.unavailable[ref])
            targets = self.forward[ref]
            result.extend(sorted(targets))
            envelope |= any(not self.reverse[target] <= selected for target in targets)
        return list(dict.fromkeys(result)), envelope

    def coverage(self) -> dict:
        """Return numeric diagnostics, keeping unsupported labels reviewable."""
        books = {}
        for book in self.inventory.books:
            labels = {ref for ref in self.labels if ref[0] == book}
            withheld = labels & self.unavailable.keys()
            books[book] = {"labels": len(labels), "mapped": len(labels - withheld),
                           "unavailable": len(withheld)}
        return {"schemaVersion": 1, "edition": "NABRE", "standard": "STEP",
                "labels": len(self.labels), "mapped": len(self.labels) - len(self.unavailable),
                "books": books, "unavailable": [
                    {"source": list(source), "reason": reason}
                    for source, reason in sorted(self.unavailable.items())]}


@lru_cache(maxsize=1)
def mapper() -> NabreMapper:
    return NabreMapper()


if __name__ == "__main__":
    result = mapper().coverage()
    print(json.dumps(result, ensure_ascii=False, indent=2))

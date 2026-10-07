#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Exact, source-pinned Martini Psalm appointments with native verse boundaries.

These selected chapter rows are daily supplements, not a book-wide numbering
profile. Every source row stays intact, including clauses shared with adjacent
Standard verses. Published Italian wording and native row labels are retained.
"""
from dataclasses import dataclass
from functools import cached_property, lru_cache
import hashlib
import json
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
REVIEW_PATH = TOOLS / "martini-daily-psalm-reviews.json"
CACHE = TOOLS / ".scripture-cache"


class Unavailable(ValueError):
    pass


@dataclass
class Passage:
    verses: list[dict]
    source: dict
    includes_whole_verses: bool


def source_specs() -> list[dict]:
    return json.loads(REVIEW_PATH.read_text(encoding="utf-8"))["sources"]


class Resolver:
    def __init__(self, review: dict, cache: Path = CACHE):
        if review.get("schemaVersion") != 1 or review.get("editionId") != "martini":
            raise ValueError("Unsupported Martini Psalm review")
        self.reviews = review["appointments"]
        self.rows = {}
        self.boundaries = {}
        self.whole_chapters = {}
        for source in review["sources"]:
            chapter = int(source["id"].removeprefix("martini-sal-"))
            if (source["id"] != f"martini-sal-{chapter}" or source["format"] != "martini"
                    or source["book"] != "PSA"
                    or source["cache"] != f"it-martini-sal-{chapter}.json"
                    or source["url"] != f"https://parolaviva.art/api/v1/bibbia/sal/{chapter}.json"):
                raise ValueError("Unexpected Martini Psalm source identity")
            raw = (cache / source["cache"]).read_bytes()
            if hashlib.sha256(raw).hexdigest() != source["sha256"]:
                raise ValueError("Martini Psalm differs from its reviewed source payload")
            data = json.loads(raw)
            if (data["c"] != chapter or data["n"] != "Salmi"
                    or [row["n"] for row in data["v"]] != list(range(1, len(data["v"]) + 1))):
                raise ValueError("Martini Psalm has incomplete native row labels")
            if [row["n"] for row in data["v"]] != review["publishedChapterLabels"][str(chapter)]:
                raise ValueError("Martini Psalm labels differ from their publication review")
            for row in data["v"]:
                if not isinstance(row["t"], str) or not row["t"].strip():
                    raise ValueError("Martini Psalm has an empty source row")
                self.rows[chapter, row["n"]] = row["t"]
            self.whole_chapters[chapter] = [(chapter, row["n"]) for row in data["v"]]
        for row in review["boundaries"]:
            coordinate = tuple(row["source"])
            targets = {tuple(target) for target in row["standard"]}
            if coordinate not in self.rows or coordinate in self.boundaries or not targets:
                raise ValueError("Martini reviewed source unit is absent or duplicated")
            if any(target[0] != "PSA" or not 1 <= target[1] <= 150 or target[2] < 0 for target in targets):
                raise ValueError("Invalid Martini Psalm target unit")
            self.boundaries[coordinate] = targets
        for key, appointment in self.reviews.items():
            native = [tuple(ref) for ref in appointment["sourceReferences"]]
            requested = {tuple(ref) for ref in appointment["standardReferences"]}
            if (not key.startswith("daily|Psalm ") or appointment["contexts"] != ["roman"]
                    or not native or native != sorted(set(native))
                    or any(ref not in self.boundaries for ref in native)
                    or not requested):
                raise ValueError("Invalid exact Martini Psalm appointment review")
            covered = set().union(*(self.boundaries[ref] for ref in native))
            if not requested <= covered:
                raise ValueError("Martini source omits an appointed Psalm clause")
            if covered - requested and not appointment["includesWholeVerses"]:
                raise ValueError("Wider Martini source rows need a whole-unit notice")

    def handles(self, key: str) -> bool:
        return key in self.reviews

    @staticmethod
    def _source() -> dict:
        return {"book": "PSA", "name": "Salmi — Bibbia Martini",
                "attribution": "Bibbia Martini (1769–1781), public domain. Native chapter data by Giovanni Novelli / Parola Viva, CC BY 4.0. Original Italian wording and verse labels retained.",
                "sourceURL": "https://parolaviva.art/opendata", "isComplete": True}

    @cached_property
    def whole_standard_groups(self) -> dict[int, frozenset]:
        from reading_calendar_numbering import standard_units
        from reading_versification import chapter_verse_count
        groups = {}
        for chapter in self.whole_chapters:
            maximum = chapter_verse_count("PSA", chapter, "vul")
            units, _ = standard_units(f"Psalm {chapter}", [(chapter, 1, chapter, maximum)],
                                      {"psalmNumbering": "vulgate-psalm-chapters"})
            groups[chapter] = frozenset(units)
        return groups

    def resolve_standard(self, references: list[tuple], includes_whole_verses: bool = False) -> Passage:
        """Caller must first establish the source calendar's Standard units.

        A complete published source chapter has no guessed internal verse cut.
        Partial requests use only the separately inspected boundary records.
        """
        wanted = {tuple(reference) for reference in references}
        if not wanted or any(book != "PSA" or chapter < 1 or verse < 1 for book, chapter, verse in wanted):
            raise Unavailable("Invalid established Martini Psalm body units")
        native = set()
        covered = set()
        for chapter, rows in self.whole_chapters.items():
            group = self.whole_standard_groups[chapter]
            if group <= wanted:
                native.update(rows)
                covered.update(group)
        remaining = wanted - covered
        for coordinate, targets in self.boundaries.items():
            if targets & remaining:
                native.add(coordinate)
                covered.update(targets)
        if not wanted <= covered:
            raise Unavailable("Martini Psalm request exceeds its independently reviewed source-verse boundaries")
        verses = [{"chapter": chapter, "verse": verse, "text": self.rows[chapter, verse]}
                  for chapter, verse in sorted(native)]
        return Passage(verses, self._source(), includes_whole_verses or bool(covered - wanted))

    def resolve(self, key: str, contexts: set[str]) -> Passage:
        review = self.reviews.get(key)
        if review is None or not contexts or not contexts <= set(review["contexts"]):
            raise Unavailable("Martini Psalm outside its exact reviewed citation/calendar")
        verses = [{"chapter": chapter, "verse": verse, "text": self.rows[chapter, verse]}
                  for chapter, verse in review["sourceReferences"]]
        return Passage(verses, self._source(), review["includesWholeVerses"])


@lru_cache(maxsize=1)
def default_resolver() -> Resolver:
    return Resolver(json.loads(REVIEW_PATH.read_text(encoding="utf-8")))

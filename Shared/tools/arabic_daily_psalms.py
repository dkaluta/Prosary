#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Bounded Roman Psalm excerpts visually reviewed against the 1897 printing.

Only the pinned exact appointments below may use these source units. Native
labels and complete printed rows remain intact; clause overlaps are explicit
and widened source envelopes carry the existing whole-verse notice.
"""
from dataclasses import dataclass
from functools import lru_cache
import hashlib
import json
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parents[1]
REVIEWS = TOOLS / "arabic-daily-psalm-reviews.json"


class Unavailable(ValueError):
    pass


@dataclass(frozen=True)
class Passage:
    verses: list[dict]
    source: dict
    includes_whole_verses: bool


class Resolver:
    def __init__(self, review: dict, root: Path = ROOT):
        if review.get("schemaVersion") != 1 or review.get("editionId") != "jesuit-arabic-1897":
            raise ValueError("Unsupported Arabic Psalm review")
        self.rows = {}
        self.pages = {}
        self.notes = {}
        for source in review["sources"]:
            path = (root / source["path"]).resolve()
            if not path.is_relative_to((root / "Shared/content").resolve()):
                raise ValueError("Arabic reviewed source must be canonical content")
            raw = path.read_bytes()
            if hashlib.sha256(raw).hexdigest() != source["sha256"]:
                raise ValueError("Arabic source wording changed after its scan review")
            data = json.loads(raw)
            if (data["editionId"] != "jesuit-arabic-1897"
                    or data["sourcePDFSHA256"] != "2bca3535b75532044bdc2889b497b16b59e0337ee775f42de8aedc4e2809c09d"):
                raise ValueError("Arabic review belongs to another printing")
            for chapter, verses in data["verses"]["Psalm"].items():
                for verse, text in verses.items():
                    reference = int(chapter), int(verse)
                    pages = data["pages"]["Psalm"][chapter][verse]
                    pages = pages if isinstance(pages, list) else [pages]
                    if (reference in self.rows or any(type(n) is not int or n < 1 for n in reference)
                            or not isinstance(text, str) or not text.strip() or not pages
                            or any(type(p) is not int or not 1 <= p <= 570 for p in pages)):
                        raise ValueError("Arabic source has repeated or unreviewed printed rows")
                    self.rows[reference] = text
                    self.pages[reference] = pages
            for note in data.get("editorialNotes", []):
                reference = tuple(note["reference"])
                if reference not in self.rows or not isinstance(note["text"], str) or not note["text"].strip():
                    raise ValueError("Arabic editorial note lacks its printed source row")
                self.notes[reference] = note["text"]
        self.units = []
        for unit in review["units"]:
            native = tuple(tuple(ref) for ref in unit["source"])
            standard = frozenset(tuple(ref) for ref in unit["standard"])
            if (not native or len(set(native)) != len(native)
                    or any(ref not in self.rows for ref in native) or not standard
                    or any(len(ref) != 3 or ref[0] != "PSA" or type(ref[1]) is not int
                           or not 1 <= ref[1] <= 150 or type(ref[2]) is not int or ref[2] < 0
                           for ref in standard)):
                raise ValueError("Arabic source unit lacks an explicit valid clause boundary")
            self.units.append((native, standard))
        self.companions = {}
        for group in review.get("requiredSourceReferences", []):
            standard = tuple(group["standard"])
            required = frozenset(tuple(ref) for ref in group["source"])
            known = {ref for refs, targets in self.units if standard in targets for ref in refs}
            if not required or not required <= known or standard in self.companions:
                raise ValueError("Arabic clause overlap lacks its required printed neighboring unit")
            self.companions[standard] = required
        self.reviews = review["appointments"]
        for key, appointment in self.reviews.items():
            native = [tuple(ref) for ref in appointment["sourceReferences"]]
            wanted = {tuple(ref) for ref in appointment["standardReferences"]}
            if (not key.startswith("daily|Psalm ") or appointment["contexts"] != ["roman"]
                    or not native or native != sorted(set(native)) or not wanted
                    or any(ref not in self.rows for ref in native)):
                raise ValueError("Invalid exact Arabic Psalm appointment")
            chosen = [(refs, targets) for refs, targets in self.units if wanted & targets]
            covered = set().union(*(targets for _, targets in chosen)) if chosen else set()
            expected = sorted({ref for refs, _ in chosen for ref in refs})
            if not wanted <= covered or native != expected:
                raise ValueError("Arabic Psalm selection omits a reviewed source clause")
            if any(not self.companions.get(ref, frozenset()) <= set(native) for ref in wanted):
                raise ValueError("Arabic Psalm selection omits a required neighboring source clause")
            if covered - wanted and not appointment["includesWholeVerses"]:
                raise ValueError("Wider Arabic source units require a visible notice")

    def handles(self, key: str) -> bool:
        return key in self.reviews

    def resolve(self, key: str, contexts: set[str]) -> Passage:
        appointment = self.reviews.get(key)
        if appointment is None or not contexts or not contexts <= set(appointment["contexts"]):
            raise Unavailable("Arabic Psalm outside its exact reviewed calendar and citation")
        return self._passage(appointment["sourceReferences"], appointment["includesWholeVerses"])

    def resolve_standard(self, references, *, includes_whole_verses: bool = False) -> Passage:
        """A verified calendar profile may use independently reviewed source-unit facts.

        This accepts Standard coordinates only, never a raw calendar citation or
        an inferred Psalm number. Unreviewed source words remain unavailable.
        """
        wanted = {tuple(ref) for ref in references}
        if (not wanted or any(len(ref) != 3 or ref[0] != "PSA" or type(ref[1]) is not int
                or not 1 <= ref[1] <= 150 or type(ref[2]) is not int or ref[2] < 0 for ref in wanted)):
            raise Unavailable("Invalid reviewed Arabic Psalm Standard coordinates")
        chosen = [(refs, targets) for refs, targets in self.units if wanted & targets]
        covered = set().union(*(targets for _, targets in chosen)) if chosen else set()
        if not wanted <= covered:
            raise Unavailable("Arabic Psalm includes source words outside the scan review")
        native = sorted({ref for refs, _ in chosen for ref in refs})
        if any(not self.companions.get(ref, frozenset()) <= set(native) for ref in wanted):
            raise Unavailable("Arabic Psalm lacks a required neighboring source clause")
        return self._passage(native, includes_whole_verses or bool(covered - wanted))

    def _passage(self, references, includes_whole_verses: bool) -> Passage:
        verses = [{"chapter": chapter, "verse": verse, "text": self.rows[chapter, verse]}
                  for chapter, verse in references]
        notes = [self.notes[tuple(ref)] for ref in references if tuple(ref) in self.notes]
        source = {"book": "PSA", "name": "المزامير — الكتاب المقدس، بيروت 1897",
                  "attribution": "Old Jesuit Arabic translation, Jesuit Press, Beirut, 1897. Public-domain printed text, independently transcribed and visually checked against the original scan; native wording and verse labels retained.",
                  "sourceURL": "https://archive.org/details/AlKitabAlMoqadas", "isComplete": True}
        if notes:
            source["attribution"] += " " + " ".join(notes)
            source["sourceURL"] = "https://sites.dlib.nyu.edu/viewer/books/princeton_aco001445/243"
        return Passage(verses, source, includes_whole_verses)


@lru_cache(maxsize=1)
def default_resolver() -> Resolver:
    return Resolver(json.loads(REVIEWS.read_text(encoding="utf-8")))

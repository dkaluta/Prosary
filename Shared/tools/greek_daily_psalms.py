#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Bounded Greek daily Psalm excerpts from the unchanged pinned Brenton VPL.

The ordinary complete-chapter importer keeps withholding lettered and incomplete
layouts. This supplement approves nine exact Roman appointments and four separately
reviewed whole-source body groups. Neither approval creates partial offset rules.
Lettered 144:13a remains a separate printed source witness when requested.
No words are translated, fused, renumbered, or inferred from verse counts.
"""
from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import re
import zipfile

from brenton_reading_source import SOURCE_SHA256

REVIEWS = Path(__file__).with_name("greek-daily-psalm-reviews.json")
BODY_DIGEST_METHOD = "ordered-source-chapter-label-text-json-v1"
# Independently reviewed whole bodies, not counts or a Septuagint-wide offset.
WHOLE_STANDARD_GROUPS = {
    12: tuple(("PSA", 13, verse) for verse in range(1, 7)),
    114: tuple(("PSA", 116, verse) for verse in range(1, 10)),
    115: tuple(("PSA", 116, verse) for verse in range(10, 20)),
    144: tuple(("PSA", 145, verse) for verse in range(1, 22)),
}


class Unavailable(ValueError):
    pass


@dataclass(frozen=True)
class Passage:
    verses: list[dict]
    source: dict
    includes_whole_verses: bool


def load_reviews(path: Path = REVIEWS) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if (data.get("schemaVersion") != 1 or data.get("editionId") != "brenton-lxx"
            or data.get("sourceId") != "grcbrent" or data.get("sourceSHA256") != SOURCE_SHA256
            or not isinstance(data.get("appointments"), dict)):
        raise ValueError("Greek Psalm review differs from its pinned source")
    for key, review in data["appointments"].items():
        labels = review.get("sourceLabels", [])
        if (not key.startswith("daily|Psalm ") or review.get("contexts") != ["roman"]
                or type(review.get("sourceChapter")) is not int or review["sourceChapter"] < 1
                or type(review.get("includesWholeVerses")) is not bool
                or type(review.get("isComplete")) is not bool
                or not isinstance(labels, list) or not labels or len(labels) != len(set(labels))
                or any(not isinstance(label, str) or not re.fullmatch(r"[1-9]\d*a?", label) for label in labels)
                or labels != sorted(labels, key=lambda label: (int(label.rstrip("a")), label.endswith("a")))
                or not isinstance(review.get("boundaryReview"), str) or not review["boundaryReview"].strip()
                or not isinstance(review.get("evidenceURLs"), list) or not review["evidenceURLs"]
                or any(not url.startswith("https://") for url in review["evidenceURLs"])):
            raise ValueError(f"Invalid bounded Greek Psalm review: {key}")
        for label in labels:
            if label.endswith("a") and label[:-1] not in labels:
                raise ValueError("A printed Greek suffix requires its existing primary source verse")
    return data["appointments"]


def load_whole_reviews(path: Path = REVIEWS) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if (data.get("schemaVersion") != 1 or data.get("editionId") != "brenton-lxx"
            or data.get("sourceId") != "grcbrent" or data.get("sourceSHA256") != SOURCE_SHA256
            or data.get("wholePsalmBodyDigestMethod") != BODY_DIGEST_METHOD
            or not isinstance(data.get("wholePsalmGroups"), dict)
            or set(data["wholePsalmGroups"]) != {str(chapter) for chapter in WHOLE_STANDARD_GROUPS}):
        raise ValueError("Greek whole-Psalm review differs from its pinned source scope")
    return {int(chapter): review for chapter, review in data["wholePsalmGroups"].items()}


def source_body_digest(rows: dict, chapter: int, labels: list[str]) -> str:
    body = [[chapter, label, rows[chapter, label]] for label in labels]
    raw = json.dumps(body, ensure_ascii=False, separators=(",", ":")) + "\n"
    return hashlib.sha256(raw.encode()).hexdigest()


def source_rows(raw: bytes, *, expected_sha256: str = SOURCE_SHA256) -> dict[tuple[int, str], str]:
    if hashlib.sha256(raw).hexdigest() != expected_sha256:
        raise ValueError("Greek Psalm source changed; review words and printed labels again")
    rows = {}
    for line in raw.decode("utf-8-sig").splitlines():
        if not line.startswith("PSA "):
            continue
        match = re.fullmatch(r"PSA ([1-9]\d*):([1-9]\d*[a-z]*) (.+)", line)
        if not match or not match[3].strip():
            raise ValueError("Malformed Greek Psalm source unit")
        coordinate = int(match[1]), match[2]
        if coordinate in rows:
            raise ValueError("Duplicated Greek Psalm source unit")
        rows[coordinate] = match[3]
    return rows


class Resolver:
    def __init__(self, raw: bytes, reviews: dict, *, expected_sha256: str = SOURCE_SHA256,
                 whole_reviews: dict | None = None):
        self.rows = source_rows(raw, expected_sha256=expected_sha256)
        self.reviews = reviews
        for review in reviews.values():
            if any((review["sourceChapter"], label) not in self.rows for label in review["sourceLabels"]):
                raise ValueError("Reviewed Greek Psalm unit is absent from the pinned source")
        self.whole_reviews = dict(whole_reviews or {})
        self.whole_chapters = {}
        self.whole_standard_groups = {}
        for chapter, review in self.whole_reviews.items():
            labels = review.get("sourceLabels", [])
            standard = review.get("standardReferences", [])
            if (type(chapter) is not int or chapter not in WHOLE_STANDARD_GROUPS
                    or type(review.get("sourceChapter")) is not int or review["sourceChapter"] != chapter
                    or review.get("isComplete") is not True
                    or type(review.get("includesWholeVerses")) is not bool
                    or review["includesWholeVerses"] != (chapter in {12, 144})
                    or not isinstance(standard, list)
                    or any(not isinstance(ref, list) or len(ref) != 3 or ref[0] != "PSA"
                           or type(ref[1]) is not int or type(ref[2]) is not int for ref in standard)
                    or standard != [list(ref) for ref in WHOLE_STANDARD_GROUPS[chapter]]
                    or not isinstance(labels, list) or not labels or len(labels) != len(set(labels))
                    or any(not isinstance(label, str) or not re.fullmatch(r"[1-9]\d*a?", label) for label in labels)
                    or labels != sorted(labels, key=lambda label: (int(label.rstrip("a")), label.endswith("a")))
                    or set(labels) != {label for source_chapter, label in self.rows if source_chapter == chapter}
                    or review.get("sourceURL") != f"https://ebible.org/grcbrent/PSA{chapter:03d}.htm"
                    or not isinstance(review.get("publishedSourceSHA256"), str)
                    or not re.fullmatch(r"[0-9a-f]{64}", review.get("publishedSourceSHA256", ""))
                    or not isinstance(review.get("boundaryReview"), str) or not review["boundaryReview"].strip()
                    or not isinstance(review.get("evidenceURLs"), list) or review["sourceURL"] not in review["evidenceURLs"]
                    or any(not isinstance(url, str) or not url.startswith("https://") for url in review["evidenceURLs"])):
                raise ValueError("Invalid complete Greek Psalm body review")
            if any(label.endswith("a") and label[:-1] not in labels for label in labels):
                raise ValueError("A whole Greek Psalm witness requires its printed primary verse")
            if source_body_digest(self.rows, chapter, labels) != review.get("sourceBodySHA256"):
                raise ValueError("Complete Greek Psalm body differs from its reviewed source digest")
            self.whole_chapters[chapter] = tuple((chapter, label) for label in labels)
            self.whole_standard_groups[chapter] = frozenset(WHOLE_STANDARD_GROUPS[chapter])

    def handles(self, key: str) -> bool:
        return key in self.reviews

    def resolve(self, key: str, contexts: set[str]) -> Passage:
        review = self.reviews.get(key)
        if review is None or not contexts or not contexts <= set(review["contexts"]):
            raise Unavailable("Greek Psalm outside its exact reviewed appointment/calendar")
        chapter = review["sourceChapter"]
        return self._passage([(chapter, label) for label in review["sourceLabels"]],
                             review["isComplete"], review["includesWholeVerses"],
                             f"https://ebible.org/grcbrent/PSA{chapter:03d}.htm",
                             "Exact reviewed daily excerpt; original printed source labels retained.")

    def resolve_standard(self, references, *, includes_whole_verses: bool = False) -> Passage:
        """Resolve only unions of completely requested reviewed source body groups.

        The caller establishes its calendar's Standard units first. Partial groups,
        title slots and unrelated chapters remain unavailable through this API.
        """
        try:
            requested = [tuple(ref) for ref in references]
        except TypeError as error:
            raise Unavailable("Invalid Greek whole-Psalm Standard coordinates") from error
        if (not requested or type(includes_whole_verses) is not bool
                or any(len(ref) != 3 or ref[0] != "PSA" or type(ref[1]) is not int
                       or type(ref[2]) is not int or ref[1] < 1 or ref[2] < 1 for ref in requested)):
            raise Unavailable("Invalid Greek whole-Psalm Standard coordinates")
        wanted = set(requested)
        selected = sorted(chapter for chapter, group in self.whole_standard_groups.items() if group <= wanted)
        covered = set().union(*(self.whole_standard_groups[chapter] for chapter in selected)) if selected else set()
        if covered != wanted:
            raise Unavailable("Greek Psalm request is outside the reviewed complete source body groups")
        native = [ref for chapter in selected for ref in self.whole_chapters[chapter]]
        wider = includes_whole_verses or any(self.whole_reviews[chapter]["includesWholeVerses"] for chapter in selected)
        return self._passage(native, True, wider, self.whole_reviews[selected[0]]["sourceURL"],
                             "Complete reviewed source Psalm bodies; original printed source labels retained.")

    def _passage(self, references, is_complete, includes_whole_verses, source_url, attribution_detail):
        verses, blocks = [], []
        for chapter, label in references:
            text = self.rows[chapter, label]
            block_id = f"grcbrent-psa-{chapter}-{label}"
            if label.endswith("a"):
                blocks.append({"id": block_id, "kind": "witness", "text": text,
                               "printedLabel": label,
                               "addresses": [{"chapter": chapter, "verse": int(label[:-1]), "part": "a"}]})
            else:
                verse = int(label)
                verses.append({"chapter": chapter, "verse": verse, "text": text})
                blocks.append({"id": block_id, "kind": "verse", "chapter": chapter, "verse": verse})
        source = {"book": "PSA", "name": "Brenton Septuagint — Psalms",
                  "attribution": "Greek Septuagint, compiled by Sir Lancelot C. L. Brenton. Public domain; eBible.org grcbrent. " + attribution_detail,
                  "sourceURL": source_url, "isComplete": is_complete, "contentBlocks": blocks}
        return Passage(verses, source, includes_whole_verses)


@lru_cache(maxsize=1)
def default_resolver() -> Resolver:
    tools = REVIEWS.parent
    lock = json.loads((tools / "reading-text-sources.json").read_text(encoding="utf-8"))
    source = next(row for row in lock["sources"] if row["id"] == "grcbrent")
    if (source["sha256"] != SOURCE_SHA256 or source["format"] != "brenton-vplzip"
            or source["member"] != "grcbrent_vpl.txt"):
        raise ValueError("Greek Psalm source lock changed; renew its exact review")
    cache = tools / ".scripture-cache"
    path = cache / source["cache"]
    if not path.resolve().is_relative_to(cache.resolve()):
        raise ValueError("Greek source cache escapes its folder")
    with zipfile.ZipFile(path) as archive:
        raw = archive.read(source["member"])
    return Resolver(raw, load_reviews(), whole_reviews=load_whole_reviews())

#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Exact reviewed Hebrew daily excerpts, separate from the base Bible mapper.

No number-equality fallback, inferred source boundaries, or scripture slicing.
Review selections are whole source units in the appointment's reviewed order.
"""
from __future__ import annotations

import copy
from dataclasses import dataclass
from functools import lru_cache
import hashlib
import json
from pathlib import Path, PurePosixPath
import re

from hebrew_deuterocanon import BOOKS, digest, load_books
from bible_source_structure import published_blocks
from scripture_source_notes import validate_source_notes

ROOT = Path(__file__).resolve().parents[2]
REVIEWS = Path(__file__).with_name("hebrew-daily-reading-reviews.json")
CALENDARS = {"roman", "roman1962", "ugcc", "ugcc-gregorian", "syriac", "maronite"}
EDITION = "masoretic-delitzsch"
HASH = re.compile(r"[0-9a-f]{64}")


class Unavailable(ValueError):
    """A citation has no approved, currently pinned Hebrew supplement excerpt."""


def require(value, message):
    if not value:
        raise ValueError(message)


def nonempty(value):
    return isinstance(value, str) and bool(value.strip())


def positive(value):
    return type(value) is int and value > 0


def fields(value, required, optional=()):
    require(isinstance(value, dict) and set(required) <= value.keys() <= set(required) | set(optional),
            "Hebrew daily review has missing or unknown fields")


def validate_evidence(review, key, root):
    require(isinstance(review["evidence"], list) and review["evidence"], f"No Hebrew review evidence: {key}")
    for evidence in review["evidence"]:
        fields(evidence, ("path", "sha256"))
        require(nonempty(evidence["path"]), f"Invalid Hebrew evidence path: {key}")
        relative = PurePosixPath(evidence["path"])
        require(not relative.is_absolute() and ".." not in relative.parts and
                isinstance(evidence["sha256"], str) and HASH.fullmatch(evidence["sha256"]),
                f"Invalid Hebrew evidence reference: {key}")
        path = Path(root) / relative
        require(path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == evidence["sha256"],
                f"Hebrew boundary evidence changed: {key}")


def load_reviews(path=REVIEWS, *, root=ROOT):
    data = json.loads(Path(path).read_text())
    fields(data, ("schemaVersion", "appointments"))
    require(type(data["schemaVersion"]) is int and data["schemaVersion"] == 1 and isinstance(data["appointments"], dict),
            "Invalid Hebrew daily review manifest")
    for key, review in data["appointments"].items():
        require(isinstance(review, dict), "Hebrew daily review must be an object")
        require(isinstance(key, str) and key.startswith("daily|") and key.removeprefix("daily|").strip(),
                "Hebrew reviews require an exact daily citation")
        base = {"status", "contexts"}
        if review.get("status") == "pending":
            fields(review, base, ("notes",))
        elif review.get("status") == "unavailable":
            fields(review, base | {"sourceBook", "sourceContentSHA256", "reason", "method", "evidence"})
            require(review["sourceBook"] in BOOKS and
                    isinstance(review["sourceContentSHA256"], str) and HASH.fullmatch(review["sourceContentSHA256"]),
                    f"Invalid Hebrew unavailable-source pin: {key}")
            require(nonempty(review["reason"]) and nonempty(review["method"]),
                    f"Missing reviewed Hebrew unavailability reason: {key}")
            validate_evidence(review, key, root)
        else:
            fields(review, base | {"sourceBook", "sourceContentSHA256", "selections", "includesWholeVerses",
                "openingText", "closingText", "method", "evidence", "excludedSourceBlocks"})
            require(review["status"] == "complete" and review["sourceBook"] in BOOKS,
                    f"Invalid Hebrew review status or source book: {key}")
            require(isinstance(review["sourceContentSHA256"], str) and HASH.fullmatch(review["sourceContentSHA256"]),
                    f"Invalid Hebrew source pin: {key}")
            require(type(review["includesWholeVerses"]) is bool and
                    all(nonempty(review[name]) for name in ("openingText", "closingText", "method")),
                    f"Missing Hebrew boundary evidence: {key}")
            selections = review["selections"]
            require(isinstance(selections, list) and selections, f"No Hebrew source units: {key}")
            for selection in selections:
                if isinstance(selection, dict) and "blockId" in selection:
                    fields(selection, ("blockId",))
                    require(nonempty(selection["blockId"]), f"Invalid Hebrew block selection: {key}")
                else:
                    fields(selection, ("chapter", "verse"))
                    require(positive(selection["chapter"]) and positive(selection["verse"]),
                            f"Invalid Hebrew primary selection: {key}")
            require(isinstance(review["excludedSourceBlocks"], list), f"Invalid Hebrew block exclusions: {key}")
            exclusions = set()
            for exclusion in review["excludedSourceBlocks"]:
                fields(exclusion, ("blockId", "reason"))
                require(nonempty(exclusion["blockId"]) and nonempty(exclusion["reason"])
                        and exclusion["blockId"] not in exclusions, f"Invalid Hebrew block exclusion: {key}")
                exclusions.add(exclusion["blockId"])
            validate_evidence(review, key, root)
        contexts = review["contexts"]
        require(isinstance(contexts, list) and contexts and all(isinstance(c, str) for c in contexts)
                and len(contexts) == len(set(contexts)) and set(contexts) <= CALENDARS,
                f"Invalid Hebrew calendar scope: {key}")
    return data["appointments"]


@dataclass
class Passage:
    verses: list[dict]
    source: dict
    includes_whole_verses: bool


class Resolver:
    def __init__(self, books, reviews):
        # Production passes only load_books()' all-twelve-or-none result.
        self.books = {book["book"]: book for book in books}
        self.reviews = reviews

    def handles(self, key, citation_book):
        return key in self.reviews or citation_book in BOOKS

    def resolve(self, key, contexts, preserve_text=lambda value: value):
        review = self.reviews.get(key)
        if review is None or review["status"] == "pending":
            raise Unavailable("Hebrew source boundaries have not been reviewed for this citation")
        if not contexts or not contexts <= set(review["contexts"]):
            raise Unavailable("calendar context outside reviewed Hebrew source boundaries")
        if not self.books:
            raise Unavailable("Hebrew supplement source review is not complete")
        require(review["sourceBook"] in self.books, "Reviewed Hebrew source book is unavailable")
        book = self.books[review["sourceBook"]]
        require(book["review"]["status"] == "complete" and digest(book) == review["sourceContentSHA256"],
                "Hebrew source changed; review daily boundaries again")
        if review["status"] == "unavailable":
            raise Unavailable("Hebrew source does not cover the reviewed appointment: " + review["reason"])
        chapters = {chapter["number"]: chapter for chapter in book["chapters"]}
        primary = {(chapter["number"], row["verse"]): row
                   for chapter in book["chapters"] for row in chapter["verses"]}
        physical = []
        for chapter in book["chapters"]:
            blocks = chapter.get("contentBlocks")
            if blocks is None:
                blocks = [{"id": f"daily-{book['book'].lower()}-{chapter['number']}-{row['verse']}",
                           "kind": "verse", "chapter": chapter["number"], "verse": row["verse"]}
                          for row in chapter["verses"]]
            physical.extend((chapter["number"], block) for block in blocks)
        by_id, by_address = {}, {}
        for position, (chapter, block) in enumerate(physical):
            require(block["id"] not in by_id, "Duplicate Hebrew presentation identity")
            by_id[block["id"]] = position
            if block["kind"] == "verse":
                address = block["chapter"], block["verse"]
                require(address not in by_address, "Repeated Hebrew primary presentation")
                by_address[address] = position
        positions, rows, blocks, texts, selected_chapters = [], [], [], [], set()
        for selection in review["selections"]:
            if "blockId" in selection:
                require(selection["blockId"] in by_id, "Missing reviewed Hebrew source block")
                position = by_id[selection["blockId"]]
                chapter, original = physical[position]
                require(original["kind"] in {"witness", "passage"},
                        "Daily block selections require scripture, not headings or colophons")
                block = published_blocks([original])[0]
                block["text"] = preserve_text(block["text"])
                texts.append(block["text"])
                selected_chapters.add(chapter)
            else:
                address = selection["chapter"], selection["verse"]
                require(address in by_address, "Selection is not a whole Hebrew source unit start")
                position = by_address[address]
                original = primary[address]
                row = {"chapter": address[0], "verse": address[1], "text": preserve_text(original["text"])}
                for field in ("endVerse", "sourceNotes"):
                    if field in original:
                        row[field] = copy.deepcopy(original[field])
                rows.append(row)
                block = copy.deepcopy(physical[position][1])
                texts.append(row["text"])
                selected_chapters.add(address[0])
            require(position not in positions, "Repeated Hebrew source unit in daily excerpt")
            positions.append(position)
            blocks.append(block)
        # A review may deliberately reorder separated passages. Preserve its sequence.
        # Within ascending adjacent selections, make omitted self-contained scripture explicit.
        skipped = {block["id"] for left, right in zip(positions, positions[1:]) if left < right
                   for _, block in physical[left + 1:right] if block["kind"] in {"witness", "passage"}}
        selected_ids = {block["id"] for block in blocks}
        skipped -= selected_ids
        excluded = {entry["blockId"] for entry in review["excludedSourceBlocks"]}
        require(skipped == excluded and not excluded.intersection(selected_ids),
                "Skipped Hebrew scripture blocks require exact reviewed exclusions")
        require(rows, "Block-only daily excerpts need a reader contract without primary verses")
        require(texts[0].startswith(preserve_text(review["openingText"])) and
                texts[-1].endswith(preserve_text(review["closingText"])),
                "Hebrew reviewed opening or closing no longer matches its source units")
        note_ids = set()
        for item in [*rows, *(block for block in blocks if "text" in block)]:
            ids = validate_source_notes(item, label=f"Hebrew daily {key}")
            require(not note_ids.intersection(ids), "Duplicate source note in Hebrew daily excerpt")
            note_ids.update(ids)
        source = {"book": book["book"], "name": book["title"], "attribution": book["attribution"],
                  "sourceURL": book["sourceURL"], "isComplete": all(chapters[c].get("isComplete", True)
                                                                      for c in selected_chapters),
                  "contentBlocks": blocks}
        return Passage(rows, source, review["includesWholeVerses"] or any("endVerse" in row for row in rows))


@lru_cache(maxsize=1)
def default_resolver():
    books, _ = load_books()
    return Resolver(books, load_reviews())

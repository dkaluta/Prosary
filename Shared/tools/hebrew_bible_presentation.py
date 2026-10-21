#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Apply reviewed Catholic reading sequences without changing Hebrew source units.

The approved source books retain their physical order. Only the optional Bible
download uses this projection; daily appointments keep their independent reviews.
"""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path

from bible_source_structure import ABSENT, require, validate_structure
from hebrew_deuterocanon import digest

REVIEW_PATH = Path(__file__).with_name("hebrew-bible-presentation-reviews.json")


def _replace_sequence(items, before, after, key, label):
    require(before and len(before) == len(set(before)) and
            len(after) == len(set(after)) and set(before) == set(after),
            f"{label}: reading order must preserve each complete source unit")
    keys = [key(item) for item in items]
    matches = [index for index in range(len(keys) - len(before) + 1)
               if keys[index:index + len(before)] == before]
    require(len(matches) == 1, f"{label}: reviewed source order changed")
    start = matches[0]
    selected = dict(zip(before, items[start:start + len(before)], strict=True))
    items[start:start + len(before)] = [selected[value] for value in after]


def _pin_units(chapters, pins, label):
    require(isinstance(pins, list) and pins, f"{label}: missing source unit pins")
    seen = set()
    for pin in pins:
        require(set(pin) == {"chapter", "verse", "endVerse", "textSHA256"},
                f"{label}: invalid source unit pin")
        address = pin["chapter"], pin["verse"]
        require(address not in seen and address[0] in chapters, f"{label}: duplicate or missing source unit")
        seen.add(address)
        rows = [row for row in chapters[address[0]]["verses"] if row["verse"] == address[1]]
        require(len(rows) == 1 and rows[0].get("endVerse") == pin["endVerse"] and
                hashlib.sha256(rows[0]["text"].encode()).hexdigest() == pin["textSHA256"],
                f"{label}: reviewed source unit changed")
    return seen


def _inventory(book):
    primary = {(chapter["number"], row["verse"]): row
               for chapter in book["chapters"] for row in chapter["verses"]}
    blocks = {block["id"]: block for chapter in book["chapters"]
              for block in chapter.get("contentBlocks", [])}
    return primary, blocks


def aligned_book(book, reviews=None):
    """Return a checked copy; absence of a review leaves the source unchanged."""
    if reviews is None:
        reviews = json.loads(REVIEW_PATH.read_text())
    require(reviews.get("schemaVersion") == 1 and reviews.get("target") == "NABRE" and
            isinstance(reviews.get("books"), dict), "Invalid Hebrew Bible presentation review")
    review = reviews["books"].get(book["book"])
    if review is None:
        return book
    code = book["book"]
    require(digest(book) == review["sourceContentSHA256"],
            f"{code}: source changed; review Catholic presentation again")
    projected = copy.deepcopy(book)
    chapters = {chapter["number"]: chapter for chapter in projected["chapters"]}
    for change in review["reorderings"]:
        label = f"{code} {change['id']}"
        chapter = change["chapter"]
        require(chapter in chapters, f"{label}: missing source chapter")
        pins = _pin_units(chapters, change["units"], label)
        require(pins == {(chapter, verse) for verse in change["sourceVerses"]},
                f"{label}: each reordered source unit requires an exact pin")
        _replace_sequence(chapters[chapter]["verses"], change["sourceVerses"],
                          change["readingVerses"], lambda row: row["verse"], label)
        if "contentBlocks" in chapters[chapter]:
            _replace_sequence(chapters[chapter]["contentBlocks"], change["sourceVerses"],
                              change["readingVerses"],
                              lambda block: block["verse"] if block["kind"] == "verse" and
                              block["chapter"] == chapter else None, label)
    for change in review["chapterReturns"]:
        label = f"{code} {change['id']}"
        chapter, verse, previous = change["chapter"], change["verse"], change["afterVerse"]
        source = change["fromChapter"]
        require(chapter != source and chapter in chapters and source in chapters,
                f"{label}: invalid reviewed chapter return")
        pins = _pin_units(chapters, change["units"], label)
        require(pins == {(chapter, verse), (chapter, previous),
                         (source, change["sourcePreviousVerse"]), (source, change["sourceNextVerse"])},
                f"{label}: chapter return boundaries require exact pins")
        source_blocks = chapters[source].get("contentBlocks", [])
        target_blocks = chapters[chapter].get("contentBlocks", [])
        matches = [index for index, block in enumerate(source_blocks)
                   if block["kind"] == "verse" and (block["chapter"], block["verse"]) == (chapter, verse)]
        require(len(matches) == 1, f"{label}: missing moved source presentation")
        index = matches[0]
        require(0 < index < len(source_blocks) - 1, f"{label}: changed source boundaries")
        for block, expected in ((source_blocks[index - 1], change["sourcePreviousVerse"]),
                                (source_blocks[index + 1], change["sourceNextVerse"])):
            require(block["kind"] == "verse" and (block["chapter"], block["verse"]) == (source, expected),
                    f"{label}: changed source boundaries")
        require(target_blocks and target_blocks[-1]["kind"] == "verse" and
                (target_blocks[-1]["chapter"], target_blocks[-1]["verse"]) == (chapter, previous),
                f"{label}: changed destination boundary")
        block = source_blocks.pop(index)
        target_blocks.append(block)
        route = {"chapter": chapter, "verse": verse, "displayChapter": source, "blockId": block["id"]}
        require(projected.get("addressRoutes", []).count(route) == 1,
                f"{label}: missing reviewed source route")
        projected["addressRoutes"].remove(route)
        if not projected["addressRoutes"]:
            del projected["addressRoutes"]
    require(_inventory(projected) == _inventory(book), f"{code}: Catholic presentation changed source units")
    validate_structure(projected["chapters"], routes=projected.get("addressRoutes", ABSENT),
                       authoring=True, page_count=projected["scan"]["pageCount"], label=code)
    return projected

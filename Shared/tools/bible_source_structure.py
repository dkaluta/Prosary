#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Validate physical source order independently of primary numeric Bible addresses."""
from __future__ import annotations

from collections import Counter
import hashlib
import re

from scripture_source_notes import validate_source_notes

ABSENT = object()


def require(value, message):
    if not value:
        raise ValueError(message)


def positive(value):
    return type(value) is int and 1 <= value <= 1000


def text(value):
    return isinstance(value, str) and bool(value.strip())


def shape(value, required, optional=(), *, label):
    require(isinstance(value, dict), f"{label}: expected object")
    require(set(required) <= value.keys() <= set(required) | set(optional),
            f"{label}: missing or unknown fields")


def validate_structure(chapters, *, routes=ABSENT, authoring=False, page_count=None,
                       allow_empty_pages=False, archive_version=None, paired=False,
                       label="Bible book"):
    """Return ordered block/route evidence after validating the complete book.

    Caller separately validates ordinary primary verse payloads and archive metadata.
    This function resolves all references and accounts for every physical presentation,
    including the implicit references in chapters without an explicit block list.
    """
    require(isinstance(chapters, list) and chapters, f"{label}: missing chapters")
    require(archive_version is None or type(archive_version) is int and archive_version in (1, 2, 3),
            f"{label}: unknown archive version")
    require(not (archive_version == 3 and paired), f"{label}: paired-script version 3 is unsupported")
    by_chapter = {}
    primary = {}
    notes = []
    for chapter in chapters:
        number = chapter.get("number", chapter.get("chapter"))
        require(positive(number) and number not in by_chapter, f"{label}: invalid chapter")
        by_chapter[number] = chapter
        require(isinstance(chapter.get("verses"), list) and chapter["verses"],
                f"{label} {number}: missing primary verses")
        for row in chapter["verses"]:
            key = number, row.get("verse")
            require(positive(key[1]) and key not in primary, f"{label}: duplicate primary address")
            primary[key] = row
            notes.extend(n["id"] for n in row.get("sourceNotes", []))
    has_blocks = any("contentBlocks" in chapter for chapter in chapters)
    has_routes = routes is not ABSENT
    if has_blocks or has_routes:
        require(not paired, f"{label}: paired-script source blocks are unsupported")
        require(archive_version in (None, 3), f"{label}: source structure requires archive version 3")
    if has_routes:
        require(isinstance(routes, list) and routes, f"{label}: empty or null address routes")
    routes = routes if has_routes else []
    actual_routes, block_inventory, used_pages = [], [], set()
    occurrences = Counter()
    ids = set()
    for number, chapter in by_chapter.items():
        if "contentBlocks" not in chapter:
            occurrences.update((number, row["verse"]) for row in chapter["verses"])
            continue
        blocks = chapter["contentBlocks"]
        require(isinstance(blocks, list) and blocks, f"{label} {number}: empty content blocks")
        ordered_ids = []
        for block in blocks:
            require(isinstance(block, dict), f"{label}: invalid source block")
            identity, kind = block.get("id"), block.get("kind")
            require(isinstance(identity, str) and re.fullmatch(r"[a-z0-9][a-z0-9-]*", identity)
                    and identity not in ids, f"{label}: invalid or duplicate block ID")
            ids.add(identity)
            ordered_ids.append(identity)
            context = f"{label} {identity}"
            if kind == "verse":
                shape(block, ("id", "kind", "chapter", "verse"), ("printedLabel",), label=context)
                require(positive(block["chapter"]) and positive(block["verse"]), f"{context}: invalid reference")
                key = block["chapter"], block["verse"]
                require(key in primary, f"{context}: dangling primary reference")
                if "printedLabel" in block:
                    require(text(block["printedLabel"]), f"{context}: empty printed label")
                occurrences[key] += 1
                if key[0] != number:
                    actual_routes.append({"chapter": key[0], "verse": key[1],
                                          "displayChapter": number, "blockId": identity})
                continue
            require(isinstance(kind, str) and kind in {"witness", "passage", "heading", "colophon"}, f"{context}: unknown block kind")
            required = {"id", "kind", "text"}
            optional = set()
            if kind == "witness":
                required |= {"addresses", "printedLabel"}
                optional.add("sourceNotes")
            elif kind in {"passage", "colophon"}:
                optional.add("sourceNotes")
            if authoring:
                required |= {"sourcePages", "textSHA256"}
            shape(block, required, optional, label=context)
            require(text(block["text"]), f"{context}: empty block text")
            pages = None
            if authoring:
                require(type(page_count) is int and page_count > 0, f"{label}: invalid scan page count")
                require(hashlib.sha256(block["text"].encode()).hexdigest() == block["textSHA256"],
                        f"{context}: source text hash mismatch")
                pages = block["sourcePages"]
                require(isinstance(pages, list) and (pages or allow_empty_pages), f"{context}: missing source pages")
                require(all(type(p) is int and 1 <= p <= page_count for p in pages)
                        and pages == sorted(set(pages)), f"{context}: invalid source pages")
                pages = set(pages)
                used_pages |= pages
            notes.extend(validate_source_notes(block, label=context, source_pages=pages))
            if kind == "witness":
                require(text(block["printedLabel"]), f"{context}: empty printed label")
                addresses = block["addresses"]
                require(isinstance(addresses, list) and addresses, f"{context}: missing witness addresses")
                seen_addresses = set()
                for address in addresses:
                    shape(address, ("chapter", "verse"), ("endVerse", "part"), label=context)
                    first, last = address["verse"], address.get("endVerse", address["verse"])
                    require(positive(address["chapter"]) and address["chapter"] in by_chapter
                            and positive(first) and positive(last) and first <= last,
                            f"{context}: invalid witness address")
                    if "part" in address:
                        require(text(address["part"]), f"{context}: empty source part")
                    key = (address["chapter"], first, last, address.get("part"))
                    require(key not in seen_addresses, f"{context}: duplicate witness address")
                    seen_addresses.add(key)
        block_inventory.append({"number": number, "ids": ordered_ids})
    require(set(occurrences) == set(primary) and all(n == 1 for n in occurrences.values()),
            f"{label}: primary units must each have exactly one presentation")
    require(len(notes) == len(set(notes)), f"{label}: duplicate source-note ID across source units")
    supplied_routes = {}
    for route in routes:
        shape(route, ("chapter", "verse", "displayChapter", "blockId"), label=f"{label} route")
        require(all(positive(route[k]) for k in ("chapter", "verse", "displayChapter"))
                and text(route["blockId"]), f"{label}: invalid address route")
        key = route["chapter"], route["verse"]
        require(key not in supplied_routes, f"{label}: duplicate address route")
        supplied_routes[key] = route
    require(supplied_routes == {(r["chapter"], r["verse"]): r for r in actual_routes},
            f"{label}: address routes do not match actual primary presentations")
    return {"contentBlocks": block_inventory, "addressRoutes": routes,
            "sourcePages": used_pages, "sourceNoteIds": sorted(notes)}


def published_blocks(blocks):
    """Strip review-only evidence without discarding a single source presentation."""
    return [{key: value for key, value in block.items() if key not in {"sourcePages", "textSHA256"}}
            for block in blocks]

#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Pinned Greek Brenton Septuagint, with unsupported source layouts withheld.

eBible.org/grcbrent identifies this OT-only source as public domain. Its VPL
contains lettered verse labels and books outside the native citation contract.
Never discard a suffix and call the remaining chapter complete. Entire chapters
containing lettered labels or gaps are unavailable; so are the combined Ezra
chapters 11–23 (Nehemiah), Greek additions, and Sirach 33's unreviewed boundaries.
The original source bytes remain untouched in the ignored source cache.
"""
from collections import defaultdict
import hashlib
import re

SOURCE_SHA256 = "dcd97e62bab7ff629dd6c5201d1b7ff6237254c665a79535f622e31e72fc4b50"
BOOK_ALIASES = {"SOL": "SNG", "EZE": "EZK", "JOE": "JOL", "NAH": "NAM"}
SOURCE_BOOKS = frozenset("GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR JOB PSA PRO ECC SOL ISA JER LAM EZE HOS JOE AMO OBA JON MIC NAH HAB ZEP HAG ZEC MAL TOB JDT ESG WIS SIR BAR EPJ SUS BEL 1MA 2MA 1ES PRM 3MA 4MA DNG".split())
UNSUPPORTED_BOOKS = frozenset("ESG EPJ SUS BEL 1ES PRM 3MA 4MA DNG".split())


def parse_source(raw: bytes) -> tuple[dict, set]:
    chapters = defaultdict(dict)
    excluded = set()
    seen = set()
    for line in raw.decode("utf-8-sig").splitlines():
        match = re.fullmatch(r"(\S+) ([1-9]\d*):([1-9]\d*)([a-z]*) (.+)", line)
        if not match or match[1] not in SOURCE_BOOKS:
            raise ValueError("Unsupported Brenton source label or book")
        source_book, chapter, verse, suffix, text = match.groups()
        book = BOOK_ALIASES.get(source_book, source_book)
        chapter, verse = int(chapter), int(verse)
        reference = book, chapter, verse, suffix
        if reference in seen or not text.strip():
            raise ValueError("Duplicated or empty Brenton source verse")
        seen.add(reference)
        if (suffix or source_book in UNSUPPORTED_BOOKS or book == "EZR" and chapter > 10
                or (book, chapter) == ("SIR", 33)):
            excluded.add((book, chapter))
        if not suffix:
            chapters[book, chapter][verse] = text
    for key, verses in chapters.items():
        if set(verses) != set(range(1, max(verses) + 1)):
            excluded.add(key)
    return {key: verses for key, verses in chapters.items() if key not in excluded}, excluded


def load_verses(raw: bytes) -> dict:
    if hashlib.sha256(raw).hexdigest() != SOURCE_SHA256:
        raise ValueError("Brenton source changed; review labels and boundaries before importing")
    chapters, excluded = parse_source(raw)
    if (len(chapters), sum(map(len, chapters.values())), len(excluded)) != (908, 22377, 195):
        raise ValueError("Brenton import no longer matches its reviewed source inventory")
    return chapters

#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Import O Antiphon passages from the app's hash-pinned Hebrew/Russian/Tagalog editions.

Uses the existing Bible source lock and parsers. Only the eight Scripture fields are
generated; the independently sourced antiphons and their titles remain untouched.
Run --fetch if the ignored source cache is empty, or --check for a read-only check.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import re

TOOLS = Path(__file__).resolve().parent
CONTENT = TOOLS.parent / "content/oAntiphons/content"
spec = importlib.util.spec_from_file_location("readings_builder", TOOLS / "build-reading-texts.py")
readings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(readings)

PASSAGES = {
    "magnificatBody": ("LUK", 1, 46, 55),
    "oSapientiaLectio": ("ISA", 11, 2, 3),
    "oAdonaiLectio": ("ISA", 11, 4, 5),
    "oRadixIesseLectio": ("ISA", 11, 10, 10),
    "oClavisDavidLectio": ("ISA", 22, 22, 22),
    "oOriensLectio": ("ISA", 9, 2, 2),
    "oRexGentiumLectio": ("ISA", 28, 16, 16),
    "oEmmanuelLectio": ("ISA", 7, 14, 14),
}
EDITIONS = {
    "he": {
        "sources": {"ISA": "hbo", "LUK": "delitzsch-1901-LUK-1"},
        "books": {"ISA": "ישעיהו", "LUK": "לוקס"},
        "editions": {"ISA": "נוסח המסורה", "LUK": "דליטש, 1901"},
    },
    "ru": {
        "sources": {"ISA": "russyn", "LUK": "russyn"},
        "books": {"ISA": "Исаия", "LUK": "Лука"},
        "editions": {"ISA": "Синодальный перевод, 1876", "LUK": "Синодальный перевод, 1876"},
    },
    "tl": {
        "sources": {"ISA": "TagAngBiblia", "LUK": "TagAngBiblia"},
        "books": {"ISA": "Isaias", "LUK": "Lucas"},
        "editions": {"ISA": "Ang Dating Biblia, 1905", "LUK": "Ang Dating Biblia, 1905"},
    },
}


def source_span(language: str, key: str) -> tuple[str, int, int, int]:
    # Hebrew Isaiah 9:1 is the same passage as Vulgate 9:2. Keep the source's
    # numbering in the citation instead of attaching a Latin label to Hebrew text.
    if language == "he" and key == "oOriensLectio":
        return "ISA", 9, 1, 1
    return PASSAGES[key]


def hebrew_chapter(number: int) -> str:
    # These appointed passages use only chapters 1, 7, 9, 11, 22 and 28.
    return {1: "א׳", 7: "ז׳", 9: "ט׳", 11: "י״א", 22: "כ״ב", 28: "כ״ח"}[number]


def render(language: str, existing: dict, *, fetch: bool = False) -> dict:
    edition = EDITIONS[language]
    lock = json.loads(readings.LOCK.read_text())
    sources = {item["id"]: item for item in lock["sources"]}
    loaded = {}
    for source_id in set(edition["sources"].values()):
        source = sources[source_id]
        if fetch:
            readings.source_bytes(source, fetch=True)
        loaded[source_id] = readings.load_source(source)
    result = json.loads(json.dumps(existing))
    prayers = result.setdefault("prayers", {})
    for key in PASSAGES:
        book, chapter, start, end = source_span(language, key)
        rows = loaded[edition["sources"][book]][book, chapter]
        verses = [rows[number] for number in range(start, end + 1)]
        if not all(verse.strip() for verse in verses):
            raise ValueError(f"Empty source verse for {language}:{key}")
        body = " ".join(verses)
        reference = str(start) if start == end else f"{start}–{end}"
        if language == "he":
            # The rest of the source pointing and cantillation is preserved.
            marks = r"[\u0591-\u05bd\u05bf\u05c1\u05c2\u05c4\u05c5\u05c7]*"
            body = re.sub(f"י{marks}ה{marks}ו{marks}ה{marks}", "יהוה", body)
            reference = f"{hebrew_chapter(chapter)} {reference}"
        else:
            reference = f"{chapter}:{reference}"
        prayers[key] = f"{body}\n\n— {edition['books'][book]} {reference} ({edition['editions'][book]})"
    result["$scriptureSource"] = (
        "Imported by Shared/tools/import-o-antiphon-scripture.py from the app's existing "
        "hash-pinned public-domain editions in reading-text-sources.json. Source wording and "
        "numbering are retained; Hebrew Isaiah 9:1 corresponds to Vulgate 9:2. "
        "Hebrew Divine Name marks are removed in accordance with the app's typography rule. "
        "Antiphon prayer texts have separate provenance."
    )
    result["$scriptureImport"] = {
        "prayerKeys": sorted(PASSAGES), "mysteryKeys": [],
        "sources": [{key: sources[source_id][key] for key in ("id", "url", "sha256", "license")}
                    for source_id in sorted(loaded)],
    }
    result.setdefault("mysteries", {})
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--fetch", action="store_true")
    args = parser.parse_args()
    outdated = []
    for language in EDITIONS:
        target = CONTENT / f"{language}.json"
        existing = json.loads(target.read_text()) if target.exists() else {}
        output = json.dumps(render(language, existing, fetch=args.fetch), ensure_ascii=False, indent=2) + "\n"
        if target.exists() and target.read_text() == output:
            continue
        if args.check:
            outdated.append(str(target))
        else:
            target.write_text(output)
            print(f"oAntiphons [{language}]: 8 sourced passages")
    if outdated:
        raise SystemExit("Out of date: " + ", ".join(outdated))


if __name__ == "__main__":
    main()

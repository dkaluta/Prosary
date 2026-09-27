#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Build optional, content-addressed Bible downloads from the pinned imports.

No appointment-number conversion occurs here: chapter files retain their edition's
own labels. Known source defects and unreviewed sparse material stay unavailable.
Run --sync to copy only the small catalog into native apps; archives live once in
Shared/dist/bibles and are downloaded explicitly. --check leaves outputs unchanged;
--fetch can populate the ignored, hash-checked source cache on a clean checkout.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import zipfile

from hebrew_deuterocanon import load_books as load_hebrew_supplement

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "Shared/tools"
DATA = ROOT / "Shared/data"
DIST = ROOT / "Shared/dist/bibles"
TARGETS = [ROOT / "iOS/Prosary/Data", ROOT / "Android/app/src/main/assets/data",
           ROOT / "Windows/Prosary/Data"]
DOWNLOAD_ROOT = "https://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/"
MAX_ARCHIVE = 32 * 1024 * 1024
MAX_UNPACKED = 128 * 1024 * 1024
MAX_CHAPTER = 2 * 1024 * 1024


def encode(value):
    return (json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n").encode()


def reading_builder():
    spec = importlib.util.spec_from_file_location("bible_reading_builder", TOOLS / "build-reading-texts.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def book_names(edition, codes):
    """Use source-index names where available, otherwise credited localized metadata."""
    source = json.loads((TOOLS / "bible-book-names.json").read_text())["editions"]
    hebrew = json.loads((TOOLS / "hebrew-reading-books.json").read_text())["books"]
    localized = json.loads((TOOLS / "reading-books-localized.json").read_text())["books"]
    builder = reading_builder()
    english = dict(zip(builder.CODES, builder.NAMES, strict=True))
    result = {}
    for code in codes:
        if code in source.get(edition["id"], {}):
            result[code] = source[edition["id"]][code]
        elif edition["languageCode"] == "he":
            result[code] = {"name": hebrew[english[code]]["full"]}
        elif edition["languageCode"] in {"ar", "ru", "tl", "fr", "it", "uk"}:
            result[code] = {"name": localized[english[code]][edition["languageCode"]]["full"]}
        else:
            raise ValueError(f"Missing source-language title for {edition['id']} {code}")
    return result


def chapter_rows(builder, edition, corpus):
    """Yield only safe source-native chapter contents with honest completeness."""
    from reading_edition_mapping import profile_for
    from peshitta_reading_source import paired_text
    mapper = builder.edition_mapper(edition["id"], corpus)
    profile = profile_for(edition["id"])
    allowed = profile.get("reviewed_source_references", frozenset())
    gated_books = profile.get("review_required_books", frozenset())
    for (book, chapter), original in sorted(corpus.items()):
        if (book, chapter) in mapper.excluded_chapters:
            continue
        sparse = edition.get("coveragePolicy") == "reviewed-units" or book in gated_books
        values = {verse: text for verse, text in original.items()
                  if book not in gated_books or (book, chapter, verse) in allowed}
        if not values:
            continue
        rows = []
        for verse, text in sorted(values.items()):
            if type(verse) is not int or verse < 1 or not isinstance(text, str) or not text.strip():
                raise ValueError(f"Invalid Bible source row: {edition['id']} {book} {chapter}:{verse}")
            if edition["languageCode"] == "he":
                text = builder.preserve_divine_name_accents(text)
            row = {"chapter": chapter, "verse": verse, "text": text}
            if edition.get("textScript"):
                row["text"], row["transliteratedText"] = paired_text(text)
            rows.append(row)
        # Sparse Arabic imports have no independently complete chapter inventory.
        # Peshitta's complete source chapter is still partial if any row is gated out.
        complete = (not sparse or book in gated_books and values == original)
        complete = complete and set(values) == set(range(1, max(values) + 1))
        yield book, chapter, rows, complete


def make_archive(edition, chapters, names):
    files = {}
    books = defaultdict(list)
    for book, chapter, verses, complete in chapters:
        data = encode({"schemaVersion": 1, "editionId": edition["id"], "book": book,
                       "chapter": chapter, "verses": verses})
        if len(data) > MAX_CHAPTER:
            raise ValueError("Bible chapter exceeds the native resource limit")
        files[f"chapters/{book}/{chapter}.json"] = data
        books[book].append({"number": chapter, "verseCount": len(verses), "isComplete": complete})
    builder = reading_builder()
    order = builder.CODES[:39] + builder.CODES[66:] + ["LJE", "ESG", "S3Y", "SUS", "BEL"] + builder.CODES[39:66]
    book_rows = [{"id": book, **names[book], "chapters": books[book]}
                 for book in order if book in books]
    if len(book_rows) != len(books) or not files:
        raise ValueError("Unknown or empty Bible book inventory")
    # Bind both the metadata and every chapter to the revision, without a hash cycle.
    digest = hashlib.sha256(encode({"edition": edition, "books": book_rows}))
    for path, data in sorted(files.items()):
        digest.update(path.encode() + b"\0" + data)
    revision = digest.hexdigest()
    files["manifest.json"] = encode({"schemaVersion": 1, "editionId": edition["id"],
                                      "revision": revision, "books": book_rows})
    unpacked = sum(map(len, files.values()))
    if unpacked > MAX_UNPACKED:
        raise ValueError("Bible archive exceeds the expanded resource limit")
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path, data in sorted(files.items()):
            info = zipfile.ZipInfo(path, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data, compresslevel=9)
    raw = output.getvalue()
    if len(raw) > MAX_ARCHIVE:
        raise ValueError("Bible archive exceeds the download resource limit")
    filename = f"{edition['id']}-{revision}.zip"
    metadata_keys = ("id", "languageCode", "name", "attribution", "sourceURL",
                     "textScript", "transliteratedTextScript")
    entry = {key: edition[key] for key in metadata_keys if key in edition}
    entry.update(revision=revision, downloadURL=DOWNLOAD_ROOT + filename,
                 archiveSHA256=hashlib.sha256(raw).hexdigest(), archiveByteCount=len(raw),
                 unpackedByteCount=unpacked, books=book_rows)
    return filename, raw, entry


def build(*, require_hebrew_supplement=False, fetch=False):
    builder = reading_builder()
    lock, corpora = builder.load_pinned_corpora(fetch=fetch)
    supplement, _ = load_hebrew_supplement(require_complete=require_hebrew_supplement)
    archives, editions = {}, []
    coverage = {}
    for edition in lock["editions"]:
        chapters = list(chapter_rows(builder, edition, corpora[edition["id"]]))
        names = book_names(edition, {row[0] for row in chapters})
        if edition["id"] == "masoretic-delitzsch":
            for book in supplement:
                if book["book"] in names:
                    raise ValueError("A Hebrew supplement cannot replace an existing Bible book")
                metadata = {"name": book["title"], "attribution": book["attribution"],
                            "sourceURL": book["sourceURL"]}
                if "introduction" in book:
                    metadata["introduction"] = builder.preserve_divine_name_accents(book["introduction"])
                names[book["book"]] = metadata
                for chapter in book["chapters"]:
                    verses = [{"chapter": chapter["number"], "verse": row["verse"],
                               **({"endVerse": row["endVerse"]} if "endVerse" in row else {}),
                               "text": builder.preserve_divine_name_accents(row["text"])}
                              for row in chapter["verses"]]
                    chapters.append((book["book"], chapter["number"], verses, chapter.get("isComplete", True)))
        filename, raw, entry = make_archive(edition, chapters, names)
        archives[filename] = raw
        editions.append(entry)
        coverage[edition["id"]] = {"books": len(entry["books"]), "chapters": len(chapters),
            "partialChapters": sum(not row[3] for row in chapters),
            "verses": sum(len(row[2]) for row in chapters), "archiveBytes": len(raw)}
    return encode({"schemaVersion": 1, "editions": editions}), archives, coverage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sync", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--fetch", action="store_true", help="Fetch missing hash-pinned source files")
    parser.add_argument("--require-hebrew-supplement", action="store_true",
                        help="Require all Hebrew additions to have completed source review before release")
    args = parser.parse_args()
    catalog, archives, coverage = build(require_hebrew_supplement=args.require_hebrew_supplement,
                                      fetch=args.fetch)
    outputs = {DATA / "bible-catalog.json": catalog,
               ROOT / "Shared/reports/bible-library-coverage.json": encode(coverage)}
    outputs.update({DIST / filename: raw for filename, raw in archives.items()})
    if args.sync or args.check:
        outputs.update({directory / "bible-catalog.json": catalog for directory in TARGETS})
    for path, data in outputs.items():
        if args.check:
            if not path.exists() or path.read_bytes() != data:
                raise SystemExit(f"Stale Bible artifact: {path.relative_to(ROOT)}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    print(json.dumps(coverage, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

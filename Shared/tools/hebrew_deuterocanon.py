#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Keep Hebrew source drafts separate from completed, independently inventoried books.

This validates review evidence; it cannot perform or certify the human/image review.
OCR alignments and Wikisource matches are never accepted as completion evidence.
Run --require-complete before generating a release with the Hebrew supplement.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from urllib.parse import urlsplit

from scripture_source_notes import validate_source_notes
from bible_source_structure import ABSENT, validate_structure

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "Shared/content"
BOOKS = ("TOB", "JDT", "WIS", "SIR", "BAR", "1MA", "2MA", "LJE", "ESG", "S3Y", "SUS", "BEL")
INVENTORY_PATH = CONTENT / "hebrew-deuterocanon-review.json"


def digest(value: dict) -> str:
    """Pin exact text, source order, metadata and page evidence, excluding review notes."""
    payload = {key: item for key, item in value.items() if key != "review"}
    raw = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(raw).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def positive(value) -> bool:
    return type(value) is int and value > 0


def nonempty(value) -> bool:
    return isinstance(value, str) and bool(value.strip())


def page_list(pages, total: int, label: str, *, allow_empty=False) -> set[int]:
    require(isinstance(pages, list) and (pages or allow_empty), f"{label}: missing source pages")
    require(all(positive(p) and p <= total for p in pages), f"{label}: invalid source page")
    require(pages == sorted(set(pages)), f"{label}: pages must be unique and ordered")
    return set(pages)


def validate_book(book: dict, catalog: dict, approval: dict | None = None) -> dict:
    code = book.get("book")
    require(code in BOOKS and book.get("schemaVersion") == 1, "Unknown Hebrew book or schema")
    work_code = "DAG" if code in {"S3Y", "SUS", "BEL"} else code
    works = [row for row in catalog["works"] if row.get("scriptureBook") == work_code]
    require(len(works) == 1, f"{code}: missing unique contributor record")
    work = works[0]
    require(book.get("translator") == work["translatorCredit"], f"{code}: wrong translator credit")
    require(book.get("collectionEditor") == catalog["collectionEditor"], f"{code}: wrong editor credit")
    for key in ("title", "attribution", "sourceURL"):
        require(nonempty(book.get(key)), f"{code}: missing {key}")
    url = urlsplit(book["sourceURL"])
    require(url.scheme == "https" and bool(url.netloc), f"{code}: source URL must be HTTPS")
    scan = book.get("scan", {})
    scans = [row for row in catalog["referenceScans"] if row["volume"] == work["referenceVolume"]]
    require(len(scans) == 1, f"{code}: missing reference scan")
    for key in ("volume", "sha256", "pageCount"):
        require(scan.get(key) == scans[0][key], f"{code}: mismatched scan {key}")
    total = scan["pageCount"]
    review = book.get("review", {})
    require(review.get("status") in {"draft", "complete"}, f"{code}: invalid review status")
    complete = review["status"] == "complete"
    require(nonempty(review.get("method")), f"{code}: missing review method")
    reviewed = page_list(review.get("reviewedPages"), total, f"{code} reviewed", allow_empty=True)
    used_pages = set()
    if "introduction" in book:
        text = book["introduction"]
        require(nonempty(text), f"{code}: empty scriptural opening")
        require(hashlib.sha256(text.encode()).hexdigest() == book.get("introductionTextSHA256"),
                f"{code}: scriptural opening hash mismatch")
        used_pages |= page_list(book.get("introductionSourcePages"), total, f"{code} introduction")
    else:
        require(not ({"introductionSourcePages", "introductionTextSHA256"} & book.keys()),
                f"{code}: opening evidence without text")
    chapters = book.get("chapters")
    require(isinstance(chapters, list) and bool(chapters), f"{code}: no chapters")
    numbers, units, label_inventory, source_note_ids = [], 0, [], []
    for chapter in chapters:
        number = chapter.get("number")
        require(positive(number) and number not in numbers, f"{code}: duplicate/invalid chapter")
        numbers.append(number)
        require(type(chapter.get("isComplete", True)) is bool, f"{code} {number}: invalid completeness")
        verses = chapter.get("verses")
        require(isinstance(verses, list) and bool(verses), f"{code} {number}: no text units")
        labels, ranges = set(), []
        for row in verses:
            require("printedLabel" not in row, f"{code} {number}: printed labels belong on presentation references")
            first, last = row.get("verse"), row.get("endVerse", row.get("verse"))
            require(positive(first) and positive(last) and first <= last <= 1000,
                    f"{code} {number}: invalid verse range")
            covered = set(range(first, last + 1))
            require(not labels & covered, f"{code} {number}:{first}: overlapping verse range")
            labels |= covered
            ranges.append([first, last])
            text = row.get("text")
            require(nonempty(text), f"{code} {number}:{first}: empty source text")
            require(hashlib.sha256(text.encode()).hexdigest() == row.get("textSHA256"),
                    f"{code} {number}:{first}: text hash mismatch")
            row_pages = page_list(row.get("sourcePages"), total, f"{code} {number}:{first}",
                                  allow_empty=not complete)
            used_pages |= row_pages
            source_note_ids.extend(validate_source_notes(row, label=f"{code} {number}:{first}",
                                                         source_pages=row_pages))
            units += 1
        label_inventory.append({"number": number, "units": ranges})
    require(numbers == sorted(numbers), f"{code}: chapter order is not ascending")
    structure = validate_structure(chapters, routes=book.get("addressRoutes", ABSENT),
                                   authoring=True, page_count=total, allow_empty_pages=not complete,
                                   label=code)
    used_pages |= structure["sourcePages"]
    source_note_ids = structure["sourceNoteIds"]
    declared = set()
    if "textPages" in scan:
        declared = page_list(scan["textPages"], total, f"{code} text inventory")
        require(used_pages <= declared, f"{code}: text outside the declared source pages")
    if complete:
        require(bool(declared), f"{code}: missing complete source page inventory")
        require(review.get("unresolvedFindings") == [], f"{code}: unresolved findings not cleared")
        require(isinstance(approval, dict), f"{code}: missing independent source inventory")
        require(approval.get("contentSHA256") == digest(book), f"{code}: completed review digest is stale")
        expected_pages = page_list(approval.get("textPages"), total, f"{code} approved inventory")
        require(approval.get("scanSHA256") == scan["sha256"], f"{code}: inventory uses another scan")
        require(approval.get("chapters") == label_inventory, f"{code}: missing, added or reordered source units")
        require(approval.get("contentBlocks", []) == structure["contentBlocks"],
                f"{code}: source block review inventory mismatch")
        require(approval.get("addressRoutes", []) == structure["addressRoutes"],
                f"{code}: source route review inventory mismatch")
        require(used_pages == expected_pages == reviewed == declared,
                f"{code}: not every source page is represented and reviewed")
        require(nonempty(approval.get("method")), f"{code}: missing inventory review method")
        require(review.get("acceptedSourceNoteIds", []) == sorted(source_note_ids) ==
                approval.get("sourceNoteIds", []), f"{code}: source-note review inventory mismatch")
        require(type(approval.get("hasIntroduction")) is bool and
                approval["hasIntroduction"] == ("introduction" in book), f"{code}: opening inventory mismatch")
        # Source gaps may be faithfully transcribed, but cannot be advertised as a
        # gap-free chapter. Require explicit evidence, not inferred missing labels.
        for chapter, expected in zip(chapters, approval["chapters"], strict=True):
            last = chapter.get("lastVerse")
            require(positive(last), f"{code} {chapter['number']}: missing source terminal label")
            labels = {n for first, end in expected["units"] for n in range(first, end + 1)}
            require(max(labels) <= last, f"{code}: label exceeds source terminal label")
            omitted = sorted(set(range(1, last + 1)) - labels)
            gaps = approval.get("sourceGaps", {}).get(str(chapter["number"]), {})
            require(gaps.get("omittedLabels", []) == omitted, f"{code}: omitted labels lack source review")
            if not chapter.get("isComplete", True) or omitted:
                require(chapter.get("isComplete") is False and nonempty(gaps.get("reason")),
                        f"{code}: source lacuna needs a partial chapter and a reason")
    return {"book": code, "status": review["status"], "chapters": len(chapters), "units": units,
            "sourcePages": len(used_pages), "reviewedPages": len(reviewed)}


def load_books(directory=CONTENT / "hebrew-deuterocanon", catalog_path=CONTENT / "hebrew-kahana-source-catalog.json",
               inventory_path=INVENTORY_PATH, *, require_complete=False) -> tuple[list[dict], list[dict]]:
    catalog = json.loads(Path(catalog_path).read_text())
    approvals = {}
    if Path(inventory_path).exists():
        inventory = json.loads(Path(inventory_path).read_text())
        require(inventory.get("schemaVersion") == 1, "Unknown Hebrew review inventory schema")
        approvals = inventory.get("books", {})
        require(isinstance(approvals, dict) and set(approvals) <= set(BOOKS), "Unknown approved Hebrew book")
    books, report = [], []
    for code in BOOKS:
        path = Path(directory) / f"{code}.json"
        if not path.exists():
            report.append({"book": code, "status": "missing"})
            continue
        book = json.loads(path.read_text())
        require(book.get("book") == code, f"{path.name}: book identity mismatch")
        report.append(validate_book(book, catalog, approvals.get(code)))
        books.append(book)
    pending = [row["book"] for row in report if row["status"] != "complete"]
    if pending:
        require(not require_complete, "Hebrew supplement is not release-ready: " + ", ".join(pending))
        # The user requested complete books before release. Never import a partial
        # selection simply because one book finishes before the rest.
        return [], report
    return books, report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-complete", action="store_true")
    args = parser.parse_args()
    try:
        books, report = load_books(require_complete=args.require_complete)
    except ValueError as error:
        raise SystemExit(str(error)) from error
    print(json.dumps({"productionBookCount": len(books), "books": report}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

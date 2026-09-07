#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Read-only final-letter audit of all canonical Hebrew-script Aramaic fields.

Includes titles, prayer bodies, mystery fields, reading aids, any future non-metadata fields,
explicit arc labels in bundle metadata, and the Aramaic prayer reflow fixtures. Only citation
gematria is exempt; words in a citation are still checked. Source comments and provenance
records are not prayer text. This never changes downloaded/user-authored packs or source text.

Run with --json for a counted inventory. The built-in tests also cover combining marks that
must not turn a medial letter into a false word ending.
"""

from __future__ import annotations

import json
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "Shared/content"
FINALS = {"כ": "ך", "מ": "ם", "נ": "ן", "פ": "ף", "צ": "ץ"}


def hebrew_words(text: str):
    word = ""
    for char in text:
        if "א" <= char <= "ת" or word and (unicodedata.category(char).startswith("M") or char in "׳״"):
            word += char
        elif word:
            yield word
            word = ""
    if word:
        yield word


def scan(text: str) -> tuple[list[str], int, int]:
    errors: list[str] = []
    checked = ignored = 0
    for line in text.splitlines():
        is_citation = line.lstrip().startswith("— ")
        for word in hebrew_words(line):
            if is_citation and any(char in word for char in "׳״"):
                ignored += 1
                continue
            checked += 1
            letters = [char for char in word if "א" <= char <= "ת"]
            if letters[-1] in FINALS:
                errors.append(word)
    return errors, checked, ignored


def fields(value, prefix=""):
    if isinstance(value, str):
        yield prefix, value
    elif isinstance(value, dict):
        for key, nested in value.items():
            if not key.startswith("$"):
                yield from fields(nested, f"{prefix}.{key}" if prefix else key)
    elif isinstance(value, list):
        for index, nested in enumerate(value):
            yield from fields(nested, f"{prefix}[{index}]")


def arc_fields(value, prefix=""):
    """Explicitly language-keyed labels outside content/arc.json."""
    if isinstance(value, dict):
        for key, nested in value.items():
            path = f"{prefix}.{key}" if prefix else key
            if key.startswith("$"):
                continue
            if key == "arc":
                yield from fields(nested, path)
            else:
                yield from arc_fields(nested, path)
    elif isinstance(value, list):
        for index, nested in enumerate(value):
            yield from arc_fields(nested, f"{prefix}[{index}]")


def check_fields(path: Path, entries) -> dict:
    result = {"path": str(path.relative_to(ROOT)), "fields": 0, "hebrewFields": 0,
              "wordsChecked": 0, "citationNumeralsIgnored": 0, "errors": []}
    for field, text in entries:
        result["fields"] += 1
        errors, checked, ignored = scan(text)
        result["hebrewFields"] += bool(checked or ignored)
        result["wordsChecked"] += checked
        result["citationNumeralsIgnored"] += ignored
        result["errors"].extend({"field": field, "word": word} for word in errors)
    return result


def audit() -> dict:
    canonical = []
    auxiliary = []
    for path in sorted(CONTENT.glob("*/content/arc*.json")):
        canonical.append(check_fields(path, fields(json.loads(path.read_text(encoding="utf-8")))))
    for path in sorted(CONTENT.rglob("*.json")):
        if path.parent.name == "content" and path.name.startswith("arc"):
            continue
        entries = list(arc_fields(json.loads(path.read_text(encoding="utf-8"))))
        if entries:
            auxiliary.append(check_fields(path, entries))
    reflow = ROOT / "Shared/tools/prayer-line-breaks.json"
    auxiliary.append(check_fields(reflow, fields(json.loads(reflow.read_text(encoding="utf-8"))["arc"], "arc")))
    return {"canonical": canonical, "auxiliary": auxiliary}


def self_test() -> None:
    assert scan("כ מ נ פ צ")[0] == list(FINALS)
    assert scan("ך ם ן ף ץ")[0] == []
    assert scan("קוריאליסונ\nקוריאליסונ\nקוריאליסונ")[0] == ["קוריאליסונ"] * 3
    assert scan("קוריאליסון\nקוריאליסון\nקוריאליסון")[0] == []
    assert scan("מ̈לכא מ̇לכא מַלכָּא מלךָ נוּן")[0] == []
    assert scan("מלכָ, נוּנ! פָצ־מָם")[0] == ["מלכָ", "נוּנ", "פָצ"]
    assert scan("— יוחנן כ׳ 1–9 (פשיטתא)") == ([], 2, 1)
    assert scan("— יוחנ כ׳ 1–9 (פשיטתא)")[0] == ["יוחנ"]
    assert scan("כ׳")[0] == ["כ׳"]
    # A Hebrew reading aid is audited even if its field is unfamiliar to today's schema.
    values = list(fields({"$comment": "לאנ", "readingAids": {"arc": "מלכ"}, "newField": "מלך"}))
    assert values == [("readingAids.arc", "מלכ"), ("newField", "מלך")]


def main() -> int:
    self_test()
    report = audit()
    rows = report["canonical"] + report["auxiliary"]
    totals = {key: sum(row[key] for row in rows) for key in
              ("fields", "hebrewFields", "wordsChecked", "citationNumeralsIgnored")}
    totals["errors"] = sum(len(row["errors"]) for row in rows)
    report["totals"] = totals
    if "--json" in sys.argv:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"Aramaic finals: {len(report['canonical'])} canonical files, {totals['hebrewFields']} Hebrew fields, "
              f"{totals['wordsChecked']} words, {totals['citationNumeralsIgnored']} citation numerals exempt, "
              f"{totals['errors']} errors")
        for row in rows:
            for error in row["errors"]:
                print(f"{row['path']}:{error['field']}: {error['word']}")
    return bool(totals["errors"])


if __name__ == "__main__":
    sys.exit(main())

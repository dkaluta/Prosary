#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Import reviewed Old Jesuit Arabic verses into prayers and native fallback tables.

The passage inventory is explicit: traditional Arabic Stations cite Scripture where
their Latin counterparts contain meditations. Neither runtime text nor a different
language's body determines what this importer replaces. All source verses and all
targets are checked before any file is written. --check only reports stale files.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parents[1]
SOURCE_PATH = Path("Shared/content/arabic-jesuit-1897.json")
INVENTORY_PATH = Path("Shared/tools/arabic-scripture-passages.json")
EDITION_ID = "jesuit-arabic-1897"
BOOK_NAMES = {
    "Matthew": "متى", "Mark": "مرقس", "Luke": "لوقا", "John": "يوحنا",
    "Acts": "أعمال الرسل", "Revelation": "الرؤيا", "Isaiah": "أشعيا",
}
NATIVE_PATHS = {
    "swift": Path("iOS/Prosary/Mocks/Content/MysteryTranslations+Arabic.swift"),
    "kotlin": Path("Android/app/src/main/java/com/dkaluta/prosary/content/MysteryTranslationsArabic.kt"),
    "csharp": Path("Windows/Prosary/Localization/MysteryTranslations.Arabic.cs"),
}


class ImportFailure(ValueError):
    """The input cannot produce a complete, unambiguous migration."""


def load_inventory(path: Path) -> list[dict]:
    rows = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(rows, list) or not rows:
        raise ImportFailure("The Arabic passage inventory must be a nonempty list")
    seen = set()
    for row in rows:
        if not isinstance(row, dict):
            raise ImportFailure("Each Arabic passage inventory entry must be an object")
        bundle, keys = row.get("bundle"), row.get("keys")
        if not isinstance(bundle, str) or not re.fullmatch(r"[A-Za-z0-9]+", bundle):
            raise ImportFailure("Invalid bundle in Arabic passage inventory")
        if (not isinstance(keys, list) or not all(isinstance(key, str) and key for key in keys)
                or not ((len(keys) == 2 and keys[0] == "prayers")
                        or (len(keys) == 3 and keys[0] == "mysteries" and keys[2] == "description"))):
            raise ImportFailure(f"Invalid target keys for {bundle}")
        identity = (bundle, tuple(keys))
        if identity in seen:
            raise ImportFailure(f"Repeated Arabic passage target: {bundle}:{'.'.join(keys)}")
        seen.add(identity)
        numbers = row.get("verses")
        if (row.get("book") not in BOOK_NAMES or type(row.get("chapter")) is not int
                or row["chapter"] < 1 or not isinstance(numbers, list) or not numbers
                or any(type(number) is not int or number < 1 for number in numbers)
                or numbers != sorted(set(numbers))):
            raise ImportFailure(f"Invalid verse coordinates for {bundle}:{'.'.join(keys)}")
    return rows


def source_verses(source: dict, rows: list[dict]) -> dict[tuple[str, int, int], str]:
    if not isinstance(source, dict):
        raise ImportFailure("The Arabic verse source must be an object")
    edition = source.get("edition", {})
    if not isinstance(edition, dict) or edition.get("id") != EDITION_ID:
        raise ImportFailure(f"Expected source edition {EDITION_ID}")
    for field in ("name", "sourceURL", "attribution"):
        if not isinstance(edition.get(field), str) or not edition[field].strip():
            raise ImportFailure(f"The source edition needs {field}")
    if not edition["sourceURL"].startswith("https://"):
        raise ImportFailure("The source edition needs an HTTPS sourceURL")
    requested = {(row["book"], row["chapter"], number) for row in rows for number in row["verses"]}
    found, missing = {}, []
    for book, chapter, verse in sorted(requested):
        value = source.get("verses", {})
        for key in (book, str(chapter), str(verse)):
            value = value.get(key) if isinstance(value, dict) else None
        if (not isinstance(value, str) or not value.strip() or "\ufffd" in value
                or any(ord(char) < 32 and char not in "\n\r\t" for char in value)):
            missing.append(f"{book} {chapter}:{verse}")
        else:
            found[(book, chapter, verse)] = value.strip()
    if missing:
        raise ImportFailure("Missing or invalid source verses:\n" + "\n".join(missing))
    return found


def consecutive_groups(numbers: list[int]) -> list[list[int]]:
    groups: list[list[int]] = []
    for number in numbers:
        if groups and number == groups[-1][-1] + 1:
            groups[-1].append(number)
        else:
            groups.append([number])
    return groups


def render_passage(row: dict, verses: dict[tuple[str, int, int], str]) -> str:
    groups = consecutive_groups(row["verses"])
    body = " […] ".join(" ".join(verses[(row["book"], row["chapter"], number)]
                                   for number in group) for group in groups)
    reference = "، ".join(str(group[0]) if len(group) == 1 else f"{group[0]}–{group[-1]}"
                           for group in groups)
    return (f"{body}\n\n— {BOOK_NAMES[row['book']]} {row['chapter']}:{reference} "
            "(اليسوعية القديمة، 1897)")


def render_bundle(existing: dict, rows: list[dict], verses: dict, source: dict,
                  source_hash: str) -> dict:
    result = copy.deepcopy(existing)
    for row in rows:
        target = result
        for key in row["keys"][:-1]:
            if not isinstance(target.get(key), dict):
                raise ImportFailure(f"Missing existing target: {row['bundle']}:{'.'.join(row['keys'])}")
            target = target[key]
        if not isinstance(target.get(row["keys"][-1]), str):
            raise ImportFailure(f"Missing existing text: {row['bundle']}:{'.'.join(row['keys'])}")
        target[row["keys"][-1]] = render_passage(row, verses)
    edition = source["edition"]
    result["$scriptureSource"] = (f"{edition['name']}. {edition['attribution']} "
                                  f"Source: {edition['sourceURL']}. "
                                  "Imported by Shared/tools/import-arabic-scripture.py; "
                                  "published wording is retained, with complete cited verses.")
    result["$scriptureImport"] = {
        "editionId": EDITION_ID, "sourceURL": edition["sourceURL"],
        "sourceSHA256": source_hash,
        "prayerKeys": sorted(row["keys"][1] for row in rows if row["keys"][0] == "prayers"),
        "mysteryKeys": sorted(row["keys"][1] for row in rows if row["keys"][0] == "mysteries"),
    }
    return result


STRING_LITERAL = r'"(?:\\.|[^"\\])*"'
STRING_EXPRESSION = STRING_LITERAL + r'(?:\s*\+\s*' + STRING_LITERAL + r')*'
NATIVE_PATTERNS = {
    "swift": (r'(?P<head>"(?P<key>[^"\\]+)"\s*:\s*MysteryText\(\s*title:\s*'
              + STRING_LITERAL + r',\s*fruit:\s*' + STRING_LITERAL + r',\s*description:\s*)'),
    "kotlin": (r'(?P<head>"(?P<key>[^"\\]+)"\s+to\s+MysteryText\(\s*title\s*=\s*'
               + STRING_LITERAL + r',\s*fruit\s*=\s*' + STRING_LITERAL + r',\s*description\s*=\s*)'),
    "csharp": (r'(?P<head>\["(?P<key>[^"\\]+)"\]\s*=\s*new\(\s*'
               + STRING_LITERAL + r',\s*' + STRING_LITERAL + r',\s*)'),
}


def native_string(value: str, language: str) -> str:
    literal = json.dumps(value, ensure_ascii=False)
    # Kotlin interpolates dollars inside ordinary strings. Arabic source text must
    # remain text even if a reviewed source contains an ASCII dollar sign.
    return literal.replace("$", r"\$") if language == "kotlin" else literal


def render_native(existing: str, mysteries: dict, language: str) -> str:
    pattern = re.compile(NATIVE_PATTERNS[language] + r'(?P<body>' + STRING_EXPRESSION + r')(?P<tail>\s*\))')
    seen = set()

    def replace(match: re.Match) -> str:
        key = match.group("key")
        if key not in mysteries or key in seen:
            raise ImportFailure(f"Unexpected or repeated {language} Arabic mystery: {key}")
        seen.add(key)
        return (match.group("head") + native_string(mysteries[key]["description"], language)
                + match.group("tail"))

    result = pattern.sub(replace, existing)
    if seen != set(mysteries):
        raise ImportFailure(f"Missing {language} Arabic fallback entries: {', '.join(sorted(set(mysteries) - seen))}")
    result = result.replace(
        "Arabic Scripture edition target: Old Jesuit Arabic Bible (Beirut, 1897).",
        "Descriptions use the Old Jesuit Arabic Bible (Beirut, 1897).")
    result = result.replace(
        "Existing descriptions await replacement from the verified public-domain source.",
        "Descriptions are generated from Shared/content/rosary/content/ar.json by import-arabic-scripture.py.")
    return result


def build_plan(root: Path = ROOT, source_path: Path | None = None,
               inventory_path: Path | None = None) -> dict[Path, str]:
    source_path = source_path or root / SOURCE_PATH
    rows = load_inventory(inventory_path or root / INVENTORY_PATH)
    raw = source_path.read_bytes()
    source = json.loads(raw)
    verses = source_verses(source, rows)  # Fail for every missing verse before rendering/writing.
    digest = hashlib.sha256(raw).hexdigest()
    plan, rendered = {}, {}
    for bundle in dict.fromkeys(row["bundle"] for row in rows):
        path = root / "Shared/content" / bundle / "content/ar.json"
        existing = json.loads(path.read_text(encoding="utf-8"))
        bundle_rows = [row for row in rows if row["bundle"] == bundle]
        rendered[bundle] = render_bundle(existing, bundle_rows, verses, source, digest)
        plan[path] = json.dumps(rendered[bundle], ensure_ascii=False, indent=2) + "\n"
    if "rosary" in rendered:
        mysteries = {row["keys"][1]: rendered["rosary"]["mysteries"][row["keys"][1]]
                     for row in rows if row["bundle"] == "rosary" and row["keys"][0] == "mysteries"}
        for language, relative in NATIVE_PATHS.items():
            path = root / relative
            plan[path] = render_native(path.read_text(encoding="utf-8"), mysteries, language)
    return plan


def apply_plan(plan: dict[Path, str], *, check: bool) -> list[Path]:
    changed = [path for path, text in plan.items()
               if path.read_text(encoding="utf-8") != text]
    if not check:
        for path in changed:
            path.write_text(plan[path], encoding="utf-8")
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Report differences without writing")
    options = parser.parse_args()
    try:
        changed = apply_plan(build_plan(), check=options.check)
    except (ImportFailure, OSError, json.JSONDecodeError) as error:
        print(f"import-arabic-scripture: {error}", file=sys.stderr)
        return 1
    for path in changed:
        print(f"{'out of date' if options.check else 'updated'}: {path.relative_to(ROOT)}")
    if options.check and changed:
        return 1
    print("Arabic Scripture and native fallbacks are up to date.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

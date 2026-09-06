#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Inventory real prayer-language fallbacks without fetching or modifying content.

The format validator accepts every known PrayerKey in every language; that proves key
validity, not a translation's existence. This audit checks selected-language text first,
including native tables, shared bundle overrides, and field-wise mystery inheritance.

    uv run --script Shared/tools/audit-prayer-coverage.py
    uv run --script Shared/tools/audit-prayer-coverage.py --json
    uv run --script Shared/tools/audit-prayer-coverage.py --markdown

Reports include undeclared language overlays and absent languages separately from missing
content in advertised languages. Counts are key/language pairs, not unique prayers. This
is a coverage inventory, not a source-fidelity or native-speaker review.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
LANGUAGES = ("la", "en", "he", "ar", "ru", "tl", "fr", "it", "es", "el", "arc")
TABLES = {
    "la": "Latin", "en": "English", "he": "Hebrew", "ar": "Arabic",
    "ru": "Russian", "tl": "Tagalog", "es": "Spanish", "el": "Greek",
    "he-x-gamliel": "HebrewGamaliel",
}
# Reserved by PrayerKey for future use; not a missing prayer in today's flows.
INACTIVE_FIXED = {"doxologiaMinor"}
ANTIPHON_BODIES = {
    "salveRegina", "almaRedemptorisMater", "aveReginaCaelorum", "reginaCaeli",
    "subTuumPraesidium", "versiculumStandard", "responsiumStandard", "collectaStandard",
    "versiculumPaschale", "responsiumPaschale", "collectaPaschale",
}
ANTIPHON_TITLES = {key + "Title" for key in (
    "salveRegina", "almaRedemptorisMater", "aveReginaCaelorum", "reginaCaeli", "subTuumPraesidium",
)}


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def swift_prayers(path: Path) -> dict[str, str]:
    """Read actual string values, including concatenated and multiline Swift strings."""
    result = {}
    pattern = r'\.(\w+):\s*((?:"""[\s\S]*?"""|(?:"(?:[^"\\]|\\.)*"\s*\+?\s*)+))\s*,'
    for match in re.finditer(pattern, path.read_text(encoding="utf-8")):
        key, raw = match.groups()
        if raw.startswith('"""'):
            value = re.sub(r"\n\s*$", "", re.sub(r"^\n", "", raw[3:-3]))
            lines = value.splitlines()
            indent = min((len(line) - len(line.lstrip()) for line in lines if line.strip()), default=0)
            value = "\n".join(line[indent:] for line in lines)
        else:
            value = "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', raw))
        value = value.replace("\\n", "\n").replace('\\"', '"').replace("\\\\", "\\")
        value = re.sub(r"\\u\{([0-9A-Fa-f]+)\}", lambda m: chr(int(m[1], 16)), value)
        if value.strip():
            result[key] = value
    return result


def is_label(key: str) -> bool:
    return key.endswith(("Title", "Label", "Subtitle", "Format", "Connector", "Noun")) or bool(
        re.fullmatch(r"stationOrdinal\d+", key)
    ) or key in {"aveMariaProFide", "aveMariaProSpe", "aveMariaProCaritate"}


def walk(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def body_kind(key: str, entry: dict, language: str) -> str:
    if entry.get("isScriptureByLanguage", {}).get(language, entry.get("isScripture", False)):
        return "scripture_body"
    if re.fullmatch(r"station\d+Body", key):
        return "meditation_body"
    return "prayer_body"


def collect_refs(devotion: dict, language: str) -> tuple[dict[str, set], set, set]:
    refs = defaultdict(set)
    mysteries, meditations = set(), set()
    for entry in walk(devotion):
        if key := entry.get("bodyKey"):
            refs[body_kind(key, entry, language)].add(key)
        if key := entry.get("acclamationKey"):
            # A response beside Scripture is always ordinary prayer text.
            refs["prayer_body"].add(key)
        refs["prayer_body"].update(entry.get("bodyKeys", []))
        for field in ("titleKey", "subtitleKey", "ordinalNounKey", "combinedTitleKey"):
            if key := entry.get(field):
                refs["heading_or_label"].add(key)
        if entry.get("kind") in {"marianAntiphon", "seasonalMarianAntiphon"}:
            seasonal = entry["kind"] == "seasonalMarianAntiphon"
            refs["prayer_body"].update(ANTIPHON_BODIES - ({"subTuumPraesidium"} if seasonal else set()))
            refs["heading_or_label"].update(ANTIPHON_TITLES - ({"subTuumPraesidiumTitle"} if seasonal else set()))
        if entry.get("announceMystery"):
            for mystery in entry.get("entries", []):
                mysteries.add(mystery["imageKey"])
                if not mystery.get("isScriptureByLanguage", {}).get(language, mystery.get("isScripture", True)):
                    meditations.add(mystery["imageKey"])
    if devotion.get("type") == "rosary":
        refs["heading_or_label"].update({"fructusMysteriiLabel", "decadeOrdinalFormat", "repetitionCounterConnector"})
    return refs, mysteries, meditations


def inventory() -> dict:
    key_source = ROOT / "iOS/Prosary/Mocks/Content/PrayerKey.swift"
    fixed_keys = set(re.findall(r"^  case (\w+)", key_source.read_text(), re.M))
    labels = {key for key in fixed_keys if is_label(key)}
    native, table_parity = {}, []
    for language, name in TABLES.items():
        table = swift_prayers(ROOT / f"iOS/Prosary/Mocks/Content/PrayerTranslations+{name}.swift")
        native[language] = table
        android = (ROOT / f"Android/app/src/main/java/com/dkaluta/prosary/content/PrayerTranslations{name}.kt").read_text()
        windows = (ROOT / f"Windows/Prosary/Localization/PrayerTranslations.{name}.cs").read_text()
        normalized = lambda values: {key[0].lower() + key[1:] for key in values}
        android_keys = normalized(re.findall(r"PrayerKey\.(\w+)\s+to\b", android))
        windows_keys = normalized(re.findall(r"\[PrayerKey\.(\w+)\]\s*=", windows))
        table_parity.append({"language": language, "iOS_keys": len(table), "Android_keys": len(android_keys),
                             "Windows_keys": len(windows_keys), "Android_vs_iOS": sorted(android_keys ^ table.keys()),
                             "Windows_vs_iOS": sorted(windows_keys ^ table.keys())})
    contents, manifests, devotions = {}, {}, {}
    fixed = {language: dict(native.get(language, {})) for language in LANGUAGES}
    mysteries = {language: {} for language in LANGUAGES}
    native_mystery_counts = {}
    for language, name in TABLES.items():
        path = ROOT / f"iOS/Prosary/Mocks/Content/MysteryTranslations+{name}.swift"
        if not path.exists():
            continue
        for key, body in re.findall(r'"([a-z0-9_]+)": MysteryText\((.*?)(?=\n    "|\n  \])', path.read_text(), re.S):
            mysteries[language][key] = {field: True for field in ("title", "fruit", "description")
                                        if re.search(r"\b" + field + r":", body)}
        native_mystery_counts[language] = len(mysteries[language])
    for manifest_path in sorted((ROOT / "Shared/content").glob("*/manifest.json")):
        folder, pack = manifest_path.parent, manifest_path.parent.name
        manifests[pack], devotions[pack] = read_json(manifest_path), read_json(folder / "devotion.json")
        contents[pack] = {path.stem: read_json(path) for path in sorted((folder / "content").glob("*.json"))}
        for language, data in contents[pack].items():
            if language not in LANGUAGES:
                continue  # he-x-gamliel intentionally inherits Hebrew; not a separate public language.
            fixed[language].update({key: value for key, value in data.get("prayers", {}).items()
                                    if key in fixed_keys and isinstance(value, str) and value.strip()})
            for key, value in data.get("mysteries", {}).items():
                mysteries[language][key] = {**mysteries[language].get(key, {}), **value}
    packs = {}
    for pack, localized in contents.items():
        canonical_keys = set().union(*(data.get("prayers", {}).keys() for data in localized.values()))
        canonical_mysteries = set().union(*(data.get("mysteries", {}).keys() for data in localized.values()))
        packs[pack] = {}
        for language in LANGUAGES:
            refs, required_mysteries, meditation_mysteries = collect_refs(devotions[pack], language)
            required_mysteries |= canonical_mysteries
            referenced = set().union(*refs.values())
            for key in canonical_keys - referenced:
                refs["heading_or_label" if is_label(key) else "supplemental_body"].add(key)
            local_prayers = localized.get(language, {}).get("prayers", {})

            def present(key: str) -> bool:
                if key == "signumCrucisFormB" and language != "arc":
                    key = "signumCrucis"  # Runtime alias: this alternate wording exists only in Aramaic.
                value = local_prayers.get(key) or fixed[language].get(key)
                return isinstance(value, str) and bool(value.strip())

            missing = {category: sorted(key for key in keys if not present(key)) for category, keys in sorted(refs.items())}
            missing_mysteries = {field: sorted(key for key in required_mysteries if not mysteries[language].get(key, {}).get(field))
                                 for field in ("title", "fruit", "description")}
            missing_mysteries["scripture_descriptions"] = sorted(set(missing_mysteries["description"]) - meditation_mysteries)
            missing_mysteries["meditation_descriptions"] = sorted(set(missing_mysteries["description"]) & meditation_mysteries)
            status = ("advertised" if language in manifests[pack]["languages"] else
                      "partial_overlay" if language in localized else "absent_language")
            packs[pack][language] = {"status": status, "source_file": f"Shared/content/{pack}/content/{language}.json",
                                     "missing": missing, "missing_mysteries": missing_mysteries}
    return {
        "method": "Exact selected-language coverage before user fallback. Native fixed prayers and shared bundle overrides merge; local keys resolve in their own pack. Shared mystery fields merge across packs. Hebrew traditions are one language, with he-x-gamliel inheriting he. Absent languages are expansion work, not broken manifest promises. Counts are key/language pairs, not unique prayers or editorial approval.",
        "languages": list(LANGUAGES), "canonical_files": sum(len(langs) for langs in contents.values()),
        "pack_count": len(packs), "status_counts": dict(Counter(row["status"] for langs in packs.values() for row in langs.values())),
        "fixed_prayers": {language: {
            "missing_prayer_bodies": sorted(fixed_keys - labels - INACTIVE_FIXED - fixed[language].keys()),
            "missing_headings_or_labels": sorted(labels - fixed[language].keys()),
            "missing_inactive_fixed_bodies": sorted(INACTIVE_FIXED - fixed[language].keys()),
            "native_keys": len(native.get(language, {})), "resolved_fixed_keys": len(fixed[language]),
        } for language in LANGUAGES},
        "packs": packs, "native_table_key_parity": table_parity, "native_mystery_counts": native_mystery_counts,
        "inactive_fixed_note": "doxologiaMinor is reserved for future use and excluded from active body-gap counts.",
    }


def markdown(report: dict) -> str:
    lines = ["# Prayer language coverage", "", "Generated from the current checkout with `uv run --script Shared/tools/audit-prayer-coverage.py --markdown`.",
             "", report["method"], "", report["inactive_fixed_note"], "",
             f"Scope: {report['canonical_files']} canonical language files, {report['pack_count']} packs, {len(report['languages'])} public prayer languages.",
             "", "## Common fixed prayers", "", "| Language | Missing bodies | Missing headings |", "|---|---:|---:|"]
    for language, row in report["fixed_prayers"].items():
        lines.append(f"| {language} | {len(row['missing_prayer_bodies'])} | {len(row['missing_headings_or_labels'])} |")
    lines += ["", "## Pack coverage gaps", "", "Rows with no missing fields and an advertised language are omitted.", "",
              "| Pack | Language | Status | Prayer bodies | Scripture | Meditations | Other bodies | Headings | Mystery title / fruit / body |",
              "|---|---|---|---:|---:|---:|---:|---:|---|"]
    for pack, languages in report["packs"].items():
        for language, row in languages.items():
            counts = {key: len(value) for key, value in row["missing"].items()}
            mystery = row["missing_mysteries"]
            if not any(counts.values()) and not any(mystery.values()) and row["status"] == "advertised":
                continue
            values = [counts.get(key, 0) for key in ("prayer_body", "scripture_body", "meditation_body", "supplemental_body", "heading_or_label")]
            lines.append(f"| {pack} | {language} | {row['status']} | " + " | ".join(map(str, values)) +
                         f" | {len(mystery['title'])} / {len(mystery['fruit'])} / {len(mystery['description'])} |")
    lines += ["", "## Exact common-prayer gaps", ""]
    for language, row in report["fixed_prayers"].items():
        if row["missing_prayer_bodies"] or row["missing_headings_or_labels"]:
            lines += [f"### {language}", "", "Bodies: " + ", ".join(row["missing_prayer_bodies"]), "",
                      "Headings: " + ", ".join(row["missing_headings_or_labels"]), ""]
    lines += ["## Exact pack gaps", "", "The sibling `PRAYER-LANGUAGE-COVERAGE.json` records every missing key and its intended canonical file.",
              "Regenerate it with `uv run --script Shared/tools/audit-prayer-coverage.py --json`.", "",
              "Presence only establishes coverage. Source provenance, accurate wording, and liturgical suitability require separate review.", ""]
    return "\n".join(line.rstrip() for line in lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    output = parser.add_mutually_exclusive_group()
    output.add_argument("--json", action="store_true", help="Print exact missing-key lists as JSON")
    output.add_argument("--markdown", action="store_true", help="Print the compact review report")
    args = parser.parse_args()
    report = inventory()
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    elif args.markdown:
        print(markdown(report), end="")
    else:
        print(f"{report['canonical_files']} files; {report['pack_count']} packs; {len(report['languages'])} languages")
        print("Pack/language pairs: " + ", ".join(f"{key}={value}" for key, value in report["status_counts"].items()))
        for language, row in report["fixed_prayers"].items():
            if row["missing_prayer_bodies"] or row["missing_headings_or_labels"]:
                print(f"  {language}: {len(row['missing_prayer_bodies'])} missing fixed bodies; {len(row['missing_headings_or_labels'])} missing labels")
        print("Use --json for every missing pack key; a successful audit does not mean every translation is complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

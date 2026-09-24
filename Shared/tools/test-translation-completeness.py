#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Keep native UI, bundle metadata, mystery names and fruits complete without fallback.

Prayer bodies require published sources and are inventoried separately. Their absence
must never be hidden by claiming that a Latin fallback is a completed translation.
"""
import importlib.util
import json
from pathlib import Path
import plistlib
import re
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[2]
LANGUAGES = ("en", "he", "ar", "ru", "tl", "fr", "it", "uk")


def nonempty(value):
    return isinstance(value, str) and bool(value.strip()) and "\ufffd" not in value


def native_rows(path, platform):
    rows = {}
    for row in ET.parse(path).getroot():
        if row.attrib.get("translatable") == "false":
            continue
        if platform == "Windows" and row.tag == "data":
            values = [row.findtext("value", "")]
        elif platform == "Android" and row.tag == "string":
            values = ["".join(row.itertext())]
        elif platform == "Android" and row.tag in {"string-array", "plurals"}:
            values = ["".join(item.itertext()) for item in row.findall("item")]
        else:
            continue
        key = row.attrib["name"]
        assert key not in rows, (platform, path, "duplicate resource", key)
        assert values and all(nonempty(value.strip().strip('"')) for value in values), (platform, path, key)
        rows[key] = values
    return rows


for catalog_path in sorted((ROOT / "iOS").glob("*/*.xcstrings")):
    catalog = catalog_path.stem
    apple = json.loads(catalog_path.read_text())
    for key, row in apple["strings"].items():
        if not key or row.get("shouldTranslate") is False:
            continue
        # The bundle's invariant product name is a brand, not a translatable UI label.
        if catalog == "InfoPlist" and key == "CFBundleName":
            assert row["localizations"]["en"]["stringUnit"]["value"] == "Prosary"
            continue
        for language in LANGUAGES:
            # Xcode's catalog uses the platform identifier; canonical content uses tl.
            localized = row.get("localizations", {}).get("fil" if language == "tl" else language)
            assert localized, ("Apple", catalog, key, language)
            units = []
            def collect_units(value):
                if isinstance(value, dict):
                    if "stringUnit" in value:
                        units.append(value["stringUnit"].get("value"))
                    if "stringSet" in value:
                        units.extend(value["stringSet"].get("values", []))
                    for child in value.values():
                        collect_units(child)
            collect_units(localized)
            assert units and all(nonempty(unit) for unit in units), ("Apple", catalog, key, language)
            if catalog == "AppShortcuts":
                assert all("${applicationName}" in unit for unit in units), ("Apple", catalog, key, language, "missing app name")

settings = ROOT / "iOS/Prosary/Settings.bundle"
settings_root = plistlib.loads((settings / "Root.plist").read_bytes())
settings_keys = {
    value
    for row in settings_root["PreferenceSpecifiers"]
    for key, value in row.items()
    if key in {"Title", "FooterText"} and value != "Prosary"
}
for language in LANGUAGES:
    path = settings / f"{'fil' if language == 'tl' else language}.lproj/Root.strings"
    rows = re.findall(r'"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;', path.read_text())
    assert len(rows) == len(dict(rows)), (path, "duplicate settings label")
    localized = dict(rows)
    assert settings_keys <= localized.keys(), (path, settings_keys - localized.keys())
    assert all(nonempty(value) for value in localized.values()), (path, "empty settings label")

android = ROOT / "Android/app/src/main/res"
android_paths = {"en": "values", "he": "values-iw", "tl": "values-tl"}
windows = ROOT / "Windows/Prosary/Strings"
windows_paths = {"en": "en-US", "tl": "fil"}
for platform in ("Android", "Windows"):
    baseline = None
    for language in LANGUAGES:
        path = (android / android_paths.get(language, f"values-{language}") / "strings.xml" if platform == "Android"
                else windows / windows_paths.get(language, language) / "Resources.resw")
        rows = native_rows(path, platform)
        assert rows, (platform, language)
        if baseline is None:
            baseline = rows
        assert rows.keys() == baseline.keys(), (platform, language, baseline.keys() - rows.keys(), rows.keys() - baseline.keys())
        for key, values in rows.items():
            # Each artwork attribution in an Android string array is independently visible.
            assert len(values) == len(baseline[key]), (platform, language, key, "item count")
    if platform == "Android":
        assert (android / "values-tl/strings.xml").read_bytes() == (android / "values-b+fil/strings.xml").read_bytes()

METADATA = {"displayNameByLanguage", "nameByLanguage", "periodByLanguage", "reminderBody", "reminderPresetFooter"}


def check_metadata(value, path):
    if isinstance(value, dict):
        for base in ("displayName", "name", "period"):
            if base in value:
                assert nonempty(value[base]), (path, base, "empty base label")
                assert isinstance(value.get(base + "ByLanguage"), dict), (path, base, "missing translation map")
        for key, child in value.items():
            if key in METADATA:
                assert isinstance(child, dict), (path, key, "invalid translation map")
                required = LANGUAGES if key in {"reminderBody", "reminderPresetFooter"} else LANGUAGES[1:]
                for language in required:
                    assert nonempty(child.get(language)), (path, key, language)
            check_metadata(child, f"{path}/{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            check_metadata(child, f"{path}/{index}")


for name in ("manifest.json", "options.json", "devotion.json"):
    for path in (ROOT / "Shared/content").glob(f"*/{name}"):
        check_metadata(json.loads(path.read_text()), path)

# A complete source file is only useful if the distributed archive contains it.
# Native byte parity is independently checked by test-asset-deduplication.py.
for manifest in (ROOT / "Shared/content").glob("*/manifest.json"):
    folder = manifest.parent
    expected = list((folder / "content").glob("*.json")) + [
        folder / name for name in ("manifest.json", "options.json", "devotion.json", "catalog.json", "audio.json")
        if (folder / name).exists()
    ]
    with zipfile.ZipFile(ROOT / "Shared/dist" / (folder.name + ".prosaryprayer")) as archive:
        for path in expected:
            entry = path.relative_to(folder).as_posix()
            assert archive.read(entry) == path.read_bytes(), (folder.name, entry, "stale distributed content")
        assert {name for name in archive.namelist() if name.startswith("content/") and name.endswith(".json")} == {
            path.relative_to(folder).as_posix() for path in expected if path.parent.name == "content"
        }, (folder.name, "stale distributed language files")

spec = importlib.util.spec_from_file_location("coverage", ROOT / "Shared/tools/audit-prayer-coverage.py")
coverage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(coverage)
group_label_keys = {f"mysteryGroup{group}Title" for group in ("Joyful", "Sorrowful", "Glorious", "Luminous")}
for language in coverage.LANGUAGES:
    prayers = json.loads((ROOT / f"Shared/content/rosary/content/{language}.json").read_text())["prayers"]
    assert all(nonempty(prayers.get(key)) for key in group_label_keys), (language, "missing Rosary group label")
report = coverage.inventory()
for language, row in report["fixed_prayers"].items():
    assert not row["missing_headings_or_labels"], (language, row)
for pack, languages in report["packs"].items():
    for language, row in languages.items():
        assert not row["missing"].get("heading_or_label"), (pack, language, row["missing"])
        for field in ("title", "fruit"):
            assert not row["missing_mysteries"][field], (pack, language, field, row["missing_mysteries"][field])

print("All eight native UI locales, shared UI metadata, and twelve-language prayer headings/mystery names/fruits are complete.")

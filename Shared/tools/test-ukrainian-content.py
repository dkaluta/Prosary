#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Offline source, actual-coverage and metadata checks for Ukrainian built-in prayers."""
import importlib.util
import json
import re
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
CONTENT = TOOLS.parent / "content"


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def words(text):
    # Remove only display cues and the source's reader/response labels, never wording.
    text = re.sub(r"(?m)^[ВУС]\.\s*", "", text)
    return " ".join(text.replace(" ✠", "").replace("*", "").split())


def walk(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def main():
    fixture = read(TOOLS / "fixtures/ukrainian-source-excerpts.json")
    content = {p.parent.parent.name: read(p) for p in CONTENT.glob("*/content/uk.json")}
    assert len(content) == 10
    for record in fixture["prayers"]:
        actual = content[record["bundle"]]["prayers"][record["key"]]
        assert words(actual) == words(record["excerpt"]), record["key"]
        assert record["source"].startswith("https://rkc.org.ua/")
        assert re.fullmatch(r"[a-f0-9]{64}", record["pageSha256"])

    # This edition's 9:2 must remain the darkness-and-light verse. Source examples also
    # guard historically spelled words against silent modernization or another edition.
    examples = fixture["scripture"]
    isaiah = content["oAntiphons"]["prayers"]
    for key, refs in {
        "oSapientiaLectio": ["ISA 11:2", "ISA 11:3"],
        "oAdonaiLectio": ["ISA 11:4", "ISA 11:5"],
        "oRadixIesseLectio": ["ISA 11:10"], "oClavisDavidLectio": ["ISA 22:22"],
        "oOriensLectio": ["ISA 9:2"], "oRexGentiumLectio": ["ISA 28:16"],
        "oEmmanuelLectio": ["ISA 7:14"],
    }.items():
        assert isaiah[key].split("\n\n—")[0] == " ".join(examples[ref] for ref in refs), key
    assert "— Ісая 9:2 (" in isaiah["oOriensLectio"]
    mysteries = content["rosary"]["mysteries"]
    assert examples["LUK 1:28"] in mysteries["joyful_01_annunciation"]["description"]
    assert examples["JOH 19:1"] in mysteries["sorrowful_02_scourging_at_the_pillar"]["description"]
    assert examples["REV 12:1"] in mysteries["glorious_04_assumption"]["description"]

    passages = 0
    for bundle, data in content.items():
        imported = data.get("$scriptureImport", {})
        for key in imported.get("prayerKeys", []):
            assert "Пулюй, 1905)" in data["prayers"][key], (bundle, key)
            passages += 1
        for key in imported.get("mysteryKeys", []):
            assert "Пулюй, 1905)" in data["mysteries"][key]["description"], (bundle, key)
            passages += 1
        folder = CONTENT / bundle
        manifest = read(folder / "manifest.json")
        assert "uk" in manifest["languages"]
        assert re.search(r"[А-Яа-яІіЇїЄєҐґ]", manifest["displayNameByLanguage"]["uk"])
        for filename in ("devotion.json", "options.json"):
            path = folder / filename
            if path.exists():
                for item in walk(read(path)):
                    if "nameByLanguage" in item:
                        assert item["nameByLanguage"].get("uk"), (bundle, item["name"])
    assert passages == 63, passages

    # Audit selected-language presence before fallback. Explicitly pin known gaps so a
    # newly missing body/heading cannot be hidden by format validation or a Latin fallback.
    spec = importlib.util.spec_from_file_location("coverage", TOOLS / "audit-prayer-coverage.py")
    audit = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(audit)
    result = audit.inventory()
    rosary_gaps = {"almaRedemptorisMater", "aveReginaCaelorum", "collectaStandard"}
    expected = {
        "rosary": rosary_gaps, "franciscanCrown": rosary_gaps,
        "litanyOfLoreto": {"collectAfterRosary"},
        "stationsOfTheCross": {"stationsOpeningPrayer", "stationsClosingPrayer"}
            | {f"station{i:02}Body" for i in range(1, 15)},
        "viaLucis": {"viaLucisAcclamation"},
    }
    unique_gaps = set()
    for bundle, languages in result["packs"].items():
        uk = languages["uk"]
        assert not uk["missing"]["heading_or_label"], bundle
        assert not any(uk["missing_mysteries"].values()), bundle
        missing = set().union(*map(set, uk["missing"].values()))
        assert missing == expected.get(bundle, set()), (bundle, missing)
        unique_gaps.update(missing)
        if missing:
            assert set(content[bundle]["$coverage"]["fallbackPrayerKeys"]) == missing
    assert len(unique_gaps) == 21
    print("PASS: 17 source excerpts, 12 Bible examples, 63 Scripture passages, all Ukrainian headings, and exactly 21 documented fallback bodies")


if __name__ == "__main__":
    main()

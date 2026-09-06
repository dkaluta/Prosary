#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Offline checks for the new sourced languages and dated intentions."""
import importlib.util
import json
import sys
import tempfile
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parents[1]
sys.path.insert(0, str(TOOLS))
spec = importlib.util.spec_from_file_location("scripture", TOOLS / "import-scripture.py")
scripture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scripture)

data = json.loads((ROOT / "Shared/data/pope-intentions.json").read_text())
assert set(data["months"]) == {f"{year}-{month:02d}" for year in (2026, 2027) for month in range(1, 13)}
for month, row in data["months"].items():
    languages = {"he", "ar", "fr", "it", "tl"} | ({"ru"} if month.startswith("2026") else set())
    for language in languages:
        for field in ("titleByLanguage", "textByLanguage"):
            text = row[field][language]
            assert text.strip() and "\ufffd" not in text, (month, language, field)
        if language != "he":
            assert row["sourceByLanguage"][language].startswith("https://")
    assert "Prosary" in row["translationCreditByLanguage"]["he"]
assert "santé des personnes" in data["months"]["2027-02"]["textByLanguage"]["fr"]
assert "osservatoreromano.va" in data["months"]["2027-02"]["sourceByLanguage"]["fr"]
assert "artificial intelligence" in data["months"]["2027-06"]["text"]
assert "больших городах" in data["months"]["2026-08"]["textByLanguage"]["ru"]
assert "ru" not in data["months"]["2027-01"]["textByLanguage"]  # no invented published Russian edition

for name in ("rosary", "angelus", "franciscanCrown"):
    bundle = ROOT / "Shared/content" / name
    assert {"fr", "it"} <= set(json.loads((bundle / "manifest.json").read_text())["languages"])
    for language in ("fr", "it"):
        text = json.loads((bundle / "content" / f"{language}.json").read_text())
        assert text["prayers"] and all(value.strip() for value in text["prayers"].values())
for language, edition in (("fr", "Crampon 1923"), ("it", "Martini")):
    text = json.loads((ROOT / "Shared/content/rosary/content" / f"{language}.json").read_text())
    assert len(text["$scriptureImport"]["mysteryKeys"]) == 20
    assert all(edition in text["mysteries"][key]["description"] for key in text["$scriptureImport"]["mysteryKeys"])
    assert text["$sources"] and text["$scriptureSource"]

# Source numbering, not array position, identifies Martini verses. No network in this test.
old_cache = scripture.CACHE
with tempfile.TemporaryDirectory() as directory:
    scripture.CACHE = Path(directory)
    (scripture.CACHE / "it-martini-lc-1.json").write_text(json.dumps({"c": 1, "v": [{"n": 27, "t": "second"}, {"n": 26, "t": "first"}]}))
    assert scripture.passage("it", "Luke", "nt", [(1, 26, 27)], "fixture") == "first second"
scripture.CACHE = old_cache
assert scripture.source_reference("fr", "Isaiah", [(9, 2, 2)], "fixture") == "9:1"
assert scripture.source_reference("it", "Isaiah", [(9, 2, 2)], "fixture") == "9:2"
for language in ("fr", "it", "es", "el", "arc"):
    merged = scripture.render(language, {"prayers": {}, "mysteries": {}, "transliterations": {}}, {"$comment": "Published prayer source", "$sources": ["https://example.test/source"]})
    assert merged["$comment"] == "Published prayer source" and merged["$sources"], language
    assert merged["$scriptureSource"] == scripture.NOTES[language], language
legacy = scripture.render("arc", {"prayers": {}, "mysteries": {}, "transliterations": {}}, {"$comment": scripture.NOTES["arc"]})
assert "$comment" not in legacy and legacy["$scriptureSource"] == scripture.NOTES["arc"]

# A known PrayerKey can still fall back to a different language. Check actual selected-
# language content for the newly completed flows, including every optional variant.
coverage_spec = importlib.util.spec_from_file_location("coverage", TOOLS / "audit-prayer-coverage.py")
coverage = importlib.util.module_from_spec(coverage_spec)
coverage_spec.loader.exec_module(coverage)
report = coverage.inventory()
for bundle, languages in {
    "rosary": ("es",),
    "angelus": ("es",),
    "divineMercyChaplet": ("es",),
    "franciscanCrown": ("es", "el"),
    "oAntiphons": ("fr", "it"),
    "trisagion": ("fr", "it", "es", "el"),
}.items():
    for language in languages:
        row = report["packs"][bundle][language]
        assert row["status"] == "advertised", (bundle, language)
        assert not any(row["missing"].values()), (bundle, language, row["missing"])
        assert not any(row["missing_mysteries"].values()), (bundle, language, row["missing_mysteries"])
assert not report["fixed_prayers"]["es"]["missing_prayer_bodies"]
for language in ("fr", "it"):
    stations = json.loads((ROOT / f"Shared/content/stationsOfTheCross/content/{language}.json").read_text())
    sourced = {"stationsOpeningPrayer"} | {f"station{number:02}Body" for number in range(1, 15)}
    assert all(stations["prayers"].get(key, "").strip() for key in sourced), language
    assert all(stations["$sources"].get(key, "").startswith("https://") for key in sourced), language

# The published medieval Syriac prayer must retain its paired square-script projection.
arc = json.loads((ROOT / "Shared/content/rosary/content/arc.json").read_text())
assert arc["prayers"]["subTuumPraesidium"] == scripture.to_hebrew(arc["transliterations"]["subTuumPraesidium"])
assert "Smelova" in arc["$comment"]
assert arc["prayers"]["repetitionCounterConnector"] == "מֶן"
assert arc["transliterations"]["repetitionCounterConnector"] == "ܡܶܢ"

for target in ("iOS/Prosary/Data", "Android/app/src/main/assets/data", "Windows/Prosary/Data"):
    for source in (ROOT / "Shared/data").glob("*.json"):
        assert source.read_bytes() == (ROOT / target / source.name).read_bytes(), (target, source.name)
print("Localized sourced content, intentions, numbering, provenance and data parity passed.")

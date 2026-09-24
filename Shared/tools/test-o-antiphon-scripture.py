#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Offline checks for O Antiphon source boundaries, numbering and prayer preservation."""
import importlib.util
import json
from pathlib import Path
import re

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("antiphon_import", TOOLS / "import-o-antiphon-scripture.py")
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)

assert importer.source_span("he", "oOriensLectio") == ("ISA", 9, 1, 1)
assert importer.source_span("ru", "oOriensLectio") == ("ISA", 9, 2, 2)
assert importer.source_span("tl", "oOriensLectio") == ("ISA", 9, 2, 2)

# Distinct per-verse tokens detect missing, repeated, reordered and misnumbered
# verses, independently of the text of the translations committed to the app.
corpus = {(book, chapter): {number: f"{book}.{chapter}.{number}" for number in range(1, 60)}
          for book, chapter in (("LUK", 1), ("ISA", 7), ("ISA", 9), ("ISA", 11), ("ISA", 22), ("ISA", 28))}
original_loader = importer.readings.load_source
try:
    importer.readings.load_source = lambda source: corpus
    original = {"prayers": {"oSapientiaBody": "Sourced antiphon, keep unchanged"}, "$prayerTraditionByKey": {"oSapientiaBody": "vicariate"}}
    rendered = importer.render("he", original)
    assert rendered["prayers"]["oOriensLectio"] == "ISA.9.1\n\n— ישעיהו ט׳ 1 (נוסח המסורה)"
    assert rendered["prayers"]["oSapientiaLectio"].startswith("ISA.11.2 ISA.11.3\n")
    assert rendered["prayers"]["magnificatBody"].split("\n\n— ")[0] == " ".join(f"LUK.1.{number}" for number in range(46, 56))
    assert rendered["prayers"]["oSapientiaBody"] == original["prayers"]["oSapientiaBody"]
    assert rendered["$prayerTraditionByKey"] == original["$prayerTraditionByKey"]
    assert len(original["prayers"]) == 1
    corpus["ISA", 11][2] = "רוּחַ יְהוָ֑ה׃"
    assert importer.render("he", {})["prayers"]["oSapientiaLectio"].startswith("רוּחַ יהוה׃ ISA.11.3")
    del corpus["ISA", 11][3]
    try:
        importer.render("ru", {})
    except KeyError:
        pass
    else:
        raise AssertionError("A missing source verse must fail instead of publishing a partial passage")
finally:
    importer.readings.load_source = original_loader

for language in ("he", "ru", "tl"):
    data = json.loads((importer.CONTENT / f"{language}.json").read_text())
    assert set(data["$scriptureImport"]["prayerKeys"]) == set(importer.PASSAGES)
    assert all(data["prayers"][key].strip() for key in importer.PASSAGES)
    assert all(source["sha256"] and "Public" in source["license"] for source in data["$scriptureImport"]["sources"])
he = json.loads((importer.CONTENT / "he.json").read_text())
assert "ישעיהו ט׳ 1 (נוסח המסורה)" in he["prayers"]["oOriensLectio"]
assert "לוקס א׳ 46–55 (דליטש, 1901)" in he["prayers"]["magnificatBody"]
for key in importer.PASSAGES:
    assert not re.search(r"י[\u0591-\u05c7]+ה[\u0591-\u05c7]*ו[\u0591-\u05c7]*ה", he["prayers"][key])
assert len(he["$prayerTraditionByKey"]) == 7
assert set(he["$prayerTraditionByKey"].values()) == {"vicariate"}
print("O Antiphon source numbering, verse boundaries, source pins and Hebrew tradition preservation passed.")

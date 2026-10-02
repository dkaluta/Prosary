#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf"]
# ///
"""Checks editorial intention snapshots, attribution, import boundaries and native copies."""
from copy import deepcopy
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "Shared/tools"
spec = importlib.util.spec_from_file_location("intentions", TOOLS / "import-pope-intentions.py")
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)
snapshot = json.loads((TOOLS / "pope-intentions-uk.json").read_text())
canonical_path = ROOT / "Shared/data/pope-intentions.json"
canonical = json.loads(canonical_path.read_text())

expected = {f"{year}-{month:02d}" for year in (2026, 2027) for month in range(1, 13)}
hebrew = {year: json.loads((TOOLS / f"pope-intentions-{year}-he.json").read_text())
          for year in ("2026", "2027")}
english_sources = {
    "2026": "https://www.usccb.org/prayers/popes-monthly-intentions-2026",
    "2027": "https://www.popesprayer.va/wp-content/uploads/2026/01/ENG-POPE-LEO-XIV-PRAYER-INTENTIONS-2027.pdf",
}
for month in expected:
    row = canonical["months"][month]
    annual = hebrew[month[:4]]
    for field in ("title", "text"):
        assert row[field + "ByLanguage"]["he"] == annual["months"][month][field], (month, field)
    assert row["sourceByLanguage"]["he"] == english_sources[month[:4]], month
    assert row["translationCreditByLanguage"]["he"] == "Prosary — Hebrew translation of the published intention"

# A fresh Hebrew import restores all 24 months without changing another language,
# the English originals, month identities, or other source/credit metadata.
without_hebrew = deepcopy(canonical)
for row in without_hebrew["months"].values():
    for field in ("titleByLanguage", "textByLanguage", "sourceByLanguage", "translationCreditByLanguage"):
        row[field].pop("he", None)
importer.merge_hebrew(without_hebrew, hebrew)
assert without_hebrew == canonical
importer.merge_hebrew(without_hebrew, hebrew)
assert without_hebrew == canonical  # Re-import is idempotent.


def reject_hebrew(invalid, label):
    destination = deepcopy(canonical)
    del destination["months"]["2026-01"]["sourceByLanguage"]["he"]
    before = deepcopy(destination)
    try:
        importer.merge_hebrew(destination, invalid)
    except ValueError:
        assert destination == before, label + ": partial mutation before rejection"
    else:
        raise AssertionError(label + " was accepted")


invalid = deepcopy(hebrew)
del invalid["2027"]["months"]["2027-12"]
reject_hebrew(invalid, "Incomplete Hebrew year")
reject_hebrew({"2027": hebrew["2027"]}, "Missing Hebrew year")
for source in (None, "", "http://www.usccb.org/prayers/popes-monthly-intentions-2026",
               "https://", "https://[broken", "https://www.usccb.org/invalid path"):
    invalid = deepcopy(hebrew)
    invalid["2027"]["source"] = source
    reject_hebrew(invalid, "Invalid Hebrew original source")
invalid = deepcopy(hebrew)
invalid["2027"]["credit"] = ""
reject_hebrew(invalid, "Uncredited Hebrew translation")
for field, value in (("title", " "), ("text", "\ufffd")):
    invalid = deepcopy(hebrew)
    invalid["2027"]["months"]["2027-12"][field] = value
    reject_hebrew(invalid, "Incomplete Hebrew " + field)

assert set(snapshot["months"]) == expected
for month, values in snapshot["months"].items():
    row = canonical["months"][month]
    for field in ("title", "text"):
        assert row[field + "ByLanguage"]["uk"] == values[field], (month, field)
    assert row["translationCreditByLanguage"]["uk"] == snapshot["credit"]
    assert "editorial Ukrainian" in row["translationCreditByLanguage"]["uk"]
    assert row["sourceByLanguage"]["uk"] == snapshot["sourceByYear"][month[:4]]

# The merge changes only the Ukrainian fields: existing English and independently sourced
# languages cannot be silently overwritten by an editorial translation.
merged = deepcopy(canonical)
importer.merge_ukrainian(merged, snapshot)
assert merged == canonical
invalid = deepcopy(snapshot)
del invalid["months"]["2027-12"]
try:
    importer.merge_ukrainian(deepcopy(canonical), invalid)
except ValueError:
    pass
else:
    raise AssertionError("Incomplete year was accepted")
invalid = deepcopy(snapshot)
invalid["credit"] = ""
try:
    importer.merge_ukrainian(deepcopy(canonical), invalid)
except ValueError:
    pass
else:
    raise AssertionError("Uncredited editorial translation was accepted")
for target in ("iOS/Prosary/Data", "Android/app/src/main/assets/data", "Windows/Prosary/Data"):
    assert (ROOT / target / canonical_path.name).read_bytes() == canonical_path.read_bytes(), target
print("Pope intentions: 24 Hebrew and 24 Ukrainian months, source/credit preservation, import guards and all3 copies pass")

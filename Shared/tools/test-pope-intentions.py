#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf"]
# ///
"""Checks the Ukrainian intention snapshot, attribution, import boundaries and pack copies."""
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
print("Pope intentions: 24 Ukrainian months, editorial/source attribution, import guards and all3 copies pass")

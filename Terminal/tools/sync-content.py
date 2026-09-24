#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Refresh the checked-in terminal snapshot; never needed by make or at runtime.

The existing coverage audit's Swift parser extracts native prayer tables. Canonical
pack JSON is copied without rewriting prayer wording. SHA-256 provenance pins every
source file. --check compares both generated text and provenance without writing.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "Terminal/data/content.json"
AUDIT = ROOT / "Shared/tools/audit-prayer-coverage.py"
ORDER = ("rosary", "angelus", "divineMercyChaplet", "franciscanCrown", "sevenSorrows",
         "stationsOfTheCross", "viaLucis", "trisagion", "oAntiphons", "litanyOfLoreto")

def snapshot() -> str:
    audit = runpy.run_path(str(AUDIT))
    sources: dict[str, str] = {}
    def record(path: Path) -> None:
        sources[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    def read(path: Path):
        record(path)
        return json.loads(path.read_text(encoding="utf-8"))
    record(AUDIT)
    record(Path(__file__))
    key_path = ROOT / "iOS/Prosary/Mocks/Content/PrayerKey.swift"
    record(key_path)
    import re
    fixed_keys = set(re.findall(r"^  case (\w+)", key_path.read_text(), re.M))
    common = {}
    for lang, name in audit["TABLES"].items():
        path = ROOT / f"iOS/Prosary/Mocks/Content/PrayerTranslations+{name}.swift"
        record(path)
        table = audit["swift_prayers"](path)
        if not table:
            raise ValueError(f"No native prayers parsed from {path}")
        if lang == "he":
            generic = {k: v for k, v in table.items() if k in {
                "decadeOrdinalFormat", "repetitionCounterConnector", "fructusMysteriiLabel"}}
            common["he"] = generic
            common["he-x-vicariate"] = {k: v for k, v in table.items() if k not in generic}
        else:
            common[lang] = table
    packs, mysteries = [], {}
    # Native loader order: Rosary first, other pack IDs in alphabetical order.
    loaded = {}
    for ident in ("rosary", *sorted(set(ORDER) - {"rosary"})):
        folder = ROOT / "Shared/content" / ident
        item = {"manifest": read(folder / "manifest.json"),
                "devotion": read(folder / "devotion.json"), "content": {}}
        for name in ("options", "catalog"):
            if (folder / f"{name}.json").exists():
                item[name] = read(folder / f"{name}.json")
        for path in sorted((folder / "content").glob("*.json")):
            lang, data = path.stem, read(path)
            item["content"][lang] = data
            marked = data.get("$prayerTraditionByKey", {})
            for key, value in data.get("prayers", {}).items():
                if key not in fixed_keys or not isinstance(value, str) or not value.strip():
                    continue
                target = "he-x-vicariate" if lang == "he" and marked.get(key) == "vicariate" else lang
                common.setdefault(target, {})[key] = value
            for key, fields in data.get("mysteries", {}).items():
                mysteries.setdefault(lang, {}).setdefault(key, {}).update(fields)
        loaded[ident] = item
    packs = [loaded[ident] for ident in ORDER]
    result = {"schemaVersion": 1,
              "provenance": {"generator": "Terminal/tools/sync-content.py",
                  "notes": "Exact sourced text; canonical packs plus native base prayers. Native Hebrew retains Vicariate provenance. Regenerate with uv; runtime needs only this JSON.",
                  "sources": dict(sorted(sources.items()))},
              "common": common, "mysteries": mysteries, "packs": packs}
    return json.dumps(result, ensure_ascii=False, indent=2) + "\n"

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    text = snapshot()
    if args.check:
        if not DEST.exists() or DEST.read_text(encoding="utf-8") != text:
            raise SystemExit("Terminal content is stale; run uv run --script Terminal/tools/sync-content.py")
        print("Terminal content and source hashes match.")
    else:
        DEST.parent.mkdir(parents=True, exist_ok=True)
        DEST.write_text(text, encoding="utf-8")
        print(f"Wrote {DEST.relative_to(ROOT)} ({len(text.encode('utf-8')):,} bytes).")
if __name__ == "__main__":
    main()

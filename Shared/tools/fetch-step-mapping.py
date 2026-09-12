#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Extract only reference metadata from pinned STEP Bible versification tables.

Neither Scripture nor explanatory note fields are retained. The pinned upstream
payload is read in memory and discarded; the generated numeric rules are CC BY 4.0.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import urllib.parse

DESTINATION = Path(__file__).resolve().parent / "versification/step"
COMMIT = "1f342173b881ba5d1a5a4cae6e7c6c3fcc7cac51"
LABEL = "Versification/TVTMS - Translators Versification Traditions with Methodology for Standardisation for Eng+Heb+Lat+Grk+Others - STEPBible.org CC BY.txt"
SOURCE_URL = f"https://raw.githubusercontent.com/STEPBible/STEPBible-Data/{COMMIT}/" + urllib.parse.quote(LABEL)
SOURCE_SHA256 = "63058e0f20201af4bdaa7d830da5be8f493455d947c5f147d84840b33db9ddf8"
ACTIONS = frozenset({"Keep verse", "Concatenation", "MergedNext verse", "Renumber verse",
    "MergedPrev verse", "IfEmpty verse", "DividedPrev verse", "DividedNext verse",
    "MovedFrom verse", "CopiedFrom verse", "Psalm title", "Renumber title"})


def extract(raw: bytes) -> dict[str, bytes]:
    if hashlib.sha256(raw).hexdigest() != SOURCE_SHA256:
        raise ValueError("STEP mapping source changed; review the new revision before accepting it")
    rows = []
    started = False
    for line_number, line in enumerate(raw.decode("utf-8-sig").splitlines(), 1):
        if line.startswith("SourceType\tSourceRef\tStandardRef\t"):
            started = True
            continue
        if not started:
            continue
        values = [value.strip() for value in line.split("\t")]
        if len(values) < 9 or not re.match(r"[A-Za-z1-9]{3}\.", values[1]) or ":" in values[0]:
            continue
        source_type, source, standard, action = values[:4]
        if action.rstrip("*") not in ACTIONS:
            raise ValueError(f"Unrecognized STEP mapping action at line {line_number}")
        # A strict character grammar excludes any Scripture/note content. The only
        # alphabetic reference components are book IDs, lettered chapters and the
        # metadata labels Title/TextBeforeV1; tests contain no quotation operands.
        for reference in (source, standard):
            if not re.fullmatch(r"[A-Za-z0-9.:!*+,;\-\s]+", reference):
                raise ValueError(f"Unexpected non-reference field at line {line_number}: {reference!r}")
        test = values[8]
        if not re.fullmatch(r"[A-Za-z0-9.:!=&<>*+\-\s]*", test):
            raise ValueError(f"Unexpected non-numeric test at line {line_number}")
        rows.append([line_number, source_type, source, standard, action, test])
    if len(rows) != 22874:
        raise ValueError(f"Expected the complete pinned table, found {len(rows)} rows")
    rules = {"schemaVersion": 1, "fields": ["sourceLine", "sourceType", "source", "standard", "action", "tests"], "rules": rows}
    encoded = (json.dumps(rules, ensure_ascii=False, separators=(",", ":")) + "\n").encode()
    provenance = {
        "schemaVersion": 1,
        "title": "STEP Bible Translators Versification Traditions with Methodology for Standardisation",
        "creator": "STEP Bible, based on work at Tyndale House Cambridge",
        "repository": "https://github.com/STEPBible/STEPBible-Data",
        "commit": COMMIT,
        "sourceURL": SOURCE_URL,
        "sourceSHA256": SOURCE_SHA256,
        "license": "CC BY 4.0",
        "licenseURL": "https://creativecommons.org/licenses/by/4.0/",
        "attributionURL": "https://www.STEPBible.org",
        "rulesSHA256": hashlib.sha256(encoded).hexdigest(),
        "ruleCount": len(rows),
        "adaptation": "Only source/standard references, tradition labels, actions, numeric tests and original line numbers are retained. Scripture, notes, examples and explanatory prose are excluded. No mapping values are changed.",
    }
    return {"rules.json": encoded, "sources.json": (json.dumps(provenance, indent=2) + "\n").encode()}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify regenerated metadata without writing")
    args = parser.parse_args()
    # Curl honors the platform's network/proxy configuration. The response remains
    # transient and is never written to a source cache.
    raw = subprocess.check_output(["curl", "--location", "--fail", "--silent", "--show-error", "--max-time", "60", SOURCE_URL])
    outputs = extract(raw)
    for name, content in outputs.items():
        path = DESTINATION / name
        if args.check:
            if not path.exists() or path.read_bytes() != content:
                raise ValueError(f"Generated STEP metadata differs: {path}")
        else:
            DESTINATION.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
    print("Verified 22,874 STEP reference-only mapping rules." if args.check else "Wrote 22,874 STEP reference-only mapping rules.")


if __name__ == "__main__":
    main()

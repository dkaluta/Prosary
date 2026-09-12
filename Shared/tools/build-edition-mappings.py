#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Build reference-only inventories from existing pinned Bible imports.

Only verse identifiers, word counts, hashes and reviewed unit references are
written. Source wording remains in the existing source cache and reader pipeline.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

from reading_edition_mapping import (DIRECTORY, EDITION_IDS, METHOD, REVIEW_FILES,
                                    EditionMapper, corpus_digest)

TOOLS = Path(__file__).resolve().parent


def encoded(value: dict) -> bytes:
    return (json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n").encode()


def build(fetch: bool = False) -> dict[str, bytes]:
    spec = importlib.util.spec_from_file_location("edition_text_importer", TOOLS / "build-reading-texts.py")
    importer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(importer)
    lock, corpora = importer.load_pinned_corpora(fetch)
    pins = {source["id"]: source["sha256"] for source in lock["sources"]}
    records, coverage = {}, {}
    for edition in lock["editions"]:
        edition_id = edition["id"]
        corpus = corpora[edition_id]
        record = {
            "sourcePins": {source["id"]: pins[source["id"]] for source in edition["sources"]},
            "corpusSHA256": corpus_digest(corpus),
            "systems": {"ot": edition["otSystem"], "nt": edition["ntSystem"]},
            "chapters": [[book, chapter, [[verse, len(words.split())] for verse, words in sorted(values.items())]]
                         for (book, chapter), values in sorted(corpus.items())],
        }
        if edition_id == "jesuit-arabic-1897":
            from reading_edition_reviews_arabic import ReviewedArabicMapper, reference_metadata
            ReviewedArabicMapper(corpus, record["sourcePins"])
            record["arabicMetadata"] = reference_metadata()
        subject = EditionMapper(edition_id, record)
        subject.validate_source(corpus, record["sourcePins"])
        records[edition_id] = record
        coverage[edition_id] = {"books": len({key[0] for key in corpus}),
                               "chapters": len(corpus), **subject.coverage()}
    if set(records) != EDITION_IDS:
        raise ValueError("Every bundled edition needs a reviewed reference profile")
    inventory = encoded({"schemaVersion": 1, "standard": "STEP", "method": METHOD, "editions": records})
    provenance = {
        "schemaVersion": 1, "inventorySHA256": hashlib.sha256(inventory).hexdigest(),
        "reviewFiles": {name: hashlib.sha256((TOOLS / name).read_bytes()).hexdigest() for name in REVIEW_FILES},
        "coverage": coverage,
    }
    return {"inventories.json": inventory,
            "sources.json": (json.dumps(provenance, indent=2, ensure_ascii=False) + "\n").encode()}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify deterministic committed metadata")
    parser.add_argument("--fetch", action="store_true", help="Fetch only the existing pinned reader sources")
    args = parser.parse_args()
    outputs = build(args.fetch)
    if args.check:
        for name, contents in outputs.items():
            if not (DIRECTORY / name).exists() or (DIRECTORY / name).read_bytes() != contents:
                raise SystemExit(f"Stale edition mapping metadata: {name}")
    else:
        DIRECTORY.mkdir(parents=True, exist_ok=True)
        for name, contents in outputs.items():
            (DIRECTORY / name).write_bytes(contents)
    print("Verified" if args.check else "Built", "numeric reference metadata for all eight bundled editions.")


if __name__ == "__main__":
    main()

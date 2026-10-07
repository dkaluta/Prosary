#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Frozen, source-pinned Psalm bodies; no chapter offset or fuzzy runtime match.

The independent witness supplies reference evidence only. The reader continues to
display the original pointed website text and its existing Hebrew projection.
Unreviewed source verses have no edge, even when a chapter's total happens to match.
"""
from functools import lru_cache
import json
from pathlib import Path
import re

from peshitta_eu_source import review as website_review
from reading_psalm_mapping import hebrew_psalm_to_standard

TOOLS = Path(__file__).resolve().parent
REVIEW_PATH = TOOLS / "peshitta-eu-2020-psalm-review.json"
_HASH = re.compile(r"[0-9a-f]{64}")
METHODS = {"exact-segmented-consonantal-body", "reviewed-source-variant",
           "complete-reviewed-boundary-envelope"}


def _references(values):
    if (not isinstance(values, list) or not values or any(
            not isinstance(ref, list) or len(ref) != 3 or ref[0] != "PSA"
            or any(type(number) is not int or number < 1 for number in ref[1:])
            for ref in values)):
        raise ValueError("Malformed reviewed Peshitta Psalm coordinates")
    result = tuple(tuple(ref) for ref in values)
    if result != tuple(sorted(set(result))):
        raise ValueError("Unordered or repeated Peshitta Psalm coordinates")
    return result


def validate_review(value, source_lock, website):
    if (value.get("schemaVersion") != 1 or value.get("editionId") != "peshitta-1905"
            or value.get("sourcePinDigest") != website["sourcePinDigest"]
            or value.get("corpusSHA256") != website["corpusSHA256"]
            or not _HASH.fullmatch(value.get("witness", {}).get("sha256", ""))):
        raise ValueError("Peshitta Psalm review differs from its pinned source")
    pins = {source["id"]: source["sha256"] for source in source_lock["sources"]
            if source.get("format") == "peshitta-eu-2020" and source.get("book") == "PSA"}
    declared = value.get("sourceChapterPins", {})
    if not declared or any(pins.get(key) != digest for key, digest in declared.items()):
        raise ValueError("Reviewed Peshitta Psalm response changed")
    inventory = value.get("sourceChapterInventory", {})
    if (not inventory or any(not chapter.isdecimal() or not 1 <= int(chapter) <= 150
            or type(maximum) is not int or maximum < 1 for chapter, maximum in inventory.items())):
        raise ValueError("Malformed Peshitta Psalm inventory")
    source_domain = {("PSA", int(chapter), verse) for chapter, maximum in inventory.items()
                     for verse in range(1, maximum + 1)}
    allowed = set()
    witnesses = set()
    overrides = {reference: () for reference in source_domain}
    units = value.get("units", [])
    if not units:
        raise ValueError("Empty Peshitta Psalm boundary review")
    for unit in units:
        sources = _references(unit["sourceReferences"])
        witness_refs = _references(unit["witnessReferences"])
        targets = _references(unit["standardReferences"])
        if (not set(sources) <= source_domain or set(sources) & allowed
                or set(witness_refs) & witnesses or unit.get("method") not in METHODS
                or not unit.get("note") or len({ref[1] for ref in sources}) != 1
                or any(f"peshitta-eu-2020-psa-{ref[1]}" not in declared for ref in sources)):
            raise ValueError("Incomplete, overlapping or unpinned Peshitta Psalm unit")
        for refs, field in ((sources, "sourceVerseSHA256"), (witness_refs, "witnessVerseSHA256")):
            hashes = unit.get(field, [])
            if len(hashes) != len(refs) or any(not _HASH.fullmatch(digest) for digest in hashes):
                raise ValueError("Peshitta Psalm unit lost its textual boundary evidence")
        bridged, _ = hebrew_psalm_to_standard(list(witness_refs))
        if tuple(bridged) != targets:
            raise ValueError("Peshitta Psalm witness bridge differs from its frozen review")
        allowed.update(sources)
        witnesses.update(witness_refs)
        overrides.update({source: targets for source in sources})
    return allowed, overrides


@lru_cache(maxsize=1)
def reviewed_mapping():
    value = json.loads(REVIEW_PATH.read_text())
    lock = json.loads((TOOLS / "reading-text-sources.json").read_text())
    return validate_review(value, lock, website_review())

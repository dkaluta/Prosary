#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Compare Hebrew OCR with a credited transcription without replacing either text.

Use scripture-only, explicitly aligned page/chapter excerpts. Wikisource verse
numbers do not establish correspondence with a different printed edition. This
tool reports differences and matching spans; it never imports or corrects text.
"""
from __future__ import annotations

import argparse
from array import array
import hashlib
import json
from pathlib import Path
import re
import unicodedata


def tokens(text: str) -> list[str]:
    # Niqqud/cantillation are ignored only in the comparison. Keep consonants,
    # spelling, final letters, numbers and non-Hebrew OCR noise observable.
    unpointed = "".join(c for c in unicodedata.normalize("NFKD", text)
                       if unicodedata.category(c) != "Mn")
    return re.findall(r"[^\W_]+", unpointed, re.UNICODE)


def align(reference: list[str], observed: list[str]) -> list[dict]:
    """Minimum word-edit alignment, preserving both input sequences and offsets."""
    n, m = len(reference), len(observed)
    if (n + 1) * (m + 1) > 8_000_000:
        raise ValueError("Align one page/chapter excerpt at a time, not a whole volume")
    directions = [bytearray(m + 1) for _ in range(n + 1)]
    previous = array("I", range(m + 1))
    for j in range(1, m + 1):
        directions[0][j] = 3
    for i in range(1, n + 1):
        current = array("I", [i])
        directions[i][0] = 2
        for j in range(1, m + 1):
            diagonal = previous[j - 1] + (reference[i - 1] != observed[j - 1])
            deletion, insertion = previous[j] + 1, current[j - 1] + 1
            cost = min(diagonal, deletion, insertion)
            directions[i][j] = 1 if cost == diagonal else 2 if cost == deletion else 3
            current.append(cost)
        previous = current
    steps = []
    i, j = n, m
    while i or j:
        direction = directions[i][j]
        if direction == 1:
            i, j = i - 1, j - 1
            kind = "equal" if reference[i] == observed[j] else "replace"
            steps.append((kind, i, j, 1, 1))
        elif direction == 2:
            i -= 1
            steps.append(("delete", i, j, 1, 0))
        else:
            j -= 1
            steps.append(("insert", i, j, 0, 1))
    segments = []
    for kind, i, j, a, b in reversed(steps):
        if segments and segments[-1]["kind"] == kind:
            segment = segments[-1]
            segment["referenceEnd"] = i + a
            segment["observedEnd"] = j + b
        else:
            segments.append({"kind": kind, "referenceStart": i, "referenceEnd": i + a,
                             "observedStart": j, "observedEnd": j + b})
    for segment in segments:
        segment["reference"] = reference[segment["referenceStart"]:segment["referenceEnd"]]
        segment["observed"] = observed[segment["observedStart"]:segment["observedEnd"]]
    return segments


def compare(reference: str, observed: str, relationship: str,
            reference_status: str = "unreviewed") -> dict:
    if relationship not in {"same-translation", "related-translation", "scan-transcription"}:
        raise ValueError("Declare the reference's relationship to the printed source")
    if reference_status not in {"unreviewed", "scan-checked"}:
        raise ValueError("Unknown reference review status")
    expected, actual = tokens(reference), tokens(observed)
    if not expected or not actual:
        raise ValueError("Both aligned excerpts must contain text")
    segments = align(expected, actual)
    counts = {kind: 0 for kind in ("equal", "replace", "delete", "insert")}
    for segment in segments:
        counts[segment["kind"]] += max(len(segment["reference"]), len(segment["observed"]))
    differences = counts["replace"] + counts["delete"] + counts["insert"]
    result = {
        "schemaVersion": 1, "purpose": "review-only", "relationship": relationship,
        "referenceStatus": reference_status, "productionEligible": False,
        "referenceSHA256": hashlib.sha256(reference.encode()).hexdigest(),
        "observedSHA256": hashlib.sha256(observed.encode()).hexdigest(),
        "normalization": "Combining marks and punctuation removed for comparison only; spelling preserved.",
        "referenceWords": len(expected), "observedWords": len(actual),
        "wordOperations": counts,
        "matchingReferenceFraction": counts["equal"] / len(expected),
        "tokenDifferenceRate": differences / len(expected),
        "alignment": segments,
        "notes": ["An alignment is a review aid, not a verified verse crosswalk.",
                  "Niqqud and punctuation still require separate image comparison."],
    }
    if relationship != "related-translation" and reference_status == "scan-checked":
        result["consonantalWordErrorRate"] = differences / len(expected)
    else:
        result["notes"].append("Text differences are not an OCR accuracy measurement without a scan-checked matching reference.")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--observed", type=Path, required=True)
    parser.add_argument("--relationship", required=True,
                        choices=["same-translation", "related-translation", "scan-transcription"])
    parser.add_argument("--reference-status", default="unreviewed",
                        choices=["unreviewed", "scan-checked"])
    parser.add_argument("--source-url")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.resolve() in {args.reference.resolve(), args.observed.resolve()}:
        parser.error("A comparison report must not overwrite either source")
    report = compare(args.reference.read_text(), args.observed.read_text(),
                     args.relationship, args.reference_status)
    if args.source_url:
        report["sourceURL"] = args.source_url
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({key: report[key] for key in ("relationship", "referenceWords",
                     "observedWords", "wordOperations", "tokenDifferenceRate")}, ensure_ascii=False))


if __name__ == "__main__":
    main()

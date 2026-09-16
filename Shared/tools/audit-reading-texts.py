#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Audit every emitted reader verse against its pinned source without resolving citations.

The full source cache is required. This verifies source fidelity, availability
accounting and native-copy parity; numerical/semantic mapping reviews are separate.
"""

from __future__ import annotations

import argparse
import collections
import hashlib
import importlib.util
import json
from pathlib import Path
import re

from peshitta_reading_source import paired_text
from reading_appointment_reviews import reviewed_appointment, reviewed_references
from reading_source_numbering_reviews import reviewed_numbering

ROOT = Path(__file__).resolve().parents[2]


def load_builder():
    """Reuse hash-checked source importers, never the passage resolver."""
    specification = importlib.util.spec_from_file_location(
        "reading_source_audit_builder", ROOT / "Shared/tools/build-reading-texts.py"
    )
    builder = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(builder)
    return builder


def audit() -> dict:
    """Compare emitted source rows and reconcile every edition/citation decision."""
    builder = load_builder()
    lock, corpora = builder.load_pinned_corpora()
    raw = (builder.DATA / "readings-texts.json").read_bytes()
    data = json.loads(raw)
    report = json.loads(
        (ROOT / "Shared/reports/readings-text-coverage.json").read_text()
    )
    metadata = json.loads((builder.DATA / "readings-editions.json").read_text())
    appointments = builder.appointments()
    editions = {row["id"]: row for row in lock["editions"]}
    whole = data["wholeVersePassages"]
    passages = data["passages"]
    unavailable = report["unavailable"]
    errors = []

    def check(condition, message):
        if not condition:
            errors.append(message)

    check(
        data["editions"] == metadata["editions"],
        "edition metadata differs from companion",
    )
    check(
        {x["id"] for x in data["editions"]} == set(editions),
        "metadata edition registry mismatch",
    )
    check(set(passages) <= set(appointments), "unappointed passage key")
    check(len(whole) == len(set(whole)), "duplicate whole-verse keys")
    check(set(whole) <= set(passages), "whole-verse flag lacks available passage")
    check(
        report["uniqueAppointments"] == len(appointments), "appointment count mismatch"
    )
    check(
        report["passagesWithAnyEdition"] == len(passages), "any-edition count mismatch"
    )
    check(set(unavailable) <= set(appointments), "unappointed unavailable key")
    summary = {eid: collections.Counter() for eid in editions}
    contexts = {}
    routes = collections.Counter()
    verse_count = 0
    source_unique = collections.defaultdict(set)
    for eid, corpus in corpora.items():
        builder.edition_mapper(eid, corpus).validate_source(corpus, corpus.source_pins)
    for key, calendar_contexts in appointments.items():
        available = passages.get(key, {})
        missing = unavailable.get(key, {})
        check(not (set(available) & set(missing)), f"availability conflict {key}")
        check(
            set(available) | set(missing) == set(editions),
            f"edition availability complement mismatch {key}",
        )
        scope, citation = key.split("|", 1)
        book_name = citation.split(":", 1)[0].rsplit(" ", 1)[0]
        book = builder.BOOKS.get(book_name)
        if available:
            check(book is not None, f"unknown emitted book {key}")
            if re.search(r"\d[a-d]", citation):
                check(key in whole, f"missing partial-verse notice {key}")
            if reviewed_appointment(key, calendar_contexts):
                routes["exactEditionReview"] += 1
            elif numbering := reviewed_numbering(key, calendar_contexts):
                routes[numbering["sourceSystem"]] += 1
            else:
                routes["legacyAgreement"] += 1
        for context in calendar_contexts:
            cell = contexts.setdefault(
                context,
                {
                    "appointments": 0,
                    "availableAnyEdition": 0,
                    "editions": collections.Counter(),
                },
            )
            cell["appointments"] += 1
            cell["availableAnyEdition"] += bool(available)
            for eid in available:
                cell["editions"][eid] += 1
        for eid, reason in missing.items():
            check(
                isinstance(reason, str) and bool(reason.strip()),
                f"empty unavailable reason {key}/{eid}",
            )
            summary[eid]["unavailable"] += 1
        for eid, rows in available.items():
            edition = editions[eid]
            corpus = corpora[eid]
            mapper = builder.edition_mapper(eid, corpus)
            seen = set()
            check(isinstance(rows, list) and bool(rows), f"empty passage {key}/{eid}")
            summary[eid][scope] += 1
            summary[eid]["passages"] += 1
            review = reviewed_appointment(key, calendar_contexts)
            if review:
                if review["includesWholeVerses"]:
                    check(key in whole, f"missing reviewed whole-verse notice {key}")
                check(
                    [(book, r["chapter"], r["verse"]) for r in rows]
                    == [tuple(r) for r in reviewed_references(review, eid)],
                    f"edition-boundary review differs {key}/{eid}",
                )
            for row in rows:
                check(
                    type(row["chapter"]) is int
                    and type(row["verse"]) is int
                    and row["chapter"] > 0
                    and row["verse"] > 0,
                    f"invalid label {key}/{eid}",
                )
                ref = (book, row["chapter"], row["verse"])
                check(ref not in seen, f"duplicate source row {key}/{eid}/{ref}")
                seen.add(ref)
                check(
                    ref[:2] not in mapper.excluded_chapters,
                    f"blocked source chapter emitted {key}/{eid}/{ref}",
                )
                original = corpus.get(ref[:2], {}).get(ref[2])
                check(
                    isinstance(original, str) and bool(original.strip()),
                    f"missing source row {key}/{eid}/{ref}",
                )
                if not isinstance(original, str):
                    continue
                if edition["languageCode"] == "he":
                    expected = builder.preserve_divine_name_accents(original)
                elif eid == "peshitta-1905":
                    expected, syriac = paired_text(original)
                    check(
                        row.get("transliteratedText") == syriac,
                        f"Syriac source changed {key}/{eid}/{ref}",
                    )
                else:
                    expected = original
                check(
                    row["text"] == expected, f"source text mismatch {key}/{eid}/{ref}"
                )
                if eid != "peshitta-1905":
                    check(
                        "transliteratedText" not in row,
                        f"unexpected alternate script {key}/{eid}/{ref}",
                    )
                source_unique[eid].add(ref)
                verse_count += 1
                summary[eid]["verseEntries"] += 1
    for eid, counts in summary.items():
        for scope in ("daily", "torah"):
            check(
                counts[scope] == report["coverage"][eid][scope],
                f"coverage count mismatch {eid}/{scope}",
            )
        reasons = collections.Counter(
            rows[eid] for rows in unavailable.values() if eid in rows
        )
        check(
            dict(reasons) == report["coverage"][eid]["unavailableReasons"],
            f"unavailable reasons mismatch {eid}",
        )
        counts["uniqueSourceVerses"] = len(source_unique[eid])
    for name in ("readings-editions.json", "readings-texts.json"):
        canonical = (builder.DATA / name).read_bytes()
        for target in builder.TARGETS:
            check(
                (target / name).read_bytes() == canonical,
                f"native copy mismatch {target / name}",
            )
    result = {
        "schemaVersion": 1,
        "corpusSHA256": hashlib.sha256(raw).hexdigest(),
        "appointmentCount": len(appointments),
        "editionCount": len(editions),
        "appointmentEditionPairs": len(appointments) * len(editions),
        "emittedPassages": sum(x["passages"] for x in summary.values()),
        "verseEntries": verse_count,
        "wholeVersePassageKeys": len(whole),
        "availablePassageKeys": len(passages),
        "unavailablePassageKeys": len(appointments) - len(passages),
        "sourceResolutionRoutes": dict(routes),
        "editions": {k: dict(v) for k, v in summary.items()},
        "calendarContexts": contexts,
        "errors": errors,
        "limits": [
            "Source fidelity and exact retained review checks cover every emitted verse. Numeric transformation properties and regression suites are audited separately.",
            "The audit does not establish semantic equivalence for all unreviewed Bible mappings or add unavailable source text.",
        ],
    }

    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--report",
        type=Path,
        help="Write numeric audit results as JSON; never includes source wording",
    )
    arguments = parser.parse_args()
    result = audit()
    if arguments.report:
        arguments.report.write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n"
        )
    print(
        f"Audited {result['appointmentCount']} appointments across {result['editionCount']} editions: "
        f"{result['emittedPassages']:,} passages, {result['verseEntries']:,} verse entries, "
        f"{len(result['errors'])} source-fidelity errors."
    )
    if result["errors"]:
        print("\n".join(result["errors"]))
        raise SystemExit(1)


if __name__ == "__main__":
    main()

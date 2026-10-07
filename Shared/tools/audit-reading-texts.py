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
from reading_appointment_keys import split_passage_key, registry_datasets, passage_key
from reading_calendar_numbering import profile_for, chapter_system, standard_units

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
    registered = registry_datasets(builder.DATA)
    check(set(report.get("readingDatasets", {})) == set(registered),
          "coverage omitted or invented a registered reading table")
    for identifier, registration in registered.items():
        path = builder.DATA / (registration["file"] + ".json")
        table = json.loads(path.read_text()) if path.exists() else {}
        rows = [reading for day in table.get("days", {}).values() for reading in day.get("readings", [])]
        keys = {passage_key(row["full"], identifier) for row in rows}
        actual = report.get("readingDatasets", {}).get(identifier, {})
        expected = {"file": registration["file"], "calendarIds": sorted(registration["calendarIds"]),
                    "hasTable": path.exists(), "appointmentRows": len(rows), "uniqueAppointments": len(keys),
                    "uniquePsalmAppointments": sum(split_passage_key(key)[1].startswith("Psalm ") for key in keys),
                    "sourceURL": table.get("sourceUrl"), "sourceSHA256": table.get("sourceSha256")}
        check(all(actual.get(field) == value for field, value in expected.items()),
              f"registered table provenance or appointment inventory differs: {identifier}")
        for eid in editions:
            missing_keys = [key for key in keys if eid not in passages.get(key, {})]
            counts = actual.get("coverage", {}).get(eid, {})
            check(counts.get("available") == len(keys) - len(missing_keys)
                  and counts.get("unavailable") == len(missing_keys)
                  and counts.get("reasons") == dict(collections.Counter(
                      unavailable.get(key, {}).get(eid, "no available source") for key in missing_keys)),
                  f"registered table per-edition coverage differs: {identifier}/{eid}")
    summary = {eid: collections.Counter() for eid in editions}
    contexts = {}
    routes = collections.Counter()
    verse_count = 0
    source_unique = collections.defaultdict(set)
    from reading_supplement_audit import audit_psalm_supplements
    try:
        routes.update(audit_psalm_supplements(data, appointments, builder))
    except ValueError as error:
        check(False, str(error))
    from arabic_daily_psalms import default_resolver as arabic_source_resolver
    arabic = arabic_source_resolver()
    from hebrew_deuterocanon import load_books
    supplements, _ = load_books()
    from greek_daily_psalms import default_resolver as greek_source_resolver
    greek = greek_source_resolver()
    from martini_daily_psalms import default_resolver as martini_source_resolver
    martini = martini_source_resolver()
    from peshitta_daily_psalms import default_resolver as peshitta_source_resolver
    bounded_peshitta = peshitta_source_resolver()
    supplement_rows = {(source["book"], chapter["number"], row["verse"]):
        {"chapter":chapter["number"], "verse":row["verse"],
         "text":builder.preserve_divine_name_accents(row["text"]),
         **{field:row[field] for field in ("endVerse", "sourceNotes") if field in row}}
        for source in supplements for chapter in source["chapters"] for row in chapter["verses"]}
    expected_books = {}
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
        scope, citation, dataset = split_passage_key(key)
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
            elif dataset is not None and book == "PSA":
                routes["registeredCalendarPsalmProfile"] += 1
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
            descriptor = data.get("passageSources", {}).get(key, {}).get(eid)
            source_book = descriptor["book"] if descriptor is not None else book
            expected_books.setdefault(key, {})[eid] = source_book
            seen = set()
            check(isinstance(rows, list) and bool(rows), f"empty passage {key}/{eid}")
            summary[eid][scope] += 1
            summary[eid]["passages"] += 1
            review = reviewed_appointment(key, calendar_contexts)
            greek_review = greek.reviews.get(key) if eid == "brenton-lxx" and descriptor is not None else None
            martini_review = martini.reviews.get(key) if eid == "martini" and descriptor is not None else None
            martini_scoped = eid == "martini" and descriptor is not None and dataset is not None and book == "PSA"
            peshitta_review = bounded_peshitta.reviews.get(key) if eid == "peshitta-1905" else None
            if martini_scoped:
                calendar_profile = profile_for(dataset, calendar_contexts)
                _, spans = builder.parse_citation(citation, expand_subverses=True,
                    psalm_chapter_system=chapter_system(calendar_profile))
                requested, source_whole = standard_units(citation, spans, calendar_profile)
                wanted = set(requested)
                expected_native, covered = set(), set()
                for chapter, group in martini.whole_standard_groups.items():
                    if group <= wanted:
                        expected_native.update(martini.whole_chapters[chapter])
                        covered.update(group)
                remaining = wanted - covered
                for coordinate, targets in martini.boundaries.items():
                    if targets & remaining:
                        expected_native.add(coordinate)
                        covered.update(targets)
                check(wanted <= covered, f"Italian scoped Psalm exceeds inspected source boundaries {key}")
                check([(row["chapter"], row["verse"]) for row in rows] == sorted(expected_native),
                      f"Italian scoped Psalm native source sequence changed {key}")
                check(descriptor.get("book") == "PSA" and descriptor.get("isComplete") is True
                      and descriptor.get("sourceURL") == "https://parolaviva.art/opendata"
                      and "Giovanni Novelli / Parola Viva" in descriptor.get("attribution", ""),
                      f"Italian scoped Psalm source credit changed {key}")
                if source_whole or covered - wanted:
                    check(key in whole, f"Italian scoped Psalm wider units lack a notice {key}")
            if martini_review:
                check(bool(calendar_contexts) and calendar_contexts <= set(martini_review["contexts"]),
                      f"Italian supplement escaped its calendar review {key}")
                check([(row["chapter"], row["verse"]) for row in rows]
                      == [tuple(ref) for ref in martini_review["sourceReferences"]],
                      f"Italian supplement source sequence changed {key}")
                check(descriptor.get("book") == "PSA" and descriptor.get("isComplete") is True
                      and descriptor.get("sourceURL") == "https://parolaviva.art/opendata"
                      and "Giovanni Novelli / Parola Viva" in descriptor.get("attribution", ""),
                      f"Italian supplement source credit changed {key}")
                if martini_review["includesWholeVerses"]:
                    check(key in whole, f"missing Italian whole-unit notice {key}")
            if greek_review:
                chapter = greek_review["sourceChapter"]
                labels = greek_review["sourceLabels"]
                check(bool(calendar_contexts) and calendar_contexts <= set(greek_review["contexts"]),
                      f"Greek supplement escaped its calendar review {key}")
                check([(row["chapter"], str(row["verse"])) for row in rows]
                      == [(chapter, label) for label in labels if label.isdigit()],
                      f"Greek supplement source sequence changed {key}")
                expected_blocks = []
                for label in labels:
                    block_id = f"grcbrent-psa-{chapter}-{label}"
                    expected_blocks.append({"id": block_id, "kind": "witness", "text": greek.rows[chapter, label],
                        "printedLabel": label, "addresses": [{"chapter": chapter, "verse": int(label[:-1]), "part": "a"}]}
                        if label.endswith("a") else {"id": block_id, "kind": "verse", "chapter": chapter, "verse": int(label)})
                check(descriptor.get("book") == "PSA" and descriptor.get("contentBlocks") == expected_blocks
                      and descriptor.get("isComplete") == greek_review["isComplete"]
                      and descriptor.get("sourceURL") == f"https://ebible.org/grcbrent/PSA{chapter:03d}.htm",
                      f"Greek supplement printed source blocks changed {key}")
                if greek_review["includesWholeVerses"]:
                    check(key in whole, f"missing Greek whole-verse notice {key}")
            elif (review and not martini_review and not peshitta_review
                  and not (eid == "jesuit-arabic-1897" and descriptor is not None)
                  and not (eid == "peshitta-1905" and not reviewed_references(review, eid)
                           and reviewed_numbering(key, calendar_contexts) is not None)):
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
                ref = (source_book, row["chapter"], row["verse"])
                check(ref not in seen, f"duplicate source row {key}/{eid}/{ref}")
                seen.add(ref)
                if descriptor is not None and eid == "jesuit-arabic-1897":
                    check(row == {"chapter": ref[1], "verse": ref[2], "text": arabic.rows.get((ref[1], ref[2]))},
                          f"Arabic Psalm printed source row changed {key}/{ref}")
                    source_unique[eid].add(ref)
                    verse_count += 1
                    summary[eid]["verseEntries"] += 1
                    continue
                if descriptor is not None and eid == "masoretic-delitzsch":
                    check(row == supplement_rows.get(ref), f"reviewed supplement source unit changed {key}/{eid}/{ref}")
                    source_unique[eid].add(ref)
                    verse_count += 1
                    summary[eid]["verseEntries"] += 1
                    continue
                if descriptor is not None and eid == "brenton-lxx":
                    check(row == {"chapter": ref[1], "verse": ref[2], "text": greek.rows.get((ref[1], str(ref[2])))},
                          f"reviewed Greek supplement source unit changed {key}/{ref}")
                    source_unique[eid].add(ref)
                    verse_count += 1
                    summary[eid]["verseEntries"] += 1
                    continue
                if martini_review:
                    check(row == {"chapter": ref[1], "verse": ref[2],
                                  "text": martini.rows.get((ref[1], ref[2]))},
                          f"reviewed Italian supplement source unit changed {key}/{ref}")
                    source_unique[eid].add(ref)
                    verse_count += 1
                    summary[eid]["verseEntries"] += 1
                    continue
                if martini_scoped:
                    check(row == {"chapter": ref[1], "verse": ref[2],
                                  "text": martini.rows.get((ref[1], ref[2]))},
                          f"Italian scoped Psalm literal source wording changed {key}/{ref}")
                    source_unique[eid].add(ref)
                    verse_count += 1
                    summary[eid]["verseEntries"] += 1
                    continue
                if peshitta_review:
                    primary, syriac = paired_text(bounded_peshitta.rows.get(ref[2], ""))
                    check(ref[1] == 118 and row == {"chapter": 118, "verse": ref[2],
                        "text": primary, "transliteratedText": syriac},
                        f"Peshitta bounded Psalm literal source scripts changed {key}/{ref}")
                    check([row["verse"] for row in rows] == peshitta_review["sourceVerses"],
                          f"Peshitta bounded Psalm source sequence changed {key}")
                    check(not peshitta_review["includesWholeVerses"] or key in whole,
                          f"Peshitta bounded Psalm wider units lack a notice {key}")
                    source_unique[eid].add(ref)
                    verse_count += 1
                    summary[eid]["verseEntries"] += 1
                    continue
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
    check(data.get("passageBooks") == expected_books, "reviewed native Bible source book map differs or has orphaned entries")
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

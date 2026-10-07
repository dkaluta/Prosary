#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Audit every bundled reading against the pinned numeric reference graphs.

Run with uv; --texts accepts an alternate artifact for regression checks without
changing canonical data. This checks numeric coverage, review scope and edition
agreement. It does not certify a new word-by-word alignment of Bible editions;
source-text integrity remains the responsibility of the reading build checks.
"""
from __future__ import annotations

import argparse
from collections import Counter
import importlib.util
import json
from pathlib import Path

from reading_appointment_reviews import (
    CALENDARS, load_reviews as appointment_reviews, reviewed_appointment,
    reviewed_references,
)
from reading_edition_mapping import mapper
from reading_nabre_mapping import mapper as nabre_mapper
from reading_psalm_mapping import hebrew_psalm_to_standard
from reading_source_numbering_reviews import (
    load_reviews as numbering_reviews, reviewed_numbering,
)
from reading_step_mapping import Unavailable
from peshitta_supplied_ot import BOOKS as PESHITTA_OT_BOOKS
from reading_versification import chapter_verse_count
from reading_appointment_keys import split_passage_key
from reading_calendar_numbering import profile_for, chapter_system, standard_units
from hebrew_daily_readings import default_resolver, Unavailable as HebrewUnavailable

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("reading_text_builder", TOOLS / "build-reading-texts.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def same_json(actual, expected) -> bool:
    # Python considers True == 1 and False == 0; native source decoders do not.
    return json.dumps(actual, sort_keys=True, ensure_ascii=False) == json.dumps(expected, sort_keys=True, ensure_ascii=False)


def reviewed_standard_units(book: str, spans: list, system: str) -> tuple[set, bool]:
    if system == "hebrew-psalms":
        refs = []
        for sc, sv, ec, ev in spans:
            for chapter in range(sc, ec + 1):
                end = ev if chapter == ec else chapter_verse_count(book, chapter, "org")
                refs.extend((book, chapter, verse)
                            for verse in range(sv if chapter == sc else 1, end + 1))
        standard, whole = hebrew_psalm_to_standard(refs)
    else:
        require(system == "nabre", f"Unreviewed source system: {system}")
        converter = nabre_mapper()
        refs = [ref for span in spans for ref in converter.inventory.span(book, *span)]
        standard, whole = converter.to_standard(refs)
    return set(standard), whole


def audit_hebrew_supplements(artifact: dict, contexts: dict) -> Counter:
    """Verify source-reviewed excerpts independently of the base Bible's numeric graph."""
    resolver = default_resolver()
    descriptors = {}
    counts = Counter()
    for key, calendars in contexts.items():
        scope, citation, dataset = split_passage_key(key)
        if scope != "daily":
            continue
        try:
            book, _ = builder.parse_citation(citation, expand_subverses=True)
        except builder.Unavailable:
            continue
        if not resolver.handles(key, book):
            continue
        actual = artifact["passages"].get(key, {}).get("masoretic-delitzsch")
        try:
            expected = resolver.resolve(key, calendars, builder.preserve_divine_name_accents)
        except HebrewUnavailable:
            require(actual is None, f"Unavailable Hebrew supplement was emitted: {key}")
            counts["unavailableHebrewAppointments"] += 1
            continue
        require(same_json(actual, expected.verses), f"Hebrew source text, order or notes changed: {key}")
        require(not expected.includes_whole_verses or key in artifact["wholeVersePassages"],
                f"Hebrew source envelope lacks a notice: {key}")
        descriptors[key] = {"masoretic-delitzsch": expected.source}
        counts["reviewedHebrewAppointments"] += 1
    actual = {key: {"masoretic-delitzsch": sources["masoretic-delitzsch"]}
              for key, sources in artifact.get("passageSources", {}).items()
              if "masoretic-delitzsch" in sources}
    require(same_json(actual, descriptors),
            "Hebrew source credits or presentation changed, disappeared or became orphaned")
    return counts


def audit(texts: Path) -> dict:
    artifact = json.loads(texts.read_text())
    lock = json.loads(builder.LOCK.read_text())
    converters = {edition["id"]: mapper(edition["id"]) for edition in lock["editions"]}
    contexts = builder.appointments()
    notices = set(artifact["wholeVersePassages"])
    counts = audit_hebrew_supplements(artifact, contexts)
    from reading_supplement_audit import audit_psalm_supplements
    counts.update(audit_psalm_supplements(artifact, contexts, builder))
    per_edition = {}

    # The sparse Arabic corpus is composed of indivisible reviewed units; its
    # emitted sequences are checked below, not invalid singleton verse slices.
    for edition_id, converter in converters.items():
        if edition_id == "jesuit-arabic-1897":
            continue
        edition_counts = Counter()
        for (book, chapter), verses in converter.corpus.items():
            for verse in verses:
                ref = (book, chapter, verse)
                edition_counts["sourceLabels"] += 1
                try:
                    standard, _ = converter.to_standard([ref])
                except Unavailable:
                    edition_counts["blockedLabels"] += 1
                    continue
                returned, _ = converter.from_standard(standard)
                require(ref in returned, f"Lost source unit on roundtrip: {edition_id} {ref}")
                require(len(standard) == len(set(standard)) and len(returned) == len(set(returned)),
                        f"Duplicated roundtrip units: {edition_id} {ref}")
                require(not any(target[:2] in converter.excluded_chapters for target in returned),
                        f"Roundtrip enters excluded chapter: {edition_id} {ref}")
                edition_counts["successfulRoundtrips"] += 1
        per_edition[edition_id] = dict(edition_counts)
        counts.update(edition_counts)

    for reviews, lookup in ((numbering_reviews(), reviewed_numbering),
                            (appointment_reviews(), reviewed_appointment)):
        for key, review in reviews.items():
            allowed = set(review["contexts"])
            require(lookup(key, set()) is None, f"Empty review scope accepted: {key}")
            for outside in CALENDARS - allowed:
                require(lookup(key, allowed | {outside}) is None,
                        f"Review leaks into {outside}: {key}")
            for context in allowed:
                require(lookup(key, {context}) == review, f"Declared review scope lost: {key}")
            counts["scopedReviews"] += 1

    for key, by_edition in artifact["passages"].items():
        require(key in contexts, f"Reading has no current appointment: {key}")
        scope, citation, dataset = split_passage_key(key)
        calendar_profile = profile_for(dataset, contexts[key])
        book, spans = builder.parse_citation(citation, expand_subverses=True,
                                             psalm_chapter_system=chapter_system(calendar_profile))
        require(not builder.includes_whole_verses(citation) or key in notices,
                f"Partial-verse appointment lacks a notice: {key}")
        exact = reviewed_appointment(key, contexts[key])
        source = reviewed_numbering(key, contexts[key]) if exact is None else None
        required, source_whole = (reviewed_standard_units(book, spans, source["sourceSystem"])
                                  if source else (None, False))
        if dataset is not None and book == "PSA":
            units, source_whole = standard_units(citation, spans, calendar_profile)
            required = set(units)
            counts["registeredCalendarPsalmKeys"] += 1
        require(not source_whole or key in notices, f"Source envelope lacks a notice: {key}")
        projections = {}
        for edition_id, rows in by_edition.items():
            require(edition_id in converters, f"Unknown emitted edition: {edition_id}")
            refs = [(book, row["chapter"], row["verse"]) for row in rows]
            require(refs and len(refs) == len(set(refs)), f"Empty or duplicate passage: {key} {edition_id}")
            if edition_id == "peshitta-1905":
                from peshitta_daily_psalms import default_resolver as bounded_peshitta
                bounded = bounded_peshitta()
                if bounded.handles(key):
                    expected = bounded.resolve(key, contexts[key])
                    require(same_json(rows, expected.verses), f"Peshitta bounded source rows changed: {key}")
                    require(not expected.includes_whole_verses or key in notices,
                            f"Peshitta bounded envelope lacks a notice: {key}")
                    counts["boundedPeshittaPsalmKeys"] += 1
                    continue
            if edition_id in artifact.get("passageSources", {}).get(key, {}):
                # Exact source text/metadata and scoped whole-unit evidence were checked above.
                # The base Tanakh/Delitzsch graph cannot relabel a separately sourced addition.
                continue
            standard, _ = converters[edition_id].to_standard(refs)
            if edition_id == 'peshitta-1905' and book in PESHITTA_OT_BOOKS:
                closed_refs, _ = converters[edition_id].from_standard(standard)
                require(set(closed_refs) == set(refs),
                        f"Emitted passage splits a reviewed source unit: {key} {edition_id}")
            projections[edition_id] = set(standard)
            counts["emittedPassageProjections"] += 1
            if exact is not None:
                expected_exact = reviewed_references(exact, edition_id)
                if edition_id == "peshitta-1905" and not expected_exact:
                    numbering = reviewed_numbering(key, contexts[key])
                    require(numbering is not None and numbering["sourceSystem"] == "hebrew-psalms",
                            f"Peshitta exact boundary lacks an independent source review: {key}")
                    wanted, source_wider = reviewed_standard_units(book, spans, numbering["sourceSystem"])
                    require(wanted <= set(standard), f"Peshitta reviewed Psalm clauses missing: {key}")
                    require(not source_wider and not set(standard) - wanted or key in notices,
                            f"Peshitta independent wider Psalm envelope lacks a notice: {key}")
                else:
                    require(refs == expected_exact,
                            f"Exact appointment review was bypassed: {key} {edition_id}")
                require(not exact["includesWholeVerses"] or key in notices,
                        f"Exact appointment lost its whole-verse notice: {key}")
                counts["exactReviewPassages"] += 1
            elif required is not None:
                require(required <= set(standard),
                        f"Missing reviewed source units: {key} {edition_id}: {sorted(required - set(standard))}")
                require(not set(standard) - required or key in notices,
                        f"Wider source envelope lacks a notice: {key} {edition_id}")
                counts["reviewedSourceCoverageChecks"] += 1
        if len(projections) > 1:
            counts["multiEditionKeys"] += 1
            if exact is None and source is None and required is None:
                # Generic SIL agreement must not hide differing complete units
                # in actual editions, as it once did at 2 Corinthians 13:13.
                # The source-pinned Peshitta OT review can require a wider
                # indivisible envelope. Establish the other editions' common
                # set first, then require exactly its reviewed graph closure,
                # not an arbitrary superset or a blanket edition exception.
                values = [value for edition, value in projections.items()
                          if edition != 'peshitta-1905' or book not in PESHITTA_OT_BOOKS]
                require(all(value == values[0] for value in values[1:]),
                        f"Legacy editions disagree about source units: {key}")
                if values and book in PESHITTA_OT_BOOKS and 'peshitta-1905' in projections:
                    converter = converters['peshitta-1905']
                    source_refs, whole = converter.from_standard(sorted(values[0]))
                    expected, _ = converter.to_standard(source_refs)
                    require(projections['peshitta-1905'] == set(expected),
                            f"Peshitta passage differs from its reviewed unit closure: {key}")
                    require(not whole or key in notices,
                            f"Peshitta compound envelope lacks a notice: {key}")
                counts["legacyAgreementChecks"] += 1
    return {"status": "passed", "counts": dict(counts), "editionRoundtrips": per_edition}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--texts", type=Path, default=builder.DATA / "readings-texts.json")
    args = parser.parse_args()
    print(json.dumps(audit(args.texts), indent=2))


if __name__ == "__main__":
    main()

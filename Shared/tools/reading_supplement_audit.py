"""Independent source-unit checks for bounded Psalm additions.

This reads pinned witnesses and reviewed unit memberships, never the builder's
passage resolution or a supplement's resolve method.
"""
from collections import Counter
import json

from reading_appointment_keys import split_passage_key
from reading_calendar_numbering import profile_for, chapter_system, standard_units, Unavailable as CalendarUnavailable


def audit_psalm_supplements(artifact, contexts, builder):
    from arabic_daily_psalms import default_resolver as arabic_resolver
    from greek_daily_psalms import default_resolver as greek_resolver
    from martini_daily_psalms import default_resolver as martini_resolver
    arabic, greek, martini = arabic_resolver(), greek_resolver(), martini_resolver()
    notices = set(artifact["wholeVersePassages"])
    counts = Counter()

    def require(condition, message):
        if not condition:
            raise ValueError(message)

    def same_json(actual, expected):
        # JSON source types matter: Python alone considers True equal to1.
        return json.dumps(actual, sort_keys=True, ensure_ascii=False) == json.dumps(expected, sort_keys=True, ensure_ascii=False)

    def greek_whole_units(key):
        _, citation, dataset = split_passage_key(key)
        try:
            profile = profile_for(dataset, contexts[key])
            _, spans = builder.parse_citation(citation, expand_subverses=True,
                                               psalm_chapter_system=chapter_system(profile))
            references, source_whole = standard_units(citation, spans, profile)
        except (CalendarUnavailable, builder.Unavailable) as error:
            raise ValueError(f"Greek source scope changed: {key}") from error
        wanted = set(references)
        selected = sorted(chapter for chapter, group in greek.whole_standard_groups.items() if group <= wanted)
        covered = set().union(*(greek.whole_standard_groups[chapter] for chapter in selected)) if selected else set()
        native = [reference for chapter in selected for reference in greek.whole_chapters[chapter]]
        return selected, native, covered == wanted, source_whole

    for key, editions in artifact["passages"].items():
        _, citation, dataset = split_passage_key(key)
        descriptors = artifact.get("passageSources", {}).get(key, {})
        for edition, resolver in (("jesuit-arabic-1897", arabic), ("martini", martini), ("brenton-lxx", greek)):
            bounded = key in resolver.reviews or (dataset is not None and citation.startswith("Psalm ")
                                                and edition in {"jesuit-arabic-1897", "martini"})
            if edition == "brenton-lxx" and edition in editions and dataset is not None and citation.startswith("Psalm "):
                _, _, fully_reviewed, _ = greek_whole_units(key)
                bounded |= fully_reviewed
            require(not (bounded and edition in editions) or edition in descriptors,
                    f"Pinned Psalm source descriptor disappeared: {key}/{edition}")

    for key, descriptors in artifact.get("passageSources", {}).items():
        require(key in contexts and key in artifact["passages"], f"Orphan source descriptor: {key}")
        scope, citation, dataset = split_passage_key(key)
        for edition, source in descriptors.items():
            if edition not in {"jesuit-arabic-1897", "martini", "brenton-lxx"}:
                continue
            rows = artifact["passages"][key].get(edition)
            require(scope == "daily" and rows and source.get("book") == "PSA",
                    f"Psalm source descriptor escaped its scope: {key}/{edition}")
            if edition == "brenton-lxx":
                review = greek.reviews.get(key)
                if review is not None:
                    require(contexts[key] and contexts[key] <= set(review["contexts"]), f"Greek source scope changed: {key}")
                    chapter, labels = review["sourceChapter"], review["sourceLabels"]
                    native = [(chapter, label) for label in labels]
                    complete, wider = review["isComplete"], review["includesWholeVerses"]
                    source_url = f"https://ebible.org/grcbrent/PSA{chapter:03d}.htm"
                else:
                    require(dataset is not None, f"Greek source has no exact calendar/body review: {key}")
                    selected, native, fully_reviewed, source_whole = greek_whole_units(key)
                    require(fully_reviewed and selected, f"Greek source includes an unreviewed partial body: {key}")
                    complete = True
                    wider = source_whole or any(greek.whole_reviews[chapter]["includesWholeVerses"] for chapter in selected)
                    source_url = greek.whole_reviews[selected[0]]["sourceURL"]
                require(type(source.get("isComplete")) is bool and source["isComplete"] == complete,
                        f"Greek source completeness changed: {key}")
                expected = [{"chapter": chapter, "verse": int(label), "text": greek.rows[chapter, label]}
                            for chapter, label in native if label.isdigit()]
                blocks = [{"id": f"grcbrent-psa-{chapter}-{label}", "kind": "witness",
                           "text": greek.rows[chapter, label], "printedLabel": label,
                           "addresses": [{"chapter": chapter, "verse": int(label[:-1]), "part": "a"}]}
                          if label.endswith("a") else
                          {"id": f"grcbrent-psa-{chapter}-{label}", "kind": "verse",
                           "chapter": chapter, "verse": int(label)} for chapter, label in native]
                require(same_json(source.get("contentBlocks"), blocks), f"Greek printed witness changed: {key}")
                require(source.get("sourceURL") == source_url
                        and "Sir Lancelot C. L. Brenton" in source.get("attribution", "")
                        and "Public domain; eBible.org grcbrent" in source.get("attribution", ""),
                        f"Greek source credit changed: {key}")
            else:
                require(source.get("isComplete") is True, f"Missing source unit completeness: {key}/{edition}")
                resolver = arabic if edition == "jesuit-arabic-1897" else martini
                if dataset is None:
                    review = resolver.reviews.get(key)
                    require(review and contexts[key] and contexts[key] <= set(review["contexts"]),
                            f"Psalm supplement calendar scope changed: {key}/{edition}")
                    native = [tuple(ref) for ref in review["sourceReferences"]]
                    wanted = {tuple(ref) for ref in review["standardReferences"]}
                    source_whole = review["includesWholeVerses"]
                else:
                    profile = profile_for(dataset, contexts[key])
                    _, spans = builder.parse_citation(citation, expand_subverses=True,
                        psalm_chapter_system=chapter_system(profile))
                    requested, source_whole = standard_units(citation, spans, profile)
                    wanted = set(requested)
                    native = None
                selected, covered = set(), set()
                if edition == "martini":
                    if dataset is not None:
                        for chapter, group in martini.whole_standard_groups.items():
                            if group <= wanted:
                                selected.update(martini.whole_chapters[chapter])
                                covered.update(group)
                    remaining = wanted - covered
                    for ref, targets in martini.boundaries.items():
                        if targets & remaining:
                            selected.add(ref)
                            covered.update(targets)
                    require(source.get("sourceURL") == "https://parolaviva.art/opendata"
                            and "Giovanni Novelli / Parola Viva" in source.get("attribution", ""),
                            f"Italian source credit changed: {key}")
                else:
                    for refs, targets in arabic.units:
                        if wanted & targets:
                            selected.update(refs)
                            covered.update(targets)
                    expected_notes = [arabic.notes[ref] for ref in sorted(selected) if ref in arabic.notes]
                    require(all(note in source.get("attribution", "") for note in expected_notes),
                            f"Arabic printed uncertainty note disappeared: {key}")
                    expected_url = ("https://sites.dlib.nyu.edu/viewer/books/princeton_aco001445/243"
                                    if expected_notes else "https://archive.org/details/AlKitabAlMoqadas")
                    require(source.get("sourceURL") == expected_url
                            and "1897" in source.get("attribution", ""), f"Arabic source credit changed: {key}")
                require(wanted <= covered, f"Requested Psalm clauses missing: {key}/{edition}")
                require(native is None or native == sorted(selected), f"Reviewed source sequence omits units: {key}/{edition}")
                expected = [{"chapter": chapter, "verse": verse, "text": resolver.rows[chapter, verse]}
                            for chapter, verse in sorted(selected)]
                wider = source_whole or bool(covered - wanted)
            require(same_json(rows, expected), f"Pinned Psalm source rows changed: {key}/{edition}")
            require(not wider or key in notices, f"Wider Psalm source envelope lacks notice: {key}/{edition}")
            counts["sourcePinnedPsalmSupplementChecks"] += 1
    return counts

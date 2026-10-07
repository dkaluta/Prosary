#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Numeric-only Martini Psalm profile; native browsing and daily mapping differ."""
import json
from pathlib import Path

TOOLS = Path(__file__).resolve().parent


def reviewed_profile(original_pin_digest: str) -> dict:
    from reading_edition_mapping import source_pin_digest
    review = json.loads((TOOLS / "martini-daily-psalm-reviews.json").read_text())
    lock = json.loads((TOOLS / "reading-text-sources.json").read_text())
    edition = next(edition for edition in lock["editions"] if edition["id"] == "martini")
    pins = {source["id"]: source["sha256"] for source in lock["sources"]}
    all_pins = {source["id"]: pins[source["id"]] for source in edition["sources"]}
    base = {key: value for key, value in all_pins.items() if not key.startswith("martini-sal-")}
    if source_pin_digest(base) != original_pin_digest:
        raise ValueError("Martini's previously reviewed non-Psalm source pins changed")
    expected = {source["id"]: source["sha256"] for source in review["sources"]}
    psalms = {key: value for key, value in all_pins.items() if key.startswith("martini-sal-")}
    labels = review["publishedChapterLabels"]
    if (psalms != expected or set(labels) != {str(chapter) for chapter in range(1, 151)}
            or any(verses != list(range(1, len(verses) + 1)) for verses in labels.values())):
        raise ValueError("Native Martini Psalm labels/pins differ from their publication review")
    # Remove every guessed default edge from this newly imported book. The
    # explicit, independently inspected boundary facts are its only daily map.
    overrides = {("PSA", int(chapter), verse): () for chapter, verses in labels.items() for verse in verses}
    allowed = set()
    for row in review["boundaries"]:
        chapter, verse = row["source"]
        reference = "PSA", chapter, verse
        if reference not in overrides or reference in allowed:
            raise ValueError("Invalid or duplicated reviewed Martini Psalm coordinate")
        overrides[reference] = tuple(tuple(target) for target in row["standard"])
        allowed.add(reference)
    rules = json.loads((TOOLS / "versification/step/rules.json").read_text())["rules"]
    psalm_rules = {row[0] for row in rules if row[2].startswith("Psa.")}
    return {"source_pin_digest": source_pin_digest(all_pins), "overrides": overrides,
            "reviewed_source_references": allowed, "review_required_books": {"PSA"},
            "reviewed_inventory_exceptions": {("PSA", chapter) for chapter in range(1, 151)},
            "source_native_books": {"PSA"}, "excluded_rule_lines": psalm_rules}

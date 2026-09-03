#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Tests validate-devotion.py against the hours-format-proof fixture and deliberate breakages.

A validator that only ever says yes is worth nothing, so every rule the hours type adds gets a
case here that must make it say no. The positive case is the fixture itself: it exercises two
hours in one bundle, a shared ordinary, the running psalter, a proper of the season, a saint's
day, a rank-based override, the two-year reading cycle, a slot with its own default, and an
option-gated step — and it must validate clean.

    usage: test-validate-devotion.py
"""

from __future__ import annotations

import copy
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
FIXTURE = TOOLS / "fixtures" / "hours-format-proof"
ROSARY_FIXTURE = TOOLS / "fixtures" / "rosary-variants-proof"
VALIDATOR = TOOLS / "validate-devotion.py"
SHARED_CONTENT = TOOLS.parent / "content"

failures: list[str] = []


def run(directory: Path) -> tuple[int, str]:
    proc = subprocess.run([sys.executable, str(VALIDATOR), str(directory)],
                          capture_output=True, text=True)
    return proc.returncode, proc.stdout + proc.stderr


def check_valid(directory: Path, label: str) -> None:
    code, output = run(directory)
    if code != 0:
        failures.append(f"{label}: expected valid, got:\n{output}")


def check_rejects(label: str, mutate, expected: str, fixture: Path = FIXTURE) -> None:
    """Apply `mutate` to a copy of a fixture's devotion.json and require a matching error."""
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp) / "bundle"
        shutil.copytree(fixture, work)
        devotion = json.loads((work / "devotion.json").read_text(encoding="utf-8"))
        mutate(devotion)
        (work / "devotion.json").write_text(json.dumps(devotion), encoding="utf-8")
        code, output = run(work)
        if code == 0:
            failures.append(f"{label}: expected rejection, but it validated")
        elif expected not in output:
            failures.append(f"{label}: expected {expected!r} in:\n{output}")


def check_content_rejects(label: str, mutate, expected: str, language: str = "en") -> None:
    """Apply `mutate` to a fixture content file and require the validator to reject it."""
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp) / "bundle"
        shutil.copytree(FIXTURE, work)
        path = work / "content" / f"{language}.json"
        content = json.loads(path.read_text(encoding="utf-8"))
        mutate(content)
        path.write_text(json.dumps(content, ensure_ascii=False), encoding="utf-8")
        code, output = run(work)
        if code == 0:
            failures.append(f"{label}: expected rejection, but it validated")
        elif expected not in output:
            failures.append(f"{label}: expected {expected!r} in:\n{output}")


def hour(devotion: dict, hid: str) -> dict:
    return next(h for h in devotion["hours"] if h["id"] == hid)


def proper(devotion: dict, slot: str) -> dict:
    return next(p for p in devotion["propers"] if p["slot"] == slot)


def main() -> int:
    check_valid(FIXTURE, "hours-format-proof")

    # Every shipped bundle must still validate — the hours branch must not have disturbed the
    # types that were already there.
    for source in sorted(SHARED_CONTENT.iterdir()):
        if (source / "manifest.json").exists():
            check_valid(source, f"shipped: {source.name}")

    # --- A slot must be able to produce a step -------------------------------------------------
    check_rejects(
        "a slot nothing fills",
        lambda d: hour(d, "vespers")["steps"].append({"kind": "proper", "slot": "intercessions"}),
        "no proper to fill it")

    check_rejects(
        "a slot whose only proper is for another hour",
        lambda d: (hour(d, "vespers")["steps"].append({"kind": "proper", "slot": "examen"}),
                   d["propers"].append({"hour": "compline", "slot": "examen", "when": {},
                                        "steps": [{"title": "x", "bodyKey": "examination",
                                                   "imageKey": "crucifix"}]})),
        "has no 'examen' slot to fill")

    check_rejects(
        "a proper for a slot no hour asks for",
        lambda d: d["propers"].append({"slot": "ghost", "when": {},
                                       "steps": [{"title": "x", "bodyKey": "salvaNos",
                                                  "imageKey": "crucifix"}]}),
        "is not asked for by any hour")

    # --- The 'when' vocabulary is closed -------------------------------------------------------
    check_rejects(
        "an unknown facet",
        lambda d: proper(d, "reading")["when"].update({"moonPhase": ["waxing"]}),
        "unknown facet 'moonPhase'")

    check_rejects(
        "a season that is not one of the five",
        lambda d: proper(d, "hymn")["when"].update({"season": ["pentecost"]}),
        "is not a valid season")

    check_rejects(
        "a psalter week outside 1-4",
        lambda d: proper(d, "psalmody")["when"].update({"psalterWeek": [5]}),
        "is not a valid psalterWeek")

    check_rejects(
        "a date that is not MM-DD",
        lambda d: proper(d, "collect")["when"].update({"date": ["13-01"]}),
        "is not a valid date")

    check_rejects(
        "a reading year outside the two-year cycle",
        lambda d: proper(d, "reading")["when"].update({"readingYear": [3]}),
        "is not a valid readingYear")

    check_rejects(
        "a facet given a bare value instead of a list",
        lambda d: proper(d, "hymn")["when"].update({"season": "advent"}),
        "must be a non-empty array")

    # --- Identity and shape --------------------------------------------------------------------
    check_rejects(
        "two hours sharing an id",
        lambda d: d["hours"].append(dict(hour(d, "compline"))),
        "duplicate id 'compline'")

    check_rejects(
        "two propers no calendar could tell apart",
        lambda d: d["propers"].append(copy.deepcopy(proper(d, "reading"))),
        "can never be chosen")

    check_rejects(
        "an hour naming a time that is not HH:mm",
        lambda d: hour(d, "vespers").update({"suggestedTime": "6pm"}),
        'suggestedTime must be "HH:mm"')

    check_rejects(
        "a proper naming an hour that does not exist",
        lambda d: proper(d, "hymn").update({"hour": "sext"}),
        "is not a declared hour")

    check_rejects(
        "a slot entry carrying step fields of its own",
        lambda d: hour(d, "vespers")["steps"][0].update({"bodyKey": "salvaNos"}),
        "must have no other fields")

    check_rejects(
        "an hours devotion carrying another type's fields",
        lambda d: d.update({"days": [{"name": "x", "steps": []}]}),
        "must not have 'days'")

    check_rejects(
        "an hour with no steps",
        lambda d: hour(d, "compline").update({"steps": []}),
        "empty step list")

    check_rejects(
        "an option-gated step naming an option that was never declared",
        lambda d: hour(d, "vespers")["steps"][1].update({"if": "solemnTone"}),
        "undeclared option 'solemnTone'")

    # A proper's own steps are ordinary entries and resolve like any other.
    check_rejects(
        "a proper referencing a key no language ships",
        lambda d: proper(d, "collect")["steps"][0].update({"bodyKey": "collectNoSuchThing"}),
        "unresolved key 'collectNoSuchThing'")

    # --- Content overlays: partial mystery fields and citation punctuation --------------------
    check_content_rejects(
        "a citation range written with a hyphen",
        lambda c: c["prayers"].update(
            {"magnificat": c["prayers"]["magnificat"].replace("46–47", "46-47")}),
        "citation ranges must use an en dash",
    )
    check_content_rejects(
        "a Hebrew-script citation written with a colon",
        lambda c: c["prayers"].update(
            {"magnificat": "טקסט\n\n— יוחנן 3:16–17 (מהדורה)"}),
        "Hebrew-script citations use a gematria chapter and no colon",
    )
    check_content_rejects(
        "an empty partial mystery override",
        lambda c: c["mysteries"].update({"joyful_01_annunciation": {}}),
        "must override title, fruit, or description",
    )
    check_content_rejects(
        "a mystery transliteration without its source description",
        lambda c: c["mysteries"].update({
            "joyful_01_annunciation": {
                "title": "Annunciation",
                "transliteratedDescription": "alternate",
            }
        }),
        "transliteratedDescription requires description",
    )

    # --- rosary-type variants: every form carries the bead track's invariants on its own ------
    check_valid(ROSARY_FIXTURE, "rosary-variants-proof")

    def rosary(label, mutate, expected):
        check_rejects(label, mutate, expected, fixture=ROSARY_FIXTURE)

    rosary(
        "a second form whose opening does not start with the cross",
        lambda d: d["variants"][1]["opening"].pop(0),
        "must be the Sign of the Cross",
    )
    rosary(
        "a second form promising a closing cross it does not end with",
        lambda d: d["variants"][1]["closing"].pop(),
        "hasClosingCross",
    )
    rosary(
        "a form with no opening at all",
        lambda d: d["variants"][0].update({"opening": []}),
        "needs an opening",
    )
    rosary(
        "two forms sharing an id",
        lambda d: d["variants"].append(dict(d["variants"][0])),
        "duplicate id 'short'",
    )
    rosary(
        "a form missing its name",
        lambda d: d["variants"][1].pop("name"),
        "missing name",
    )
    rosary(
        "variants alongside a top-level form",
        lambda d: d.update({"decades": d["variants"][0]["decades"]}),
        "must not also have top-level",
    )
    rosary(
        "a broken decade inside the second form only",
        lambda d: d["variants"][1]["decades"].update({"minorCount": 0}),
        "minorCount must be an integer >= 1",
    )

    # --- per-language default forms (defaultForLanguages) and the canonical tradition order ---
    def claims(d, index, langs):
        d["variants"][index]["defaultForLanguages"] = langs

    def accepts_rosary(label, mutate):
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp) / "bundle"
            shutil.copytree(ROSARY_FIXTURE, work)
            devotion = json.loads((work / "devotion.json").read_text(encoding="utf-8"))
            mutate(devotion)
            (work / "devotion.json").write_text(json.dumps(devotion), encoding="utf-8")
            check_valid(work, label)

    accepts_rosary(
        "a form claiming a rite as its default audience",
        lambda d: claims(d, 1, ["he-x-gamliel"]),
    )
    rosary(
        "two forms claiming the same default language",
        lambda d: (claims(d, 0, ["he-x-gamliel"]), claims(d, 1, ["he-x-gamliel"])),
        "already another variant's default language",
    )
    rosary(
        "a defaultForLanguages that is not a list of codes",
        lambda d: claims(d, 1, "he-x-gamliel"),
        "must be a non-empty array",
    )
    rosary(
        # Declaration order is the default rule, so the canonical order latin → byzantine →
        # west syriac → armenian → alexandrian → east syriac is machine-checked, not folklore.
        "tradition-named forms out of canonical order",
        lambda d: [d["variants"][i].update({"id": vid})
                   for i, vid in enumerate(["syriac", "latin"])],
        "canonical order",
    )
    accepts_rosary(
        "tradition-named forms in canonical order",
        lambda d: [d["variants"][i].update({"id": vid})
                   for i, vid in enumerate(["latin", "syriac"])],
    )
    rosary(
        "a preAnnouncement entry missing its body",
        lambda d: d["variants"][1]["decades"]["preAnnouncement"][0].pop("bodyKey"),
        "missing bodyKey",
    )
    rosary(
        "a preAnnouncement key no language ships",
        lambda d: d["variants"][1]["decades"]["preAnnouncement"][0].update({"bodyKey": "nope"}),
        "unresolved key 'nope'",
    )

    for failure in failures:
        print(f"FAIL {failure}", file=sys.stderr)
    if failures:
        print(f"\n{len(failures)} failing case(s)", file=sys.stderr)
        return 1
    print("validate-devotion: all cases pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())

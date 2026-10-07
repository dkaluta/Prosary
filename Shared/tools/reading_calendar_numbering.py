#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Distinct source-calendar Psalm conventions for newly registered tables.

A published calendar's reference system is separate from a selected Bible's
native verse layout. No Roman exact-appointment review is inherited here.
"""
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import re

from reading_appointment_keys import DATA, registry_datasets
from reading_psalm_mapping import hebrew_psalm_to_standard
from reading_versification import Versification, chapter_verse_count

TOOLS = Path(__file__).resolve().parent
REVIEW_PATH = TOOLS / "reading-calendar-numbering-reviews.json"
WHOLE_PSALM = re.compile(r"Psalm ([1-9]\d*)(?:[–-]([1-9]\d*))?")


@lru_cache(maxsize=1)
def _tables():
    return Versification().tables


class Unavailable(ValueError):
    pass


@lru_cache(maxsize=1)
def profiles() -> dict[str, dict]:
    raw = json.loads(REVIEW_PATH.read_text(encoding="utf-8"))
    if raw.get("schemaVersion") != 1 or not isinstance(raw.get("datasets"), dict):
        raise ValueError("Unsupported source-calendar numbering review")
    registry = registry_datasets()
    for identifier, profile in raw["datasets"].items():
        if identifier not in registry or profile.get("psalmNumbering") not in {"hebrew-psalms", "vulgate-psalm-chapters"}:
            raise ValueError("Unregistered or unsupported calendar Psalm profile")
        snapshot = TOOLS / profile["sourceSnapshot"]
        if (not snapshot.resolve().is_relative_to((TOOLS / "sources").resolve())
                or hashlib.sha256(snapshot.read_bytes()).hexdigest() != profile["sourceSnapshotSHA256"]):
            raise ValueError("Source calendar snapshot changed; review its numbering again")
        table = json.loads((DATA / (registry[identifier]["file"] + ".json")).read_text())
        if table.get("sourceSha256") != profile["sourcePDFSHA256"] or table.get("sourceUrl") != profile["sourceURL"]:
            raise ValueError("Registered reading table differs from its reviewed calendar source")
        if not profile.get("evidence") or not profile.get("boundaryReview"):
            raise ValueError("Calendar numbering lacks source evidence")
        if identifier == "stjames":
            snapshot_data = json.loads(snapshot.read_text())
            appointed = {reading["full"] for day in table["days"].values()
                         for reading in day.get("readings", []) if reading["full"].startswith("Psalm ")}
            if (profile.get("datasetId") != identifier or set(profile.get("appointments", {})) != appointed
                    or not set(profile.get("unavailableAppointments", {})) <= appointed):
                raise ValueError("St James Psalm appointments lack their own bilingual source evidence")
            letters = dict(zip("אבגדהוזחטיכלמנסעפצקרשת",
                               (1,2,3,4,5,6,7,8,9,10,20,30,40,50,60,70,80,90,100,200,300,400)))
            for citation, evidence in profile["appointments"].items():
                actual_dates = {date for date, day in table["days"].items()
                                if any(row["full"] == citation for row in day.get("readings", []))}
                if not evidence or {item["date"] for item in evidence} != actual_dates:
                    raise ValueError("St James Psalm row lost its dated source scope")
                for item in evidence:
                    primary = snapshot_data["days"][item["date"]]
                    chapters = [sum(letters[letter] for letter in numeral)
                                for numeral in re.findall(r"תה['׳]\s+([א-ת]+)", primary["hebrew"])]
                    printed = item["printedEnglish"]
                    chapter = int(re.match(r"Ps\s+(\d+)", printed)[1])
                    if (item["sourcePage"] != primary["pdfPage"] or item["pairedHebrewChapter"] != chapter
                            or chapter not in chapters or " ".join(printed.split()) not in " ".join(primary["english"].split())):
                        raise ValueError("St James Psalm row differs from its printed bilingual chapter")
    return raw["datasets"]


def profile_for(dataset: str | None, contexts: set[str]) -> dict | None:
    if dataset is None:
        return None
    if contexts != {dataset}:
        raise Unavailable("reading dataset outside its registered source context")
    known = profiles()
    if dataset in known:
        return known[dataset]
    if dataset not in registry_datasets():
        raise Unavailable("reading dataset outside its registered source context")
    return None


def chapter_system(profile: dict | None) -> str | None:
    if profile is None:
        return None
    return "org" if profile["psalmNumbering"] == "hebrew-psalms" else "vul"


def standard_units(citation: str, spans: list[tuple], profile: dict | None) -> tuple[list[tuple], bool]:
    if profile is None:
        raise Unavailable("Psalm numbering has not been reviewed for this registered calendar")
    if profile.get("datasetId") == "stjames":
        if citation not in profile["appointments"]:
            raise Unavailable("St James Psalm citation lacks its exact bilingual source review")
        if citation in profile.get("unavailableAppointments", {}):
            raise Unavailable("printed Psalm span conflicts with the paired Hebrew chapter; source correction remains unresolved")
    whole_chapter = WHOLE_PSALM.fullmatch(citation) is not None
    convention = profile["psalmNumbering"]
    if convention == "vulgate-psalm-chapters" and not whole_chapter:
        raise Unavailable("calendar Psalm verse boundaries remain unreviewed; only its chapter numbers are established")
    system = chapter_system(profile)
    original = set()
    table = _tables()[system]
    if convention == "vulgate-psalm-chapters" and whole_chapter:
        # SIL's Vulgate maxima/verse labels do not describe every printed Latin
        # chapter layout. In 115 it records only 10–19; in 147 only 12–20. Default
        # identity for the unlisted lower labels mixes in an unrelated body.
        # A chapter-only appointment uses explicit chapter-family relations,
        # never those absent-label identities or an inferred native verse cut.
        chapters = {chapter for sc, _, ec, _ in spans for chapter in range(sc, ec + 1)}
        for chapter in chapters:
            targets = {target for source, related in table.explicit.items()
                       if source[0] == "PSA" and source[1] == chapter for target in related}
            if not targets:
                raise Unavailable("Latin Psalm chapter lacks an explicit reviewed body family")
            original.update(targets)
        body = {unit for unit in original if unit[2] > 0}
        units, _ = hebrew_psalm_to_standard(sorted(body))
        units = [unit for unit in units if unit[2] > 0]
        if not units:
            raise Unavailable("Latin Psalm chapter has no explicit Scripture body family")
        return units, False
    for sc, sv, ec, ev in spans:
        for chapter in range(sc, ec + 1):
            maximum = chapter_verse_count("PSA", chapter, system)
            start, end = (sv if chapter == sc else 1), (ev if chapter == ec else maximum)
            if maximum is None or not 1 <= start <= end <= maximum:
                raise Unavailable("calendar Psalm reference is outside its reviewed source chapter")
            for verse in range(start, end + 1):
                source = ("PSA", chapter, verse)
                # Full chapter relations retain SIL's merged/split references. The
                # ordinary one-edge API deliberately refuses those partial units.
                original.update(table.explicit.get(source, {source}))
    if whole_chapter:
        original = {unit for unit in original if unit[2] > 0}
    units, wider = hebrew_psalm_to_standard(sorted(original))
    if whole_chapter:
        # Zero is numeric superscription metadata. A calendar naming the whole
        # Psalm does not require a standalone title absent in a selected edition;
        # titles joined to a native body row remain untouched in that full row.
        units = [unit for unit in units if unit[2] > 0]
        wider = False
    if not units:
        raise Unavailable("calendar Psalm has no reviewed Scripture body units")
    return units, wider

#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Reference-only profiles for three exact pinned Bible source assemblies.

See EDITION-NUMBERING-HEBREW.markdown for the source review and limitations.
The source-pin digest must be checked before these edition-specific relations
are applied. No Scripture words, inferred translations, or source downloads.
"""
from collections import defaultdict

from reading_versification import Versification

Reference = tuple[str, int, int]
# Canonical Psalm superscriptions, verified against the pinned STEP title rows.
TITLE_PSALMS = frozenset({3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,20,21,22,
    23,24,25,26,27,28,29,30,31,32,34,35,36,37,38,39,40,41,42,44,45,46,47,48,
    49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,72,73,
    74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,92,98,100,101,102,103,
    108,109,110,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,138,
    139,140,141,142,143,144,145})


def _hebrew_overrides() -> dict[Reference, tuple[Reference, ...]]:
    # hbo follows SIL Original in all 929 actual OT chapter inventories. Keep
    # complete Psalm relations, including the 53 titles joined to body verse 1.
    english = Versification().tables["eng"]
    graph = defaultdict(set)
    for (book, chapter), maximum in english.maxima.items():
        if book != "PSA":
            continue
        for verse in range(1, maximum + 1):
            standard = (book, chapter, verse)
            for original in english.explicit.get(standard, {standard}):
                graph[original].add(standard)
    numbered_titles = set()
    for standard, originals in english.explicit.items():
        if standard[0] == "PSA" and standard[2] == 0:
            numbered_titles.add(standard[1])
            for original in originals:
                graph[original].add(standard)
    for chapter in TITLE_PSALMS - numbered_titles:
        graph["PSA", chapter, 1].add(("PSA", chapter, 0))
    # Hebrew word division makes the STEP Malachi length discriminator choose
    # the wrong order. The actual source has Moses, Elijah, reconciliation in
    # 3:22-24, as in the reviewed Original-to-English numeric correspondence.
    for verse in range(19, 25):
        graph["MAL", 3, verse] = {("MAL", 4, verse - 18)}
    graph["1SA", 20, 42] = {("1SA", 20, 42)}
    graph["1SA", 21, 1] = {("1SA", 20, 42)}
    # Exact Delitzsch 1901 units already reviewed in delitzsch_numbering.py.
    graph["JHN", 1, 38] = graph["JHN", 1, 39] = {("JHN", 1, 38)}
    for verse in range(40, 53):
        graph["JHN", 1, verse] = {("JHN", 1, verse - 1)}
    graph["ROM", 7, 25] = graph["ROM", 7, 26] = {("ROM", 7, 25)}
    graph["1CO", 13, 12] = graph["1CO", 13, 13] = {("1CO", 13, 12)}
    graph["1CO", 13, 14] = {("1CO", 13, 13)}
    graph["2TH", 3, 16] = graph["2TH", 3, 17] = {("2TH", 3, 16)}
    graph["2TH", 3, 18] = {("2TH", 3, 17)}
    graph["2TH", 3, 19] = {("2TH", 3, 18)}
    return {source: tuple(sorted(targets)) for source, targets in graph.items()}


def _kulish_overrides() -> dict[Reference, tuple[Reference, ...]]:
    result = {}
    def put(book, chapter, source, targets):
        result[book, chapter, source] = tuple((book, chapter, v) for v in targets)
    # Printed bodies were compared at each changed boundary. The source joins
    # canonical units here; none of these edges is inferred from chapter size.
    put("GEN",3,1,(1,2))
    for verse in range(2,24): put("GEN",3,verse,(verse+1,))
    put("GEN",6,20,(20,21)); put("GEN",6,21,(22,))
    put("GEN",48,21,(21,22))
    for verse in range(20,24): result["LEV",5,verse] = (("LEV",6,verse-19),)
    result["LEV",5,24] = result["LEV",5,25] = (("LEV",6,5),)
    result["LEV",5,26] = (("LEV",6,6),)
    result["LEV",5,27] = (("LEV",6,7),)
    for verse in range(1,22): put("LEV",6,verse,(verse+7,))
    put("LEV",6,22,(29,30))
    for book,chapter,source,targets in (
        ("LEV",14,55,(55,56,57)), ("LEV",17,15,(15,16)),
        ("NUM",8,25,(25,26)), ("NUM",14,44,(44,45)),
        ("NUM",15,40,(40,41)), ("NUM",20,28,(28,29)),
        ("NUM",25,17,(17,18)), ("NUM",27,22,(22,23)),
        ("DEU",16,21,(21,22)), ("DEU",24,21,(21,22)),
        ("DEU",32,51,(51,52)), ("DEU",34,11,(11,12)),
        ("JOB",21,32,(32,33)), ("JOB",21,33,(34,)),
        ("PRO",30,30,(30,31)), ("PRO",30,31,(32,)), ("PRO",30,32,(33,)),
        ("ISA",9,21,(21,)), ("ISA",9,22,(21,)),
        ("PHP",3,20,(20,21)), ("PHM",1,23,(23,24)), ("PHM",1,24,(25,))):
        put(book,chapter,source,targets)
    # Narrative/poetic subdivisions that restore the original count later.
    put("NUM",23,17,(17,)); put("NUM",23,18,(17,))
    put("NUM",23,19,(18,)); put("NUM",23,20,(19,))
    put("NUM",23,21,(20,21)); put("NUM",23,22,(21,))
    for verse in range(23,29): put("NUM",23,verse,(verse-1,))
    put("NUM",23,29,(28,29)); put("NUM",23,30,(29,)); put("NUM",23,31,(30,))
    result["DEU",28,69] = (("DEU",29,1),)
    put("DEU",29,1,(2,)); put("DEU",29,2,(2,))
    put("2SA",2,4,(4,)); put("2SA",2,5,(4,))
    for verse in range(6,34): put("2SA",2,verse,(verse-1,))
    # Actual Kulish Philippians is KJV order despite the opposite length test.
    put("PHP",1,16,(16,)); put("PHP",1,17,(17,))
    # 114 source superscriptions remain intact. Two are separately numbered in
    # Psalm 60; the others are in verse 1. Psalms 98 and 123 omit their titles.
    for chapter in TITLE_PSALMS - {60,98,123}:
        put("PSA",chapter,1,(0,1))
    put("PSA",60,1,(0,)); put("PSA",60,2,(0,))
    for verse in range(3,15): put("PSA",60,verse,(verse-2,))
    for chapter,source,targets in (
        (13,5,(5,6)), (24,9,(9,10)), (29,7,(7,8)), (29,8,(9,)),
        (29,9,(10,)), (29,10,(11,)), (54,4,(4,5)), (54,5,(6,)),
        (54,6,(7,)), (89,51,(51,52)), (106,47,(47,48)),
        (127,5,(5,)), (127,6,(5,))): put("PSA",chapter,source,targets)
    return result


KULISH_LOCAL_LINES = set(range(6142,6145)) | set(range(6184,6207)) | set(range(7175,7188)) | {
    *range(10156,10214), *range(18002,18022), *range(18101,18118),
    *range(18157,18171), *range(20264,20267), *range(20540,20574),
    *range(21082,21092), *range(21170,21181), *range(27448,27452), *range(27463,27466)}

KULISH_REVIEWED_INVENTORY = {
    ("GEN",3),("GEN",6),("GEN",48),("LEV",5),("LEV",6),("LEV",14),("LEV",17),
    ("NUM",8),("NUM",14),("NUM",15),("NUM",20),("NUM",23),("NUM",25),("NUM",27),
    ("DEU",16),("DEU",24),("DEU",28),("DEU",32),("DEU",34),("1SA",20),("1SA",23),
    ("1SA",24),("2SA",2),("1KI",22),("JOB",21),("JOB",39),("JOB",40),("JOB",41),
    ("PSA",13),("PSA",24),("PSA",29),("PSA",54),("PSA",60),("PSA",89),("PSA",106),
    ("PSA",127),("PRO",30),("ECC",4),("ECC",5),("SNG",1),("SNG",6),("SNG",7),
    ("ISA",9),("DAN",3),("DAN",4),("HOS",13),("HOS",14),("JON",1),("JON",2),
    ("2CO",13),("PHP",3),("PHM",1),("REV",12)}

PROFILES = {
    "masoretic-delitzsch": {
        "source_pin_digest": "25c8eb7b72ca449b0b4ea64251c560789eeaf234555a31b8b4ec91a2ee0a2a95",
        "source_types": {"Hebrew","Eng-KJV"},
        "local_rule_lines": {*range(27448,27452), *range(27463,27466)},
        "overrides": _hebrew_overrides(), "blocked_chapters": set(),
        "reviewed_inventory_exceptions": {("JHN",1),("ROM",7),("1CO",13),("2CO",13),("2TH",3),("REV",12)},
        "notes": "Exact hbo OT plus 260 Delitzsch1901 chapters; 66 books. All Hebrew superscriptions retained, including merged titles. Six previously reviewed Delitzsch chapter boundaries; 3John split; Malachi length-predicate correction. Standard Nehemiah7:68 has no source counterpart. No deuterocanonical books.",
    },
    "ang-dating-biblia-1905": {
        "source_pin_digest": "a841574697b680101934da5ac4f768a5dc0d3f08d8a231d8c770d77d978fe370",
        "source_types": {"Eng-KJV"}, "local_rule_lines": {27455,27456},
        "overrides": {}, "blocked_chapters": set(),
        "reviewed_inventory_exceptions": {("3JN",1),("REV",12)},
        "notes": "Exact TagAngBiblia archive; 66 books. Philippians16 is love and17 strife, opposite KJV order. The source omits Psalm superscriptions, merges3John14-15 into14, and uses Revelation12:17/13:1 KJV boundary. No deuterocanonical books.",
    },
    "kulish-1905": {
        "source_pin_digest": "f2a938ae98dbc3c4e562c57d6f2e5b63bb9d2b7adec2770d796fec1efb7d3239",
        "source_types": {"Eng-KJV"}, "local_rule_lines": KULISH_LOCAL_LINES,
        "overrides": _kulish_overrides(), "blocked_chapters": {("LEV",21),("PSA",148)},
        "reviewed_inventory_exceptions": KULISH_REVIEWED_INVENTORY,
        "notes": "Exact ukr1871 archive; 66 books. Reviewed local Hebrew/Latin/Job boundaries and source merges;114 Psalm superscriptions, with Psalm60 titles in1-2. Source omits Psalm98/123 titles and Song1:1 title. Leviticus21 and Psalm148 remain blocked because their final canonical material is absent. Philippians16/17 retains KJV order despite its misleading length predicate.",
    },
}

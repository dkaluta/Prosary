#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Build offline Bible passages from pinned editions already used by Prosary.

The appointment tables remain authoritative. This tool never translates Scripture,
repairs malformed appointments, guesses subverse cuts, or falls back to another Bible.
Run --fetch to populate the ignored source cache, --sync to copy canonical outputs,
or --check to verify existing outputs without changing them. See DAILY-READINGS.markdown.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "Shared/tools"
DATA = ROOT / "Shared/data"
REPORTS = ROOT / "Shared/reports"
CACHE = TOOLS / ".scripture-cache"
LOCK = TOOLS / "reading-text-sources.json"
TARGETS = [ROOT / "iOS/Prosary/Data", ROOT / "Android/app/src/main/assets/data", ROOT / "Windows/Prosary/Data"]
NAMES = (
    "Genesis|Exodus|Leviticus|Numbers|Deuteronomy|Joshua|Judges|Ruth|1 Samuel|2 Samuel|"
    "1 Kings|2 Kings|1 Chronicles|2 Chronicles|Ezra|Nehemiah|Esther|Job|Psalm|Proverbs|"
    "Ecclesiastes|Song of Songs|Isaiah|Jeremiah|Lamentations|Ezekiel|Daniel|Hosea|Joel|Amos|"
    "Obadiah|Jonah|Micah|Nahum|Habakkuk|Zephaniah|Haggai|Zechariah|Malachi|Matthew|Mark|"
    "Luke|John|Acts|Romans|1 Corinthians|2 Corinthians|Galatians|Ephesians|Philippians|"
    "Colossians|1 Thessalonians|2 Thessalonians|1 Timothy|2 Timothy|Titus|Philemon|Hebrews|"
    "James|1 Peter|2 Peter|1 John|2 John|3 John|Jude|Revelation|Tobit|Judith|Wisdom|Sirach|"
    "Baruch|1 Maccabees|2 Maccabees"
).split("|")
CODES = ("GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH EST JOB PSA PRO "
         "ECC SNG ISA JER LAM EZK DAN HOS JOL AMO OBA JON MIC NAM HAB ZEP HAG ZEC MAL MAT "
         "MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM HEB JAS 1PE "
         "2PE 1JN 2JN 3JN JUD REV TOB JDT WIS SIR BAR 1MA 2MA").split()
BOOKS = dict(zip(NAMES, CODES, strict=True))
NT = set(CODES[39:66])
PENTATEUCH = set(CODES[:5])
# eBible VPL uses BibleWorks' older abbreviations rather than USFM for these books.
VPL_CODES = dict(zip("MAR JOH PHI 1PE 2PE JAM JOE NAH SOL EZE".split(),
                     "MRK JHN PHP 1PE 2PE JAS JOL NAM SNG EZK".split(), strict=True))
VPL_CODES.update({"1JO": "1JN", "2JO": "2JN", "3JO": "3JN"})
JSON_ALIASES = {"Psalms": "Psalm", "Song of Solomon": "Song of Songs", "Revelation of John": "Revelation"}
for number, roman in [(1, "I"), (2, "II"), (3, "III")]:
    JSON_ALIASES.update({name.replace(str(number), roman, 1): name for name in NAMES if name.startswith(f"{number} ")})
ITALIAN_CODES = dict(zip(
    "gen es lv nm dt mt mc lc gv at rm 1cor 2cor gal ef fil col 1ts 2ts 1tm 2tm tt fm eb gc 1pt 2pt 1gv 2gv 3gv gd ap".split(),
    CODES[:5] + CODES[39:66], strict=True))


class Unavailable(ValueError):
    """An appointment cannot safely be resolved from the selected source."""


class ResolvedPassage(list):
    """Native verse rows plus a build-time-only whole-verse envelope marker."""

    def __init__(self, verses, *, includes_whole_verses: bool = False):
        super().__init__(verses)
        self.includes_whole_verses = includes_whole_verses


class PinnedCorpus(dict):
    """An assembled hash-checked edition with its actual numbered inventory.

    Edition rules use each reviewed source structure, which can differ from a
    generic tradition's chapter maxima. Retain the imported inventory before
    passage selection, so missing/empty rows cannot pass as a numbering change.
    """

    def __init__(self, chapters: dict, source_pins: dict[str, str]):
        super().__init__(chapters)
        self.source_pins = dict(source_pins)
        self.verse_inventory = {key: frozenset(values) for key, values in chapters.items()}
        self._step_mapper = None

    def chapter_matches(self, book: str, chapter: int) -> bool:
        values = self.get((book, chapter), {})
        expected = self.verse_inventory.get((book, chapter))
        return bool(expected) and set(values) == expected and all(
            type(verse) is int and verse > 0 and isinstance(value, str) and value.strip()
            for verse, value in values.items())

    def dra_mapper(self):
        from reading_psalm_mapping import DRA_PSALM_SOURCE_OVERLAPS
        from reading_step_mapping import StepMapper
        if self.source_pins != {"engDRA": "96282bfa7c89a74680cea66fe873aafa5e7cd446407f0ff2531a723e19eee2c2"}:
            raise ValueError("DRA reference mapping requires its reviewed, unmixed source pin")
        if self._step_mapper is None:
            self._step_mapper = StepMapper(self, "douay-rheims-1899", overrides=DRA_PSALM_SOURCE_OVERLAPS)
        return self._step_mapper


class ReviewedCorpus(dict):
    """Sparse, page-verified text whose reviewed passage boundaries are indivisible.

    This is deliberately a distinct source type, not a flag that relaxes ordinary
    imported chapters. Old Jesuit verse boundaries sometimes differ inside the
    same numbered range (e.g. Luke 1:32–33), beyond SIL's numeric mappings.
    """

    def __init__(self, chapters: dict, edition_id: str, units: list[tuple]):
        super().__init__(chapters)
        self.edition_id = edition_id
        self.review_units = tuple(units)

    def covers_reviewed_units(self, references: list[tuple]) -> bool:
        """Accept exact concatenations of reviewed units; never slice a unit."""
        references = tuple(references)
        reachable = {0}
        for position in range(len(references)):
            if position not in reachable:
                continue
            for unit in self.review_units:
                if references[position:position + len(unit)] == unit:
                    reachable.add(position + len(unit))
        return bool(references) and len(references) in reachable


def edition_mapper(edition_id: str, corpus: dict):
    """Validate each assembled source once before using its numeric crosswalk."""
    from reading_edition_mapping import mapper
    if not isinstance(corpus, (PinnedCorpus, ReviewedCorpus)) or not hasattr(corpus, "source_pins"):
        raise ValueError("Edition reference mapping requires a hash-checked source assembly")
    cached = getattr(corpus, "_edition_mapper", None)
    if cached is None or cached.edition_id != edition_id:
        cached = mapper(edition_id)
        cached.validate_source(corpus, corpus.source_pins)
        corpus._edition_mapper = cached
    return cached


def preserve_divine_name_accents(text: str) -> str:
    """Remove only niqqud on יהוה, retaining source cantillation and other text.

    Match the four letters with combining Hebrew marks, including after a prefix.
    Do not strip the prefix's vowel, normalize other words, or invent an accent.
    """
    pattern = r"י[\u0591-\u05bd\u05bf\u05c1\u05c2\u05c4\u05c5\u05c7]*ה[\u0591-\u05bd\u05bf\u05c1\u05c2\u05c4\u05c5\u05c7]*ו[\u0591-\u05bd\u05bf\u05c1\u05c2\u05c4\u05c5\u05c7]*ה[\u0591-\u05bd\u05bf\u05c1\u05c2\u05c4\u05c5\u05c7]*"
    return re.sub(pattern, lambda match: re.sub(r"[\u05b0-\u05bc\u05c7]", "", match.group()), text)


def parse_citation(citation: str, *, expand_subverses: bool = False) -> tuple[str, list[tuple[int, int, int, int]]]:
    """Keep ordered omissions; optionally include the whole verses around a/b cuts.

    This never guesses the words belonging to a subverse. Reviewed source units
    remain strict. Only the passage builder opts in and records the expansion.
    """
    match = re.fullmatch(r"(.+?)\s+(\d+:.*)", citation)
    if not match or match[1] not in BOOKS:
        raise Unavailable("unsupported citation or book")
    spans = []
    chapter = None
    previous_end = None
    for part in re.split(r"[;,]", match[2].replace("–", "-").replace("—", "-")):
        token = re.fullmatch(r"\s*(?:(\d+):)?(\d+)([a-d]*)(?:-(?:(\d+):)?(\d+)([a-d]*))?\s*", part)
        if not token:
            raise Unavailable("alternative or malformed citation")
        start_parts, end_parts = token[3], token[6] or ""
        if (start_parts or end_parts) and not expand_subverses:
            raise Unavailable("subverse requires whole-verse expansion")
        if any(value != "".join(sorted(set(value))) for value in (start_parts, end_parts)):
            raise Unavailable("malformed subverse")
        start_chapter = int(token[1]) if token[1] else chapter
        if start_chapter is None:
            raise Unavailable("missing chapter")
        start_verse = int(token[2])
        end_chapter = int(token[4]) if token[4] else start_chapter
        end_verse = int(token[5]) if token[5] else start_verse
        if not token[5]:
            end_parts = start_parts
        start_position = (start_chapter, start_verse, start_parts[:1] or "a")
        end_position = (end_chapter, end_verse, end_parts[-1:] or "z")
        if min(start_chapter, start_verse, end_chapter, end_verse) < 1 or (end_chapter, end_verse) < (start_chapter, start_verse):
            raise Unavailable("empty or reversed span")
        if end_position < start_position:
            raise Unavailable("reversed subverse span")
        start, end = (start_chapter, start_verse), (end_chapter, end_verse)
        overlapping = [index for index, span in enumerate(spans)
                       if start <= span[2:] and end >= span[:2]]
        if overlapping:
            # 16a,16b or 1b-3a,3bc become one enclosing span, without repeating
            # the shared verse. Actual overlaps and reordered cuts stay invalid.
            if (overlapping != [len(spans) - 1] or spans[-1][2:] != start
                    or previous_end is None or start_position <= previous_end):
                raise Unavailable("duplicate or overlapping appointment")
            spans[-1] = (*spans[-1][:2], end_chapter, end_verse)
        else:
            spans.append((start_chapter, start_verse, end_chapter, end_verse))
        previous_end = end_position
        chapter = end_chapter
    if not spans:
        raise Unavailable("empty citation")
    return BOOKS[match[1]], spans


def includes_whole_verses(citation: str) -> bool:
    """Called only after successful parsing; metadata, never a runtime parser."""
    return bool(re.search(r"\d[a-d]", citation))


def source_bytes(source: dict, fetch: bool = False) -> bytes:
    local_review = source["format"] == "reviewed-verses"
    label = source["path"] if local_review else source["cache"]
    path = ROOT / label if local_review else CACHE / label
    if local_review and not path.resolve().is_relative_to((ROOT / "Shared/content").resolve()):
        raise ValueError("Reviewed Scripture source must be canonical Shared/content data")
    if not path.exists():
        if local_review:
            raise ValueError(f"Missing reviewed Scripture source {label}; transcribe and review before importing")
        if not fetch:
            raise ValueError(f"Missing source {label}; run --fetch")
        request = urllib.request.Request(source["url"], headers={"User-Agent": "Prosary offline Bible passage builder"})
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read(30_000_001)
        if len(raw) > 30_000_000:
            raise ValueError("Source exceeds size limit")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
    raw = path.read_bytes()
    if source["format"] == "vplzip":
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            raw = archive.read(source["member"])
    actual = hashlib.sha256(raw).hexdigest()
    if actual != source["sha256"]:
        raise ValueError(f"Source checksum changed: {label} ({actual}); review before updating the source lock")
    return raw


def load_source(source: dict) -> dict[tuple[str, int], dict[int, str]]:
    raw = source_bytes(source)
    chapters = defaultdict(dict)
    def add(book: str, chapter: int, verse: int, text: str) -> None:
        if verse in chapters[book, chapter]:
            raise ValueError(f"Duplicate verse: {source['id']} {book} {chapter}:{verse}")
        chapters[book, chapter][verse] = text
    if source["format"] == "vplzip":
        for line in raw.decode("utf-8-sig").splitlines():
            match = re.fullmatch(r"(\S+) (\d+):(\d+) (.*)", line)
            if not match:
                raise ValueError(f"Unsupported source line in {source['cache']}")
            code = VPL_CODES.get(match[1], match[1])
            if code not in CODES:
                raise ValueError(f"Unrecognized source book: {code}")
            add(code, int(match[2]), int(match[3]), match[4])
    elif source["format"] == "scrollmapper":
        for book in json.loads(raw)["books"]:
            name = JSON_ALIASES.get(book["name"], book["name"])
            if name not in BOOKS:
                raise ValueError(f"Unrecognized source book: {name}")
            for chapter in book["chapters"]:
                for verse in chapter["verses"]:
                    add(BOOKS[name], chapter["chapter"], verse["verse"], verse["text"])
    elif source["format"] == "martini":
        data = json.loads(raw)
        for verse in data["v"]:
            add(source["book"], data["c"], verse["n"], verse["t"])
    elif source["format"] == "delitzsch-html":
        from delitzsch_source import parse_chapter, apply_reviewed_corrections
        if source["book"] not in NT or type(source["chapter"]) is not int or source["chapter"] < 1:
            raise ValueError("Invalid Delitzsch source chapter")
        for verse, text in apply_reviewed_corrections(source, parse_chapter(raw)).items():
            add(source["book"], source["chapter"], verse, text)
    elif source["format"] in {"peshitta-tei", "peshitta-isaiah"}:
        from peshitta_reading_source import load_verses
        for (chapter, verse), text in load_verses(source, raw).items():
            add(source["book"], chapter, verse, text)
    elif source["format"] == "reviewed-verses":
        data = json.loads(raw)
        if data["edition"]["id"] != source["editionId"]:
            raise ValueError("Reviewed Scripture edition differs from its source lock")
        # Every transcribed verse must identify the scanned PDF page(s) actually
        # inspected. Neither OCR text nor a publisher label establishes review.
        for name, book in data["verses"].items():
            if name not in BOOKS:
                raise ValueError(f"Unrecognized reviewed source book: {name}")
            for chapter, verses in book.items():
                for verse, text in verses.items():
                    pages = data["pages"].get(name, {}).get(chapter, {}).get(verse)
                    pages = pages if isinstance(pages, list) else [pages]
                    if (not re.fullmatch(r"[1-9]\d*", chapter)
                            or not re.fullmatch(r"[1-9]\d*", verse)
                            or not isinstance(text, str) or not text.strip()
                            or not pages or any(type(page) is not int or page < 1 for page in pages)):
                        raise ValueError(f"Invalid or unreviewed source verse: {name} {chapter}:{verse}")
                    add(BOOKS[name], int(chapter), int(verse), text)
        units = []
        if not isinstance(data.get("reviewUnits"), list) or not data["reviewUnits"]:
            raise ValueError("Reviewed Scripture requires explicit reviewed passage units")
        for citation in data["reviewUnits"]:
            book, spans = parse_citation(citation)
            unit = []
            for sc, sv, ec, ev in spans:
                # None of the currently reviewed units crosses a chapter. A
                # future one needs explicit inspected endpoints, not inferred
                # chapter lengths from a sparse transcription.
                if sc != ec:
                    raise ValueError("Cross-chapter review units require a separate boundary review")
                for verse in range(sv, ev + 1):
                    if verse not in chapters.get((book, sc), {}):
                        raise ValueError(f"Review unit contains an untranscribed verse: {citation}")
                    unit.append((book, sc, verse))
            if len(unit) != len(set(unit)):
                raise ValueError(f"Review unit repeats a verse: {citation}")
            units.append(tuple(unit))
        return ReviewedCorpus(dict(chapters), source["editionId"], units)
    else:
        raise ValueError("Unknown source format")
    return dict(chapters)


def appointments() -> dict[str, set[str]]:
    result = defaultdict(set)
    for name in ("roman", "roman1962", "ugcc", "ugcc-gregorian", "syriac", "maronite"):
        for day in json.loads((DATA / f"readings-{name}.json").read_text())["days"].values():
            for reading in day.get("readings", []):
                result["daily|" + reading["full"]].add(name)
    for day in json.loads((DATA / "torah-portions.json").read_text())["days"].values():
        for reading in day.get("readings", []):
            result["torah|" + reading["full"]].add("torah")
    return result


def resolve_nabre_references(book: str, spans: list[tuple], edition: dict,
                             corpus: dict) -> tuple[list[tuple], bool]:
    """Resolve an explicitly reviewed NABRE appointment into existing source rows."""
    from reading_nabre_mapping import mapper as nabre_mapper
    from reading_step_mapping import Unavailable as MappingUnavailable
    converter = nabre_mapper()  # Requires the complete, reference-only source inventory.
    try:
        source_refs = [reference for span in spans for reference in converter.inventory.span(book, *span)]
        standard, whole = converter.to_standard(source_refs)
        references, target_whole = edition_mapper(edition["id"], corpus).from_standard(standard)
        whole |= target_whole
    except MappingUnavailable as error:
        raise Unavailable(str(error)) from error
    except ValueError as error:
        # Invalid individual source spans are unavailable; an absent/incomplete
        # inventory fails above at construction and must stop regeneration.
        if isinstance(error, Unavailable):
            raise
        from nabre_versification import InvalidInventory
        if not isinstance(error, InvalidInventory):
            raise
        raise Unavailable(str(error)) from error
    references = list(dict.fromkeys(tuple(reference) for reference in references))
    if (not references or any(ref[0] != book or type(ref[1]) is not int or type(ref[2]) is not int
                              or ref[1] < 1 or ref[2] < 1 for ref in references)):
        raise Unavailable("target edition cannot represent this source book or verse label")
    return references, whole


def resolve_hebrew_psalm_references(book: str, spans: list[tuple], edition: dict,
                                    corpus: dict) -> tuple[list[tuple], bool]:
    """Use source-verified Hebrew verse numbers and the existing edition crosswalk."""
    from reading_versification import chapter_verse_count
    from reading_psalm_mapping import hebrew_psalm_to_standard
    from reading_step_mapping import Unavailable as MappingUnavailable
    if book != "PSA":
        raise ValueError("A Hebrew Psalm review cannot reinterpret another book")
    source_refs = []
    for sc, sv, ec, ev in spans:
        for chapter in range(sc, ec + 1):
            count = chapter_verse_count(book, chapter, "org")
            start, end = (sv if chapter == sc else 1), (ev if chapter == ec else count)
            if not count or not 1 <= start <= end <= count:
                raise Unavailable("appointment outside reviewed Hebrew Psalm chapter")
            source_refs.extend((book, chapter, verse) for verse in range(start, end + 1))
    try:
        standard, whole = hebrew_psalm_to_standard(source_refs)
        references, target_whole = edition_mapper(edition["id"], corpus).from_standard(standard)
    except MappingUnavailable as error:
        raise Unavailable(str(error)) from error
    if not references or any(ref[0] != book or ref[1] < 1 or ref[2] < 1 for ref in references):
        raise Unavailable("target edition cannot represent this Psalm verse label")
    return list(dict.fromkeys(tuple(ref) for ref in references)), whole or target_whole


def resolve(key: str, contexts: set[str], edition: dict, corpus: dict) -> ResolvedPassage:
    # The helper is intentionally build-time only; native apps never parse citations.
    from reading_versification import map_reference, chapter_verse_count, chapter_matches
    from reading_appointment_reviews import reviewed_appointment, reviewed_references
    from reading_source_numbering_reviews import reviewed_numbering
    scope, citation = key.split("|", 1)
    book, spans = parse_citation(citation, expand_subverses=True)
    if scope == "torah":
        source_systems = ["org"]
    elif book in NT and contexts == {"roman1962"}:
        source_systems = ["vul"]
    else:
        # Daily tables do not yet declare a versification. Only emit a passage
        # when every supported numbering tradition resolves it to identical verses.
        # English book labels do not prove English numbering (including in the NT).
        # Ambiguous references stay visible as citations, without text.
        source_systems = ["org", "eng", "vul", "rso"]
    target_system = edition["ntSystem"] if book in NT else edition["otSystem"]
    canonical_target_system = "eng" if target_system == "delitzsch-1901" else target_system
    candidates = []
    whole = includes_whole_verses(citation)
    uses_step_inventory = False
    review = reviewed_appointment(key, contexts)
    if review is not None:
        references = reviewed_references(review, edition["id"])
        if not references:
            raise Unavailable("edition outside reviewed appointment boundaries")
        if any(reference[0] != book for reference in references):
            raise ValueError("Reviewed appointment changes its Bible book")
        candidates.append(references)
        source_systems = []
        whole |= review["includesWholeVerses"]
    elif (numbering_review := reviewed_numbering(key, contexts)) is not None:
        resolver = (resolve_hebrew_psalm_references if numbering_review["sourceSystem"] == "hebrew-psalms"
                    else resolve_nabre_references)
        references, mapped_whole = resolver(book, spans, edition, corpus)
        candidates.append(references)
        source_systems = []
        whole |= mapped_whole
        uses_step_inventory = True
    for source_system in source_systems:
        references = []
        for sc, sv, ec, ev in spans:
            for chapter in range(sc, ec + 1):
                count = chapter_verse_count(book, chapter, source_system)
                if not count:
                    raise Unavailable("missing source versification")
                start = sv if chapter == sc else 1
                end = ev if chapter == ec else count
                if not 1 <= start <= end <= count:
                    raise Unavailable("appointment outside source chapter")
                for verse in range(start, end + 1):
                    mapped = map_reference(book, chapter, verse, source_system, canonical_target_system)
                    if not mapped or len(mapped) != 1 or mapped[0][0] != book:
                        raise Unavailable("unreviewed split or numbering mapping")
                    references.append(tuple(mapped[0]))
        candidates.append(references)
    if any(candidate != candidates[0] for candidate in candidates[1:]):
        raise Unavailable("ambiguous appointment numbering")
    if target_system == "delitzsch-1901" and not uses_step_inventory:
        from delitzsch_numbering import source_references
        try:
            candidates = [source_references(candidates[0])]
        except ValueError as error:
            raise Unavailable(str(error)) from error
    if isinstance(corpus, PinnedCorpus):
        # Source completeness is independent of a calendar's numbering. Keep
        # both the edition's reviewed exclusions and the legacy inventory guard;
        # new local correspondences do not certify an unreviewed appointment.
        excluded = edition_mapper(edition["id"], corpus).excluded_chapters
        if any(reference[:2] in excluded for reference in candidates[0]):
            raise Unavailable("source chapter excluded by its edition review")
    if isinstance(corpus, ReviewedCorpus):
        if edition.get("coveragePolicy") != "reviewed-units" or corpus.edition_id != edition["id"]:
            raise ValueError("Reviewed Scripture corpus requires its matching edition and boundary policy")
        if not corpus.covers_reviewed_units(candidates[0]):
            raise Unavailable("appointment is not a complete reviewed passage unit")
    elif edition.get("coveragePolicy") == "reviewed-units":
        raise ValueError("Reviewed passage policy requires a verified reviewed source")
    result = []
    seen = set()
    for mapped_book, chapter, verse in candidates[0]:
        values = corpus.get((mapped_book, chapter), {})
        # Whole-chapter validation catches shifted/merged trailing empty verses in
        # the existing Crampon transcription and incomplete upstream Martini data.
        if isinstance(corpus, ReviewedCorpus):
            if verse not in values or not values[verse].strip():
                raise Unavailable("reviewed source verse unavailable")
        else:
            if edition["id"] == "peshitta-1905" and mapped_book == "ISA":
                from reading_edition_reviews_peshitta import REVIEWED_ISAIAH
                complete = (isinstance(corpus, PinnedCorpus) and corpus.chapter_matches(mapped_book, chapter)
                            and (chapter, verse) in REVIEWED_ISAIAH)
            elif uses_step_inventory:
                complete = (edition_mapper(edition["id"], corpus).chapter_available(mapped_book, chapter)
                            and corpus.chapter_matches(mapped_book, chapter))
            elif target_system == "delitzsch-1901":
                from delitzsch_numbering import chapter_matches as source_chapter_matches
                complete = source_chapter_matches(mapped_book, chapter, values)
            else:
                complete = chapter_matches(target_system, mapped_book, chapter, values)
            if not complete or any(not value.strip() for value in values.values()):
                raise Unavailable("source chapter incomplete or numbering differs")
        if (chapter, verse) in seen:
            raise Unavailable("duplicate or overlapping appointment")
        seen.add((chapter, verse))
        text = values[verse]
        if edition["languageCode"] == "he":
            text = preserve_divine_name_accents(text)
        row = {"chapter": chapter, "verse": verse, "text": text}
        if edition.get("textScript") or edition.get("transliteratedTextScript"):
            if (edition["id"] != "peshitta-1905" or edition.get("textScript") != "Hebr"
                    or edition.get("transliteratedTextScript") != "Syrc"):
                raise ValueError("Paired Bible scripts require their reviewed source projection")
            from peshitta_reading_source import paired_text
            row["text"], row["transliteratedText"] = paired_text(text)
        result.append(row)
    if not result:
        raise Unavailable("empty passage")
    return ResolvedPassage(result, includes_whole_verses=whole)


def load_pinned_corpora(fetch: bool = False) -> tuple[dict, dict]:
    """Assemble the exact checked sources for both text and reference metadata."""
    lock = json.loads(LOCK.read_text())
    sources = lock["sources"]
    pins_by_source = {source["id"]: source["sha256"] for source in sources}
    if fetch:
        with ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda source: source_bytes(source, True), sources))
    raw_corpora = {}
    for source in sources:
        raw_corpora[source["id"]] = load_source(source)
    corpora = {}
    for edition in lock["editions"]:
        corpus = {}
        if edition.get("coveragePolicy") == "reviewed-units":
            if len(edition["sources"]) != 1 or "testament" in edition["sources"][0]:
                raise ValueError("Reviewed sparse editions must use one unmixed source")
            corpus = raw_corpora[edition["sources"][0]["id"]]
            if not isinstance(corpus, ReviewedCorpus) or corpus.edition_id != edition["id"]:
                raise ValueError("Reviewed source does not match the selected edition")
            corpus.source_pins = {reference["id"]: pins_by_source[reference["id"]] for reference in edition["sources"]}
            corpora[edition["id"]] = corpus
            continue
        for reference in edition["sources"]:
            source_id = reference["id"]
            if isinstance(raw_corpora[source_id], ReviewedCorpus):
                raise ValueError("Reviewed sparse sources cannot be mixed with complete imported chapters")
            allowed = NT if reference.get("testament") == "nt" else set(CODES) - NT if reference.get("testament") == "ot" else set(CODES)
            for chapter, verses in raw_corpora[source_id].items():
                if chapter[0] in allowed:
                    if chapter in corpus:
                        raise ValueError(f"Duplicate source chapter in {edition['id']}: {chapter}")
                    corpus[chapter] = verses
        source_pins = {reference["id"]: pins_by_source[reference["id"]] for reference in edition["sources"]}
        corpora[edition["id"]] = PinnedCorpus(corpus, source_pins)
    return lock, corpora


def build(fetch: bool = False) -> dict[str, bytes]:
    lock, corpora = load_pinned_corpora(fetch)
    metadata_keys = ("id", "languageCode", "name", "attribution", "sourceURL",
                     "textScript", "transliteratedTextScript")
    editions = [{key: edition[key] for key in metadata_keys if key in edition} for edition in lock["editions"]]
    passages = {}
    failures = defaultdict(Counter)
    missing = defaultdict(dict)
    keys = appointments()
    for key, contexts in sorted(keys.items()):
        by_edition = {}
        for edition in lock["editions"]:
            try:
                by_edition[edition["id"]] = resolve(key, contexts, edition, corpora[edition["id"]])
            except Unavailable as error:
                failures[edition["id"]][str(error)] += 1
                missing[key][edition["id"]] = str(error)
        if by_edition:
            passages[key] = by_edition
    # The schema's key-level notice is deliberately conservative: if any selected
    # edition needs a larger source-verse envelope, every edition for the same raw
    # appointment key retains the full-verse notice.
    whole_verse_passages = [key for key, values in passages.items()
                           if any(value.includes_whole_verses for value in values.values())]
    payload = {"schemaVersion": 1, "editions": editions, "passages": passages,
               "wholeVersePassages": whole_verse_passages}
    report = {"schemaVersion": 1, "uniqueAppointments": len(keys), "passagesWithAnyEdition": len(passages),
              "coverage": {edition["id"]: {"daily": sum(key.startswith("daily|") and edition["id"] in value for key, value in passages.items()),
                  "torah": sum(key.startswith("torah|") and edition["id"] in value for key, value in passages.items()),
                  "unavailableReasons": dict(failures[edition["id"]])} for edition in editions}, "unavailable": dict(missing)}
    encode = lambda value: (json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n").encode()
    return {"readings-editions.json": encode({"schemaVersion": 1, "editions": editions}),
            "readings-texts.json": encode(payload), "readings-text-coverage.json": encode(report)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--sync", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for name, content in build(args.fetch).items():
        path = (REPORTS if name == "readings-text-coverage.json" else DATA) / name
        if args.check:
            if not path.exists() or path.read_bytes() != content:
                raise SystemExit(f"Out of date: {path.relative_to(ROOT)}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        if args.sync and name != "readings-text-coverage.json":
            for target in TARGETS:
                if args.check:
                    if not (target / name).exists() or (target / name).read_bytes() != content:
                        raise SystemExit(f"Out of date: {(target / name).relative_to(ROOT)}")
                else:
                    shutil.copyfile(path, target / name)
        print(f"{'Checked' if args.check else 'Built'} {name}: {len(content):,} bytes")


if __name__ == "__main__":
    main()

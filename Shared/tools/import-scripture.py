#!/usr/bin/env python3
"""Fills a bundle's Aramaic scripture from the Peshitta, in both alphabets.

Every Scripture body a bundle ships already names its passage — the Latin text ends
"— Luc. 1:26-38 (Vulgata)". That citation is the input here: this reads it, pulls the same
verses from the Peshitta, and writes them into content/arc.json. Nothing is composed by hand,
which is the point — a verse in a prayer app has to come from an edition someone can check,
not from anyone's memory.

Two alphabets, one text. Classical Syriac and Hebrew are both 22-letter abjads descended from
the same Imperial Aramaic script, so the letters map one to one, reversibly, with no
transcription judgement involved — the round trip is asserted over the whole alphabet on every
run. Syriac diacritics have no Hebrew counterpart and are dropped from the Hebrew form only.
Following the
catalogue's own promise that "arc" is Aramaic in Hebrew script, the Hebrew-lettered form is
what content/arc.json ships as its prayers, and the Syriac original rides along in the same
file's "transliterations" map, which is what the prayer flow's script toggle reads.

The text is unpointed, exactly as the source has it. That is the same courtesy the Latin
Patriarchate's Divine Mercy Hebrew gets: pointing a text is an editorial act, and not this
tool's to perform.

    sources   ETCBC/syrnt      Peshitta New Testament   MIT     (Dirk Roorda / ETCBC, VU Amsterdam)
              ETCBC/peshitta   Peshitta Old Testament   MIT     (Dirk Roorda / ETCBC, VU Amsterdam)

    usage: import-scripture.py [bundle ...]   default: every bundle with Latin citations
           import-scripture.py --check        re-derive and diff, writing nothing (CI)
"""

from __future__ import annotations

import json
import re
import sys
import unicodedata
import urllib.request
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
CONTENT = TOOLS.parent / "content"
CACHE = TOOLS / ".scripture-cache"

SOURCES = {
    "nt": ("https://raw.githubusercontent.com/ETCBC/syrnt/master/plain/0.1/{book}.txt",
           "Peshitta New Testament (ETCBC/syrnt, MIT)"),
    "ot": ("https://raw.githubusercontent.com/ETCBC/peshitta/master/plain/0.2/{book}.txt",
           "Peshitta Old Testament (ETCBC/peshitta, MIT)"),
}

# The Latin abbreviations the bundles actually use -> (testament, Peshitta file stem).
BOOKS = {
    "Matt": ("nt", "Matthew"), "Matth": ("nt", "Matthew"),
    "Marc": ("nt", "Mark"),
    "Luc": ("nt", "Luke"),
    "Ioan": ("nt", "John"), "Ioann": ("nt", "John"), "Joan": ("nt", "John"),
    "Act": ("nt", "Acts"),
    "Apoc": ("nt", "Revelation"),
    "Is": ("ot", "Isaiah"), "Isaias": ("ot", "Isaiah"),
}

# How each book is named in the citation line the Aramaic text carries, in both alphabets.
BOOK_NAMES = {
    "Matthew": ("ܡܬܝ", "מתי"),
    "Mark": ("ܡܪܩܘܣ", "מרקוס"),
    "Luke": ("ܠܘܩܐ", "לוקא"),
    "John": ("ܝܘܚܢܢ", "יוחנן"),
    "Acts": ("ܦܪܟܣܝܣ", "פרכסיס"),
    "Revelation": ("ܓܠܝܢܐ", "גלינא"),
    "Isaiah": ("ܐܫܥܝܐ", "אשעיא"),
}

EDITION = ("ܦܫܝܛܬܐ", "פשיטתא")

# Classical Syriac -> Hebrew square script. Both alphabets are the same 22 letters in the same
# order, so this is a transliteration in the strict sense: one letter for one letter, nothing
# interpreted. Hebrew's five final forms are deliberately NOT used — Syriac has no such thing,
# and introducing them would make the mapping lossy in the other direction.
SYRIAC_TO_HEBREW = {
    "ܐ": "א",  # ālaph      -> alef
    "ܒ": "ב",  # bēth       -> bet
    "ܓ": "ג",  # gāmal      -> gimel
    "ܕ": "ד",  # dālath     -> dalet
    "ܗ": "ה",  # hē         -> he
    "ܘ": "ו",  # waw        -> vav
    "ܙ": "ז",  # zain       -> zayin
    "ܚ": "ח",  # ḥēth       -> het
    "ܛ": "ט",  # ṭēth       -> tet
    "ܝ": "י",  # yudh       -> yod
    "ܟ": "כ",  # kāph       -> kaf
    "ܠ": "ל",  # lāmadh     -> lamed
    "ܡ": "מ",  # mim        -> mem
    "ܢ": "נ",  # nun        -> nun
    "ܣ": "ס",  # semkath    -> samekh
    "ܥ": "ע",  # ʿē         -> ayin
    "ܦ": "פ",  # pē         -> pe
    "ܨ": "צ",  # ṣādhē      -> tsadi
    "ܩ": "ק",  # qāph       -> qof
    "ܪ": "ר",  # rish       -> resh
    "ܫ": "ש",  # shin       -> shin
    "ܬ": "ת",  # taw        -> tav
}
HEBREW_TO_SYRIAC = {v: k for k, v in SYRIAC_TO_HEBREW.items()}

# Syriac diacritics — vowels, the seyame plural dots, the marks that tell homographs apart.
# They are NOT all in the Syriac Unicode block: the ETCBC text writes seyame and the qushshaya
# dots as plain combining marks (U+0307, U+0308), so matching on the block alone silently leaves
# them in the Hebrew. Every nonspacing mark goes instead. Hebrew script has no counterpart for
# any of them, so the Hebrew-lettered form drops them rather than carrying marks that mean
# nothing there; the Syriac form, which is what a Syriac reader reads, keeps every one. This is
# the one respect in which the two forms differ, and why the round trip is asserted on letters.

CITATION = re.compile(r"—\s*([^\n(]+?)\s*\(([^)]+)\)\s*$")
REFERENCE = re.compile(r"^([1-3]?\s*[A-Za-z]+)\.?\s+(.+)$")

errors: list[str] = []


def err(message: str) -> None:
    errors.append(message)


def to_hebrew(syriac: str) -> str:
    return "".join(SYRIAC_TO_HEBREW.get(ch, ch) for ch in syriac
                   if unicodedata.category(ch) != "Mn")


def to_syriac(hebrew: str) -> str:
    return "".join(HEBREW_TO_SYRIAC.get(ch, ch) for ch in hebrew)


def fetch(testament: str, book: str) -> str:
    CACHE.mkdir(exist_ok=True)
    cached = CACHE / f"{testament}-{book}.txt"
    if not cached.exists():
        url = SOURCES[testament][0].format(book=book)
        print(f"  fetching {url}", file=sys.stderr)
        with urllib.request.urlopen(url, timeout=60) as response:
            cached.write_bytes(response.read())
    return cached.read_text(encoding="utf-8")


def verses(testament: str, book: str) -> dict:
    """(chapter, verse) -> Syriac text.

    The two ETCBC sets are laid out differently and neither is quite predictable from the
    filename. The Old Testament heads a chapter "Chapter 3". The New Testament heads it with the
    abbreviation the file declares in its own first line — "Matthew (Matt)" means chapters read
    "Matt 3", while "Mark (Mark)" means "Mark 3" — so that word is read from the file rather than
    guessed at. A long verse in either set may wrap onto continuation lines carrying no number.
    """
    table: dict = {}
    chapter = None
    current = None
    lines = fetch(testament, book).splitlines()
    words = {re.escape(book.replace("_", " ")), "Chapter"}
    for line in lines:
        declared = re.match(r"^\s*(.+?)\s+\((.+?)\)\s*$", line)
        if declared:
            words.add(re.escape(declared.group(2).strip()))
        if line.strip():
            break
    header_pattern = rf"^(?:{'|'.join(sorted(words))})\s+(\d+)$"
    for line in lines:
        line = line.strip()
        if not line:
            continue
        header = re.match(header_pattern, line)
        if header:
            chapter = int(header.group(1))
            current = None
            continue
        if re.match(r"^[A-Za-z0-9_ ]+\s+\([A-Za-z0-9_ ]+\)$", line):
            continue  # the file's own title line
        verse = re.match(r"^(\d+)\s+(.+)$", line)
        if verse and chapter is not None:
            current = (chapter, int(verse.group(1)))
            table[current] = verse.group(2).strip()
        elif current is not None:
            # A wrapped continuation of the verse above.
            table[current] = f"{table[current]} {line}".strip()
    return table


def parse_reference(reference: str) -> list:
    """"14:55, 60-64" -> [(14,55,55), (14,60,64)]. Chapter carries across segments."""
    spans, chapter = [], None
    for segment in reference.split(","):
        segment = segment.strip()
        if ":" in segment:
            head, _, segment = segment.partition(":")
            chapter = int(head.strip())
        if chapter is None:
            return []
        if "-" in segment:
            first, _, last = segment.partition("-")
            spans.append((chapter, int(first), int(last)))
        else:
            spans.append((chapter, int(segment), int(segment)))
    return spans


def passage(book: str, testament: str, spans: list, where: str) -> str | None:
    table = verses(testament, book)
    out = []
    for chapter, first, last in spans:
        for number in range(first, last + 1):
            text = table.get((chapter, number))
            if text is None:
                err(f"{where}: {book} {chapter}:{number} is not in the source")
                return None
            out.append(text)
    return " ".join(out)


def citation_line(book: str, reference: str, syriac: bool) -> str:
    name = BOOK_NAMES[book][0 if syriac else 1]
    edition = EDITION[0 if syriac else 1]
    return f"\n\n— {name} {reference} ({edition})"


def build(bundle: Path) -> dict | None:
    latin_path = bundle / "content" / "la.json"
    if not latin_path.exists():
        return None
    latin = json.loads(latin_path.read_text(encoding="utf-8"))

    texts = dict(latin.get("prayers", {}))
    mysteries = {k: m for k, m in (latin.get("mysteries") or {}).items()
                 if isinstance(m, dict) and m.get("description")}

    prayers, transliterations, mystery_out, skipped = {}, {}, {}, []
    for key, value in list(texts.items()) + [(f"mystery:{k}", m["description"])
                                             for k, m in mysteries.items()]:
        match = CITATION.search(value.strip())
        if not match:
            continue
        reference_match = REFERENCE.match(match.group(1).strip())
        if not reference_match:
            err(f"{bundle.name}:{key}: cannot read citation {match.group(1)!r}")
            continue
        abbreviation, reference = reference_match.group(1), reference_match.group(2)
        if abbreviation not in BOOKS:
            err(f"{bundle.name}:{key}: unknown book {abbreviation!r}")
            continue
        testament, book = BOOKS[abbreviation]
        spans = parse_reference(reference)
        if not spans:
            err(f"{bundle.name}:{key}: cannot read reference {reference!r}")
            continue
        syriac = passage(book, testament, spans, f"{bundle.name}:{key}")
        if syriac is None:
            continue

        syriac_body = syriac + citation_line(book, reference, syriac=True)
        hebrew_body = to_hebrew(syriac) + citation_line(book, reference, syriac=False)
        if key.startswith("mystery:"):
            # Deliberately not written. A mystery override is an all-or-nothing MysteryText on
            # every platform — title, fruit and description are non-optional — so writing a
            # description-only entry would blank out the announcement's title and its fruit
            # rather than letting them fall back. And title/fruit are not Scripture: they are
            # the mystery's name and what it asks for, which belong to a community's own usage,
            # not to a Bible edition. Unblocking this means letting a pack's mystery override
            # merge field by field; until then these announcements read in the fallback
            # language. Counted so the gap is reported rather than silent.
            skipped.append(f"{bundle.name}:{key[len('mystery:'):]}")
        else:
            prayers[key] = hebrew_body
            transliterations[key] = syriac_body

    if skipped:
        print(f"  {bundle.name}: {len(skipped)} mystery announcement(s) left alone "
              f"(need per-field mystery overrides)", file=sys.stderr)
    if not prayers:
        return None
    return {"prayers": prayers, "transliterations": transliterations, "mysteries": mystery_out}


def render(built: dict, existing: dict) -> dict:
    """Merge into whatever content/arc.json already holds — a hand-authored prayer must never be
    clobbered by a scripture import."""
    out = json.loads(json.dumps(existing)) if existing else {}
    out.setdefault("$comment",
                   "Scripture imported from the Peshitta by Shared/tools/import-scripture.py — "
                   "re-run it rather than editing these by hand. Prayers are Hebrew square "
                   "script; the same text in Syriac letters is in transliterations, which is "
                   "what the flow's script toggle shows. Unpointed, as the source has it.")
    prayers = out.setdefault("prayers", {})
    prayers.update(built["prayers"])
    if built["transliterations"]:
        out.setdefault("transliterations", {}).update(built["transliterations"])
    if built["mysteries"]:
        mysteries = out.setdefault("mysteries", {})
        for key, (hebrew, _syriac) in built["mysteries"].items():
            entry = mysteries.setdefault(key, {})
            entry["description"] = hebrew
            entry.setdefault("title", "")
            entry.setdefault("fruit", "")
    return out


def main() -> int:
    arguments = [a for a in sys.argv[1:] if not a.startswith("--")]
    check = "--check" in sys.argv[1:]

    # The letters must map exactly both ways, or the toggle is showing two different texts.
    # Checked on the whole alphabet, not a sample of it, and on real unpointed words.
    alphabet = "".join(SYRIAC_TO_HEBREW)
    if to_syriac(to_hebrew(alphabet)) != alphabet:
        err("the Syriac/Hebrew alphabet mapping does not round-trip")
    if len(set(SYRIAC_TO_HEBREW.values())) != len(SYRIAC_TO_HEBREW):
        err("two Syriac letters map onto one Hebrew letter — the mapping is lossy")
    for word in ("ܐܒܘܢ ܕܒܫܡܝܐ ܢܬܩܕܫ ܫܡܟ", "ܩܕܝܫܬ ܐܠܗܐ"):
        if to_syriac(to_hebrew(word)) != word:
            err(f"round trip failed for {word!r}")

    bundles = ([CONTENT / name for name in arguments] if arguments
               else sorted(p for p in CONTENT.iterdir() if (p / "manifest.json").exists()))

    changed = 0
    for bundle in bundles:
        built = build(bundle)
        if built is None:
            continue
        target = bundle / "content" / "arc.json"
        existing = json.loads(target.read_text(encoding="utf-8")) if target.exists() else {}
        rendered = render(built, existing)
        serialized = json.dumps(rendered, ensure_ascii=False, indent=2) + "\n"
        if target.exists() and target.read_text(encoding="utf-8") == serialized:
            continue
        changed += 1
        if check:
            err(f"{bundle.name}: content/arc.json is out of date (run import-scripture.py)")
            continue
        target.write_text(serialized, encoding="utf-8")
        print(f"{bundle.name}: {len(built['prayers'])} prayers, "
              f"{len(built['mysteries'])} mysteries")

    for message in errors:
        print(f"import-scripture: {message}", file=sys.stderr)
    if errors:
        return 1
    print(f"{'up to date' if not changed else f'wrote {changed} bundle(s)'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

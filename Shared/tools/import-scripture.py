#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Fills a bundle's Aramaic scripture from the Peshitta, in both alphabets.

Every Scripture body a bundle ships already names its passage — the Latin text ends
"— Luc. 1:26–38 (Vulgata)". That citation is the input here: this reads it, pulls the same
verses from the Peshitta, and writes them into content/arc.json. Nothing is composed by hand,
which is the point — a verse in a prayer app has to come from an edition someone can check,
not from anyone's memory.

Two alphabets, one text. The Hebrew-square projection uses the deterministic Syriac-to-Hebrew
converter Erez supplied: the corresponding letters, Hebrew final forms, five vowel signs,
qushshaya/dagesh, and the Syriac waw patterns all follow his rules. The current ETCBC source is
unpointed, so final forms are the only rule that changes these Peshitta passages today; no points
are invented. Unsupported Syriac marks are removed from the Hebrew projection, while the extracted
Syriac passage is left unchanged by conversion in the same file's "transliterations" map for the
prayer flow's script toggle.

    sources   ETCBC/syrnt      Peshitta New Testament   MIT     (Dirk Roorda / ETCBC, VU Amsterdam)
              ETCBC/peshitta   Peshitta Old Testament   MIT     (Dirk Roorda / ETCBC, VU Amsterdam)

    usage: import-scripture.py [bundle ...]   default: every bundle with Latin citations
           import-scripture.py --check        re-derive and diff, writing nothing
"""

from __future__ import annotations

import csv
import html
import io
import json
import re
import subprocess
import sys
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

from aramaic_script_converter import SYRIAC_TO_HEBREW, to_hebrew, to_syriac_letters

TOOLS = Path(__file__).resolve().parent
CONTENT = TOOLS.parent / "content"
CACHE = TOOLS / ".scripture-cache"

# Which book each Latin abbreviation in the bundles names. "ot"/"nt" only picks the source file;
# nothing else depends on the testament.
BOOKS = {
    "Matt": ("nt", "Matthew"), "Matth": ("nt", "Matthew"),
    "Marc": ("nt", "Mark"),
    "Luc": ("nt", "Luke"),
    "Ioan": ("nt", "John"), "Ioann": ("nt", "John"), "Joan": ("nt", "John"),
    "Act": ("nt", "Acts"),
    "Apoc": ("nt", "Revelation"),
    "Is": ("ot", "Isaiah"), "Isaias": ("ot", "Isaiah"),
}

# Each target language: where its text comes from, how a book is named in its citation line, and
# what the edition is called there. A language may render one text in two alphabets (Aramaic), in
# which case `second_script` names the transform and the result rides in "transliterations" —
# which is exactly what the prayer flow's script toggle reads.
LANGUAGES = {
    "fr": {
        "sources": {testament: (
            "https://raw.githubusercontent.com/scrollmapper/bible_databases/master/formats/json/FreCrampon.json",
            "scrollmapper", "Bible Augustin Crampon (1923), public domain; scrollmapper/bible_databases")
            for testament in ("ot", "nt")},
        "primary_script": None, "second_script": None,
        "books": {"Matthew": ("Matthieu",), "Mark": ("Marc",), "Luke": ("Luc",),
                  "John": ("Jean",), "Acts": ("Actes",), "Revelation": ("Apocalypse",),
                  "Isaiah": ("Isaïe",)},
        "edition": ("Crampon 1923",),
    },
    "it": {
        "sources": {testament: (
            "https://parolaviva.art/api/v1/bibbia/{book}/{chapter}.json",
            "martini", "Bibbia Martini (1769–1781), public domain; Parola Viva data by Giovanni Novelli, CC-BY 4.0")
            for testament in ("ot", "nt")},
        "primary_script": None, "second_script": None,
        "books": {"Matthew": ("Matteo",), "Mark": ("Marco",), "Luke": ("Luca",),
                  "John": ("Giovanni",), "Acts": ("Atti",), "Revelation": ("Apocalisse",),
                  "Isaiah": ("Isaia",)},
        "file_names": {"Matthew": "mt", "Mark": "mc", "Luke": "lc", "John": "gv",
                       "Acts": "at", "Revelation": "ap", "Isaiah": "is"},
        "edition": ("Martini",),
    },
    "arc": {
        "sources": {
            "nt": ("https://raw.githubusercontent.com/ETCBC/syrnt/master/plain/0.1/{book}.txt",
                   "plain", "Peshitta New Testament (ETCBC/syrnt, MIT)"),
            "ot": ("https://raw.githubusercontent.com/ETCBC/peshitta/master/plain/0.2/{book}.txt",
                   "plain", "Peshitta Old Testament (ETCBC/peshitta, MIT)"),
        },
        # The bundle ships Hebrew letters, per the catalogue's promise that "arc" is Aramaic in
        # Hebrew script; the Syriac original goes to transliterations.
        "primary_script": "hebrew",
        "second_script": "syriac",
        "books": {"Matthew": ("ܡܬܝ", "מתי"), "Mark": ("ܡܪܩܘܣ", "מרקוס"),
                  "Luke": ("ܠܘܩܐ", "לוקא"), "John": ("ܝܘܚܢܢ", "יוחנן"),
                  "Acts": ("ܦܪܟܣܝܣ", "פרכסיס"), "Revelation": ("ܓܠܝܢܐ", "גלינא"),
                  "Isaiah": ("ܐܫܥܝܐ", "אשעיא")},
        "edition": ("ܦܫܝܛܬܐ", "פשיטתא"),
        "hebrewChapterIndex": 1,
    },
    "es": {
        # Félix Torres Amat's Spanish Bible (1836), translated from the Vulgate — which is why it
        # is the right one here: every citation in this app is Vulgate chapter-and-verse, so no
        # versification map is needed. Public domain by age (Torres Amat died 1847); Wikisource
        # transcribes it from the volume scans, and only the New Testament volumes (XIII–XV) have
        # been transcribed, so Isaiah is absent and the O Antiphons' readings stay empty.
        "sources": {
            "nt": ("https://es.wikisource.org/w/api.php?action=parse&page={book}"
                   "&prop=text&format=json",
                   "wikisource", "La Sagrada Biblia, Félix Torres Amat (1836), public domain"),
        },
        "primary_script": None,
        "second_script": None,
        "books": {"Matthew": ("San Mateo",), "Mark": ("San Marcos",), "Luke": ("San Lucas",),
                  "John": ("San Juan",), "Acts": ("Hechos",), "Revelation": ("Apocalipsis",)},
        "edition": ("Torres Amat",),
        "file_names": {
            "Matthew": "La Sagrada Biblia (XIII)/Mateo",
            "Mark": "La Sagrada Biblia (XIII)/Marcos",
            "Luke": "La Sagrada Biblia (XIII)/Lucas",
            "John": "La Sagrada Biblia (XIII)/Juan",
            "Acts": "La Sagrada Biblia (XIV)/Hechos",
            "Revelation": "La Sagrada Biblia (XV)/Apocalipsis",
        },
    },
    "el": {
        # Robinson-Pierpont's Byzantine Majority text: accented polytonic Unicode and released
        # into the public domain outright. The Patriarchal 1904 edition is the same tradition and
        # was the first choice, but the only machine-readable form of it is accentless Beta Code,
        # and polytonic accents cannot be restored mechanically from that.
        "sources": {
            "nt": ("https://raw.githubusercontent.com/byztxt/byzantine-majority-text/master/"
                   "csv-unicode/ccat/no-variants/{book}.csv",
                   "csv", "Byzantine Majority Text (Robinson-Pierpont, public domain)"),
            # Brenton's Septuagint, accented and marked public domain by eBible.org. Every other
            # machine-readable accented LXX traces back to CCAT (BY-NC-SA) or Perseus (BY-SA),
            # whose claims sit on the digitisation rather than the long-public-domain edition
            # underneath — but a claim the app would have to honour either way.
            "ot": ("https://eBible.org/Scriptures/grcbrent_vpl.zip",
                   "vplzip", "Brenton's Septuagint (eBible.org grcbrent, public domain)"),
        },
        "primary_script": None,
        "second_script": None,
        "books": {"Matthew": ("Ματθαῖος",), "Mark": ("Μᾶρκος",), "Luke": ("Λουκᾶς",),
                  "John": ("Ἰωάννης",), "Acts": ("Πράξεις",), "Revelation": ("Ἀποκάλυψις",),
                  "Isaiah": ("Ἠσαΐας",)},
        "edition": ("Βυζαντινὸν κείμενον",),
        # A book's edition line follows the testament it comes from, not the language.
        "edition_by_testament": {"ot": ("Ἑβδομήκοντα",)},
        # Isaiah would need a Septuagint. Every machine-readable accented LXX found so far puts a
        # ShareAlike or NonCommercial claim on the digitisation even where the edition beneath it
        # is public domain by age, so the seven Isaiah readings wait for a source rather than
        # being filled from a licence the app cannot ship under.
        "file_names": {"Matthew": "MAT", "Mark": "MAR", "Luke": "LUK", "John": "JOH",
                       "Acts": "ACT", "Revelation": "REV", "Isaiah": "ISA"},
    },
}

# The script transform itself lives in aramaic_script_converter.py. It is separate from fetching
# and citation parsing so its behavior stays network-free, independently testable, and reusable
# for future pointed sources without ever rewriting the original Syriac track.

# The bundles cite the Vulgate's chapter-and-verse. The Peshitta and the Septuagint both follow
# the Hebrew numbering, which parts company with the Vulgate's in a handful of well-known places
# — and where it does, importing the cited number verbatim silently fetches the *wrong verse*.
# Isaiah 9 is the one this app actually touches: Hebrew 8:23 is the Vulgate's 9:1, so every
# Vulgate verse from 9:2 on sits one earlier in both sources. O Oriens cites Is. 9:2, "the people
# that walked in darkness", and without this it imported 9:3, "thou hast multiplied the nation".
# Verified against both sources and pinned by a self-check below; extend it per book/chapter as
# more of the Old Testament arrives, and never by guessing.
# Keyed by language/rite because the divergence belongs to the *source*. Both the verse lookup and
# the citation written into that rite's devotion text follow this mapping: a Peshitta passage must
# cite its Peshitta number, not retain the Vulgate number that was used to locate the passage.
# Torres Amat translated the Vulgate itself, so its table is empty; shifting it would introduce the
# very error this map exists to prevent.
# Passages a language's source genuinely does not contain, each with the reason. Declared rather
# than tolerated: a verse missing from the table is otherwise indistinguishable from a parser
# that has quietly stopped reading, and that is exactly the failure worth keeping loud.
SOURCE_GAPS = {
    # Wikisource's Torres Amat transcribes John through chapter 20 only — the scan's last
    # chapter has not been proofread, so the Via Lucis' two Johannine appearances have no
    # Spanish text yet. Remove this the day chapter 21 appears.
    "es": {("John", 21): "Wikisource has transcribed John only through chapter 20"},
}

VERSIFICATION = {
    "fr": {("Isaiah", 9): (2, -1)},  # Crampon follows Hebrew numbering here.
    "arc": {("Isaiah", 9): (2, -1)},  # (from this Vulgate verse onward, shift by this much)
    "el": {("Isaiah", 9): (2, -1)},
    "es": {},
}

CITATION = re.compile(r"—\s*([^\n(]+?)\s*\(([^)]+)\)\s*$")
REFERENCE = re.compile(r"^([1-3]?\s*[A-Za-z]+)\.?\s+(.+)$")

errors: list[str] = []


def err(message: str) -> None:
    errors.append(message)


def fetch(language: str, testament: str, book: str, binary: bool = False):
    spec = LANGUAGES[language]
    url_template, layout, _credit = spec["sources"][testament]
    stem = spec.get("file_names", {}).get(book, book)
    CACHE.mkdir(exist_ok=True)
    # A whole-testament archive is fetched once, not once per book.
    cached = CACHE / (f"{language}-bible.json" if layout == "scrollmapper" else
                      f"{language}-{testament}-archive" if layout == "vplzip"
                      else f"{language}-{testament}-{stem}".replace("/", "_"))
    if not cached.exists():
        url = url_template.format(book=urllib.parse.quote(stem, safe=""))
        print(f"  fetching {url}", file=sys.stderr)
        # eBible.org refuses urllib's default agent outright (403), so identify properly.
        request = urllib.request.Request(url, headers={
            "User-Agent": "Prosary-import-scripture/1.0 (+https://prosary.app)"})
        with urllib.request.urlopen(request, timeout=120) as response:
            cached.write_bytes(response.read())
    return cached.read_bytes() if binary else cached.read_text(encoding="utf-8")


def verses(language: str, testament: str, book: str) -> dict:
    """(chapter, verse) -> text, in whatever layout this language's source uses."""
    layout = LANGUAGES[language]["sources"][testament][1]
    if layout == "wikisource":
        return _verses_wikisource(language, testament, book)
    if layout == "scrollmapper":
        source_name = "Revelation of John" if book == "Revelation" else book
        source = next(row for row in json.loads(fetch(language, testament, book))["books"]
                      if row["name"] == source_name)
        return {(chapter["chapter"], verse["verse"]): verse["text"].strip()
                for chapter in source["chapters"] for verse in chapter["verses"]}
    if layout == "vplzip":
        stem = LANGUAGES[language].get("file_names", {}).get(book, book)
        table = {}
        raw = fetch(language, testament, book, binary=True)
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            name = next(n for n in archive.namelist() if n.endswith("_vpl.txt"))
            for line in archive.read(name).decode("utf-8").splitlines():
                match = re.match(rf"^{re.escape(stem)}\s+(\d+):(\d+)\s+(.*)$", line)
                if match:
                    table[(int(match.group(1)), int(match.group(2)))] = match.group(3).strip()
        return table
    if layout == "csv":
        table = {}
        for row in csv.DictReader(io.StringIO(fetch(language, testament, book))):
            table[(int(row["chapter"]), int(row["verse"]))] = row["text"].strip()
        return table
    return _verses_plain(language, testament, book)


def _verses_plain(language: str, testament: str, book: str) -> dict:
    """The ETCBC plain layout.

    The two ETCBC sets are laid out differently and neither is quite predictable from the
    filename. The Old Testament heads a chapter "Chapter 3". The New Testament heads it with the
    abbreviation the file declares in its own first line — "Matthew (Matt)" means chapters read
    "Matt 3", while "Mark (Mark)" means "Mark 3" — so that word is read from the file rather than
    guessed at. A long verse in either set may wrap onto continuation lines carrying no number.
    """
    table: dict = {}
    chapter = None
    current = None
    lines = fetch(language, testament, book).splitlines()
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


# Chapter headings in the 1836 printing are spelled out or set in Roman numerals, and change
# style partway through a volume — so both are read.
_SPANISH_ORDINALS = ("PRIMERO SEGUNDO TERCERO CUARTO QUINTO SEXTO SÉPTIMO OCTAVO NOVENO DÉCIMO"
                     .split())
_ROMAN = {"I": 1, "V": 5, "X": 10, "L": 50, "C": 100, "D": 500, "M": 1000}


def _roman(label: str) -> int | None:
    total = previous = 0
    for ch in reversed(label):
        value = _ROMAN.get(ch)
        if value is None:
            return None
        total = total - value if value < previous else total + value
        previous = max(previous, value)
    return total or None


def _chapter_number(label: str) -> int | None:
    label = label.strip().rstrip(".").upper()
    if label in _SPANISH_ORDINALS:
        return _SPANISH_ORDINALS.index(label) + 1
    return _roman(label)


def _verses_wikisource(language: str, testament: str, book: str) -> dict:
    """A transcribed scan, read through the MediaWiki parser.

    The book is one page transcluding a hundred-odd scan pages, so the rendered HTML is the only
    practical form. Chapters head as "CAPÍTULO PRIMERO." or "CAPÍTULO XIV.", verses run inline as
    a number followed by their text. Each chapter opens with an unnumbered summary paragraph
    whose own digits would otherwise read as verses, which is why only the first sighting of a
    (chapter, verse) is kept — the summary precedes verse 1, so a real verse always wins.
    """
    raw = json.loads(fetch(language, testament, book))
    if "error" in raw:
        err(f"{book}: Wikisource says {raw['error'].get('info')}")
        return {}
    text = raw["parse"]["text"]["*"]
    text = re.sub(r"<[^>]+>", "\n", text)
    text = html.unescape(text)
    text = re.sub(r"\[\d+\]", "", text)      # footnote markers
    text = re.sub(r"[ \t]+", " ", text)

    table: dict = {}
    parts = re.split(r"CAPÍTULO\s+([A-ZÁÉÍÓÚÑ]+|[IVXLCDM]+)\s*\.", text)
    for i in range(1, len(parts) - 1, 2):
        chapter = _chapter_number(parts[i])
        if chapter is None:
            continue
        body = re.sub(r"\s*\n\s*", " ", parts[i + 1])
        for m in re.finditer(r"(?:^|\s)—?\s*(\d{1,3})\s+(.+?)(?=\s—?\s*\d{1,3}\s|$)", body):
            key = (chapter, int(m.group(1)))
            if key not in table:
                table[key] = m.group(2).strip()
    return table


def parse_reference(reference: str) -> list:
    """"14:55, 60–64" -> [(14,55,55), (14,60,64)]. Chapter carries across segments."""
    spans, chapter = [], None
    for segment in reference.split(","):
        segment = segment.strip().replace("–", "-")
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


def source_verse(language: str, book: str, chapter: int, number: int, where: str) -> int | None:
    """The verse number this citation has in this language's source numbering."""
    rule = VERSIFICATION.get(language, {}).get((book, chapter))
    if rule is None:
        return number
    threshold, shift = rule
    if number < threshold:
        # Below the threshold the divergence crosses a chapter boundary, which no offset can
        # express. Refuse rather than fetch a plausible-looking wrong verse.
        err(f"{where}: {book} {chapter}:{number} falls in a chapter whose Vulgate and Hebrew "
            f"numbering diverge across the chapter break — resolve it by hand")
        return None
    return number + shift


def source_reference(language: str, book: str, spans: list, where: str) -> str | None:
    """Render a source-native reference from Vulgate-numbered input spans.

    Repeated segments in the same chapter retain the compact ``14:55, 60-64`` form. The mapping
    must remain linear across every range; a future discontinuity must be represented explicitly
    rather than producing a plausible but wrong citation.
    """
    rendered: list[str] = []
    previous_chapter: int | None = None
    for chapter, first, last in spans:
        mapped_first = source_verse(language, book, chapter, first, where)
        mapped_last = source_verse(language, book, chapter, last, where)
        if mapped_first is None or mapped_last is None:
            return None
        if mapped_last - mapped_first != last - first:
            err(f"{where}: {book} {chapter}:{first}-{last} crosses a non-linear source "
                "versification boundary — split or map it explicitly")
            return None
        prefix = f"{chapter}:" if chapter != previous_chapter else ""
        verses = (str(mapped_first) if mapped_first == mapped_last
                  else f"{mapped_first}–{mapped_last}")
        rendered.append(prefix + verses)
        previous_chapter = chapter
    return ", ".join(rendered)


def passage(language: str, book: str, testament: str, spans: list, where: str) -> str | None:
    if LANGUAGES[language]["sources"][testament][1] == "martini":
        table = {}
        spec = LANGUAGES[language]
        for chapter in sorted({span[0] for span in spans}):
            CACHE.mkdir(exist_ok=True)
            stem = spec["file_names"][book]
            cached = CACHE / f"it-martini-{stem}-{chapter}.json"
            if not cached.exists():
                url = spec["sources"][testament][0].format(book=stem, chapter=chapter)
                subprocess.run(["curl", "-L", "--fail", "--silent", "--show-error", url,
                                "-o", str(cached)], check=True)
            source = json.loads(cached.read_text())
            if source["c"] != chapter:
                raise ValueError(f"{where}: Martini returned the wrong chapter")
            table.update({(chapter, verse["n"]): verse["t"].strip() for verse in source["v"]})
    else:
        table = verses(language, testament, book)
    out = []
    for chapter, first, last in spans:
        for cited in range(first, last + 1):
            number = source_verse(language, book, chapter, cited, where)
            if number is None:
                return None
            text = table.get((chapter, number))
            if text is None:
                gap = SOURCE_GAPS.get(language, {}).get((book, chapter))
                if gap:
                    print(f"  {where}: {book} {chapter} unavailable — {gap}", file=sys.stderr)
                else:
                    err(f"{where}: {book} {chapter}:{number} is not in the source")
                return None
            out.append(text)
    return " ".join(out)


def hebrew_numeral(n: int) -> str:
    """Chapter numbers as Hebrew numerals with their traditional punctuation — geresh after a
    single letter (כ׳), gershayim before the last of several (נ״ג) — matching the convention
    the hand-authored Hebrew citations already follow (— יְשַׁעְיָהוּ נ״ג 8). 15 and 16 take
    the ט forms, as always, so no numeral spells a fragment of the Name."""
    ones = ["", "א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"]
    tens = ["", "י", "כ", "ל", "מ", "נ", "ס", "ע", "פ", "צ"]
    hundreds = ["", "ק", "ר", "ש", "ת"]
    letters = ""
    h, rest = divmod(n, 100)
    letters += "ת" * (h // 4) + hundreds[h % 4]
    if rest in (15, 16):
        letters += "טו" if rest == 15 else "טז"
    else:
        letters += tens[rest // 10] + ones[rest % 10]
    return letters + "׳" if len(letters) == 1 else letters[:-1] + "״" + letters[-1]


def hebrew_reference(reference: str) -> str:
    """Book-external reference style: gematria chapters, Arabic verses, and no colon."""
    rendered = re.sub(
        r"(?<!\d)(\d+):",
        lambda match: f"{hebrew_numeral(int(match.group(1)))} ",
        reference,
    )
    return re.sub(r"(?<=\d)-(?=\d)", "–", rendered)


def citation_line(language: str, book: str, testament: str, reference: str, second: bool) -> str:
    spec = LANGUAGES[language]
    index = 0 if second else min(1, len(spec["edition"]) - 1)
    names = spec["books"][book]
    name = names[index if index < len(names) else 0]
    editions = spec.get("edition_by_testament", {}).get(testament, spec["edition"])
    edition = editions[index if index < len(editions) else 0]
    # The Hebrew-lettered side cites the way Hebrew citations do everywhere else in the app:
    # book, chapter as a Hebrew numeral, verses in Arabic numerals ("אשעיא י״א 2-3"), while the
    # Syriac side keeps the source's own chapter:verse form.
    if index == spec.get("hebrewChapterIndex", -1):
        reference = hebrew_reference(reference)
    return f"\n\n— {name} {reference} ({edition})"


def build(language: str, bundle: Path) -> dict | None:
    latin_path = bundle / "content" / "la.json"
    if not latin_path.exists():
        return None
    latin = json.loads(latin_path.read_text(encoding="utf-8"))

    texts = dict(latin.get("prayers", {}))
    mysteries = {k: m for k, m in (latin.get("mysteries") or {}).items()
                 if isinstance(m, dict) and m.get("description")}

    prayers, transliterations, mystery_out = {}, {}, {}
    unsourced = []
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
        spec = LANGUAGES[language]
        if testament not in spec["sources"] or book not in spec["books"]:
            # No source for that testament in this language — the Septuagint question for Greek.
            unsourced.append(f"{bundle.name}:{key} ({book})")
            continue
        spans = parse_reference(reference)
        if not spans:
            err(f"{bundle.name}:{key}: cannot read reference {reference!r}")
            continue
        source_text = passage(language, book, testament, spans, f"{bundle.name}:{key}")
        if source_text is None:
            continue
        native_reference = source_reference(language, book, spans, f"{bundle.name}:{key}")
        if native_reference is None:
            continue

        if spec["second_script"] == "syriac":
            second_body = source_text + citation_line(language, book, testament, native_reference,
                                                      second=True)
            primary_body = to_hebrew(source_text, keep_plural_dots=False) + citation_line(
                language, book, testament, native_reference, second=False)
        else:
            second_body = None
            primary_body = source_text + citation_line(language, book, testament, native_reference,
                                                       second=True)
        if key.startswith("mystery:"):
            # Mystery content is deliberately partial. Scripture and its citation belong to the
            # edition/rite selected here; the mystery's name and fruit are not Scripture and
            # continue through the apps' ordinary field-wise language fallback chain. For
            # Aramaic, the exact Peshitta passage is also kept in Syriac letters for the flow's
            # script toggle.
            mystery_key = key[len("mystery:"):]
            mystery_out[mystery_key] = {"description": primary_body}
            if second_body is not None:
                mystery_out[mystery_key]["transliteratedDescription"] = second_body
        else:
            prayers[key] = primary_body
            if second_body is not None:
                transliterations[key] = second_body

    if unsourced:
        print(f"  {bundle.name} [{language}]: {len(unsourced)} passage(s) have no source in this "
              f"language: {', '.join(unsourced)}", file=sys.stderr)
    if not prayers and not mystery_out:
        return None
    return {"prayers": prayers, "transliterations": transliterations, "mysteries": mystery_out}


NOTES = {
    "fr": "Scripture: Bible Augustin Crampon (1923), public domain; transcribed by scrollmapper/bible_databases. Imported passages retain this edition's wording and numbering. Other prayers have separately credited published sources.",
    "it": "Scripture: Bibbia di Antonio Martini (1769–1781), public domain. Structured data by Giovanni Novelli, Parola Viva (https://parolaviva.art/opendata), CC BY 4.0. Imported passages retain this edition's wording and numbering. Other prayers have separately credited published sources.",
    "arc": ("Scripture entries imported from the Peshitta by Shared/tools/import-scripture.py — "
            "re-run it rather than editing them by hand. Their Hebrew square script is converted "
            "with Erez's script rules; the source text in Syriac letters is beside it for the "
            "flow's script toggle. Unpointed, as the source has it."),
    "es": ("Scripture imported from Félix Torres Amat's Spanish Bible (1836) by "
           "Shared/tools/import-scripture.py — re-run it rather than editing these by hand. "
           "Torres Amat translated the Vulgate, so its chapter-and-verse is the same one these "
           "devotions cite and no versification map is needed. Spelling and accentuation are the "
           "1836 printing's own. Old Testament readings are absent: only the New Testament "
           "volumes of it have been transcribed from the scans."),
    "el": ("Scripture imported from the Byzantine Majority Text (Robinson-Pierpont, public domain) "
           "by Shared/tools/import-scripture.py — re-run it rather than editing these by hand. "
           "Polytonic, as the source has it. Old Testament readings are absent pending a "
           "Septuagint whose digitisation the app can ship under."),
}


def render(language: str, built: dict, existing: dict) -> dict:
    """Merge into whatever content/<lang>.json already holds — a hand-authored prayer must never
    be clobbered by a scripture import."""
    out = json.loads(json.dumps(existing)) if existing else {}
    if language in ("fr", "it"):
        # Published fixed-prayer provenance may share the file with imported Scripture.
        out["$scriptureSource"] = NOTES[language]
    else:
        out["$comment"] = NOTES[language]
    out["$scriptureImport"] = {
        "prayerKeys": sorted(built["prayers"]),
        "mysteryKeys": sorted(built["mysteries"]),
    }
    prayers = out.setdefault("prayers", {})
    prayers.update(built["prayers"])
    if built["transliterations"]:
        out.setdefault("transliterations", {}).update(built["transliterations"])
    mysteries = out.setdefault("mysteries", {})
    for key, fields in built["mysteries"].items():
        current = mysteries.get(key)
        if not isinstance(current, dict):
            current = {}
        # Generated Scripture fields replace an earlier generated value, while any authored
        # title/fruit (or future field) remains untouched.
        current.update(fields)
        mysteries[key] = current
    return out


def main() -> int:
    arguments = [a for a in sys.argv[1:] if not a.startswith("--")]
    check = "--check" in sys.argv[1:]

    # Contextual Hebrew finals must still reverse to the same Syriac letter sequence. The original
    # Syriac itself never depends on this reverse map; it is stored byte-for-byte beside the
    # projection. Checked on the whole alphabet and on real unpointed words on every import.
    alphabet = "".join(SYRIAC_TO_HEBREW)
    if to_syriac_letters(to_hebrew(alphabet)) != alphabet:
        err("the Syriac/Hebrew alphabet mapping does not round-trip")
    if len(set(SYRIAC_TO_HEBREW.values())) != len(SYRIAC_TO_HEBREW):
        err("two Syriac letters map onto one Hebrew letter — the mapping is lossy")
    for word in ("ܐܒܘܢ ܕܒܫܡܝܐ ܢܬܩܕܫ ܫܡܟ", "ܩܕܝܫܬ ܐܠܗܐ"):
        if to_syriac_letters(to_hebrew(word)) != word:
            err(f"round trip failed for {word!r}")

    # Isaiah 9 is where the Vulgate's numbering and the sources' part company, and a silent
    # off-by-one there is indistinguishable from a correct import by eye. Pin both sources to the
    # verse the Vulgate calls 9:2 — "the people that walked in darkness".
    if not arguments:
        for language, marker in (("arc", "ܥܡܐ"), ("el", "λαὸς")):
            try:
                number = source_verse(language, "Isaiah", 9, 2, "versification self-check")
                text = verses(language, "ot", "Isaiah").get((9, number), "")
            except Exception as exc:  # noqa: BLE001 - a source being unreachable is not a failure
                print(f"  skipped {language} versification check: {exc}", file=sys.stderr)
                continue
            if marker not in text:
                err(f"versification self-check failed for {language}: Isaiah 9:2 should be "
                    f"'the people that walked in darkness', got {text[:60]!r}")

    bundles = ([CONTENT / name for name in arguments] if arguments
               else sorted(p for p in CONTENT.iterdir() if (p / "manifest.json").exists()))

    changed = 0
    for language in LANGUAGES:
        for bundle in bundles:
            target = bundle / "content" / f"{language}.json"
            manifest_path = bundle / "manifest.json"
            manifest_languages = (json.loads(manifest_path.read_text(encoding="utf-8"))
                                  .get("languages", [])) if manifest_path.exists() else []
            # Existing overlay files are intentional import targets even when the language is
            # not advertised as a complete bundle language. Do not invent a new partial overlay
            # merely because the Latin source happens to contain a citation; a new overlay is an
            # explicit content decision (or a declared manifest language).
            if not target.exists() and language not in manifest_languages:
                continue
            built = build(language, bundle)
            if built is None:
                continue
            existing = json.loads(target.read_text(encoding="utf-8")) if target.exists() else {}
            rendered = render(language, built, existing)
            serialized = json.dumps(rendered, ensure_ascii=False, indent=2) + "\n"
            if target.exists() and target.read_text(encoding="utf-8") == serialized:
                continue
            changed += 1
            if check:
                err(f"{bundle.name}: content/{language}.json is out of date "
                    f"(run import-scripture.py)")
                continue
            target.write_text(serialized, encoding="utf-8")
            passage_count = len(built["prayers"]) + len(built["mysteries"])
            print(f"{bundle.name} [{language}]: {passage_count} passages")

    for message in errors:
        print(f"import-scripture: {message}", file=sys.stderr)
    if errors:
        return 1
    print(f"{'up to date' if not changed else f'wrote {changed} bundle(s)'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

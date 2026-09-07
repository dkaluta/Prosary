#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Offline regression tests for Scripture import, script conversion, and Aramaic packs.

This deliberately does not invoke import-scripture.py's network-backed source fetch. Golden
examples pin the conversion rules independently, every committed Peshitta passage is compared
across both scripts, and every generated bundle is checked against all three platform copies.

    usage: test-import-scripture.py
"""

from __future__ import annotations

import json
import hashlib
import importlib.util
import re
import sys
import zipfile
from pathlib import Path

from aramaic_script_converter import (
    EREZ_CHARS_TO_REMOVE,
    HEBREW_MARKS_ALWAYS_REMOVE,
    SYRIAC_TO_HEBREW,
    to_hebrew,
    to_syriac_letters,
)


TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent.parent
CONTENT = TOOLS.parent / "content"
DIST = TOOLS.parent / "dist"

IMPORTER_SPEC = importlib.util.spec_from_file_location(
    "prosary_import_scripture", TOOLS / "import-scripture.py")
if IMPORTER_SPEC is None or IMPORTER_SPEC.loader is None:
    raise RuntimeError("could not load import-scripture.py")
IMPORTER = importlib.util.module_from_spec(IMPORTER_SPEC)
IMPORTER_SPEC.loader.exec_module(IMPORTER)

failures: list[str] = []


def expect(label: str, actual, wanted) -> None:
    if actual != wanted:
        failures.append(f"{label}: expected {wanted!r}, got {actual!r}")


def expect_value_error(label: str, source: str, *, keep_plural_dots: bool = False) -> None:
    try:
        to_hebrew(source, keep_plural_dots=keep_plural_dots)
    except ValueError:
        return
    failures.append(f"{label}: expected invalid source input to raise ValueError")


def scripture_body(text: str) -> str:
    marker = "\n\n— "
    return text.rsplit(marker, 1)[0] if marker in text else text


def test_converter() -> None:
    cases = {
        "alphabet": ("ܐܒܓܕܗܘܙܚܛܝܟܠܡܢܣܥܦܨܩܪܫܬ", "אבגדהוזחטיכלמנסעפצקרשת"),
        "final letters": ("ܟ ܡ ܢ ܦ ܨ", "ך ם ן ף ץ"),
        "Kyrie final nun": ("ܩܘܪܝܐܠܝܣܘܢ", "קוריאליסון"),
        "Isaiah marked dotless rish": ("ܠܖ̈ܰܫܺܝܥܶܐ", "לרַשִיעֶא"),
        "rish seyame after vowel": ("ܖܰ̈", "רַ"),
        "rish seyame at word end": ("ܡܠܖ̈", "מלר"),
        "ordinary dalath and rish stay distinct": ("ܕܰ ܪܰ", "דַ רַ"),
        "medial letters": ("ܟܐ ܡܐ ܢܐ ܦܐ ܨܐ", "כא מא נא פא צא"),
        "vowels": ("ܒܰ ܒܳ ܒܶ ܒܺ ܒܽ", "בַ בָ בֶ בִ בֻ"),
        "qushshaya and rukkakha": ("ܒ݁ ܒ݂", "בּ ב"),
        "initial conjunction": ("ܘܶܡܠܐ", "וְמלא"),
        "waw vowels": ("ܘܽ ܘܳ", "וּ וֹ"),
        "pre-waw u": ("ܒܽܘ", "בוּ"),
        "pre-waw u after qushshaya": ("ܒ݁ܽܘ", "בּוּ"),
        "guarded pre-waw u": ("ܒܽܘܰ", "בֻוַ"),
        "pointed final": ("ܡܠܟܳ", "מלךָ"),
        "pointed medial": ("ܟܳܬ", "כָת"),
        "seyame removed": ("ܡ̈ܠܟܐ", "מלכא"),
        "ETCBC dot removed": ("ܡ̇ܠܟܐ", "מלכא"),
        "word boundaries": ("ܡܠܟ، ܢܘܢ\nܦܨ", "מלך، נון\nפץ"),
        "Syriac punctuation boundary": ("ܡܠܟ܀ܡ", "מלך܀ם"),
        "punctuation and digits": ("ܡܠܟ 12:3.", "מלך 12:3."),
    }
    for label, (source, wanted) in cases.items():
        expect(label, to_hebrew(source), wanted)

    expect("seyame retained on request", to_hebrew("ܡ̈ܠܟܐ", keep_plural_dots=True), "מ̈לכא")
    marked_source = "ܠܖ̈ܰܫܺܝܥܶܐ"
    expect("marked rish retains requested seyame", to_hebrew(marked_source, keep_plural_dots=True), "לרַ̈שִיעֶא")
    expect("original marked Syriac stays unchanged", marked_source, "ܠܖ̈ܰܫܺܝܥܶܐ")
    expect("classical alphabet remains 22 letters", len(SYRIAC_TO_HEBREW), 22)
    expect("Hebrew resh still reverses to regular Syriac rish", to_syriac_letters("ר"), "ܪ")
    for ambiguous in ("ܖ", "ܖܰ", "ܖ̇", "ܖ ̈", "ܖܐ̈", "ܖ\n̈"):
        for keep_dots in (False, True):
            expect_value_error(f"ambiguous dotless letter {ambiguous!r}; keep dots={keep_dots}",
                               ambiguous, keep_plural_dots=keep_dots)

    for removed in EREZ_CHARS_TO_REMOVE | HEBREW_MARKS_ALWAYS_REMOVE:
        expect(f"removed U+{ord(removed):04X}", to_hebrew(f"ܐ{removed}ܒ"), "אב")

    expect_value_error("mixed Hebrew letter", "ܒבܐ")
    expect_value_error("mixed Hebrew vowel", "ܒְܐ")
    expect_value_error("mixed Hebrew dagesh", "ܒבּܐ")

    alphabet = "".join(SYRIAC_TO_HEBREW)
    expect("alphabet round trip", to_syriac_letters(to_hebrew(alphabet)), alphabet)
    for source in ("ܐܒܘܢ ܕܒܫܡܝܐ ܢܬܩܕܫ ܫܡܟ", "ܩܕܝܫܬ ܐܠܗܐ", "ܡܠܟ ܢܦܨ"):
        expect(f"word round trip {source!r}", to_syriac_letters(to_hebrew(source)), source)


def test_citations_and_versification() -> None:
    expect("Hebrew chapter 3", IMPORTER.hebrew_numeral(3), "ג׳")
    expect("Hebrew chapter 15", IMPORTER.hebrew_numeral(15), "ט״ו")
    expect("Hebrew chapter 16", IMPORTER.hebrew_numeral(16), "ט״ז")
    expect("Hebrew reference has no colon",
           IMPORTER.hebrew_reference("3:16-17"), "ג׳ 16–17")

    spans = IMPORTER.parse_reference("9:2")
    expect("supplied pointed Peshitta citation follows its own numbering",
           IMPORTER.source_reference("arc", "Isaiah", spans, "offline test"), "9:2")
    expect("Vulgate-derived Spanish numbering is unchanged",
           IMPORTER.source_reference("es", "Isaiah", spans, "offline test"), "9:2")

    hebrew_line = IMPORTER.citation_line("arc", "Isaiah", "ot", "9:2", second=False)
    expect("Hebrew Peshitta citation", hebrew_line, "\n\n— אשעיא ט׳ 2 (פשיטתא)")
    if ":" in hebrew_line:
        failures.append("Hebrew Peshitta citation contains a colon")


def test_spanish_nested_footnotes() -> None:
    markup = '''<h2>CAPÍTULO PRIMERO.</h2>
    <p><span id="1:48">48</span> Porque ha puesto los ojos en la bajeza de su esclava
    <sup class="reference"><a href="#cite_note-5"><span>&#91;</span>5<span>&#93;</span></a></sup>:
    por tanto ya desde ahora me llamarán bienaventurada todas las generaciones.</p>
    <p><span id="1:49">49</span> Porque ha hecho en mí cosas grandes aquel que es
    <i>todopoderoso</i>, cuyo nombre es santo;</p>
    <ol class="references"><li>5 Nota editorial que no forma parte del versículo.</li></ol>'''
    verses = IMPORTER._parse_wikisource_verses(markup)
    expect("Spanish footnote does not truncate Luke 1:48", verses.get((1, 48)),
           "Porque ha puesto los ojos en la bajeza de su esclava: por tanto ya desde ahora me llamarán bienaventurada todas las generaciones.")
    expect("Spanish italic text survives without footnote appendix", verses.get((1, 49)),
           "Porque ha hecho en mí cosas grandes aquel que es todopoderoso, cuyo nombre es santo;")
    expect("footnote number is not a verse", set(verses), {(1, 48), (1, 49)})


def test_spanish_chapter_boundaries() -> None:
    # Fragments from the cached Torres Amat/Wikisource markup. John 21 was once
    # incorrectly declared unavailable because its heading has an extra I.
    markup = '''<h2>CAPÍTULO XX.</h2>
    <p><span title="20:29" id="20:29">29</span> bienaventurados aquellos que sin haber<i>me</i> visto, han creido.</p>
    <p><span title="20:31" id="20:31">31</span> para que creyendo, tengais vida <i>eterna</i> en <i>virtud de su nombre</i>.</p>
    <div><span>CAPÍITULO XXI.</span></div>
    <div><i>Aparécese Jesus á sus discípulos, estando ellos pescando.</i></div>
    <p><span title="21:1" id="21:1">1</span> Despues de esto Jesus se apareció otra vez á los discípulos.</p>
    <p><span title="21:15" id="21:15">15</span> Acabada la comida, dice Jesus á Simon Pedro.</p>
    <p><span title="21:25" id="21:25">25</span> Muchas otras cosas hay que hizo Jesus.</p>
    <div>FIN DEL EVANGELIO.</div>
    <nav>1 Índice 2 Siguiente libro</nav>
    <div class="reflist"><ol><li>159 Nota editorial.</li></ol></div>'''
    verses = IMPORTER._parse_wikisource_verses(markup)
    expect("inline italics preserve Spanish word", verses.get((20, 29)),
           "bienaventurados aquellos que sin haberme visto, han creido.")
    expect("misspelled heading does not pollute previous chapter", verses.get((20, 31)),
           "para que creyendo, tengais vida eterna en virtud de su nombre.")
    expect("Spanish John 21 fishing appears", verses.get((21, 1)),
           "Despues de esto Jesus se apareció otra vez á los discípulos.")
    expect("Spanish John 21 Peter appears", verses.get((21, 15)),
           "Acabada la comida, dice Jesus á Simon Pedro.")
    expect("book footer is not Scripture", verses.get((21, 25)),
           "Muchas otras cosas hay que hizo Jesus.")
    expect("navigation and notes do not become verses", set(verses),
           {(20, 29), (20, 31), (21, 1), (21, 15), (21, 25)})
    expect("Spanish John 21 is not a source gap",
           IMPORTER.SOURCE_GAPS.get("es", {}).get(("John", 21)), None)

    numbered = '''<h2>CAPÍTULO VIII.</h2>
    <div><i>Referencias: Matt. 3. Marc. 1, 8.</i></div>
    <p><span title="8:28" id="8:28">28</span>No me atormentes.</p>
    <p><span title="8:29" id="8:29">29</span>. Y es que Jesus mandaba al espíritu inmundo que saliese de aquel hombre.</p>
    <p><span title="8:30" id="8:30">30</span> Jesus le preguntó.</p>
    <div class="noprint">999 Navigation</div>'''
    verses = IMPORTER._parse_wikisource_verses(numbered)
    expect("period after verse number is accepted", verses.get((8, 29)),
           "Y es que Jesus mandaba al espíritu inmundo que saliese de aquel hombre.")
    expect("period-numbered verse does not join previous one", verses.get((8, 28)),
           "No me atormentes.")
    expect("navigation does not attach to final verse", verses.get((8, 30)), "Jesus le preguntó.")
    expect("dotted summary references are not verses", set(verses), {(8, 28), (8, 29), (8, 30)})


def test_sourced_martini_whitespace() -> None:
    source = "pietra eletta, angolare, preziosa, saldissimo fonda mento: chi crede, non abbia fretta."
    corrected = "pietra eletta, angolare, preziosa, saldissimo fondamento: chi crede, non abbia fretta."
    expect("Martini Isaiah split word follows printed verse",
           IMPORTER.normalize_source_text("it", "Isaiah", 28, 16, source), corrected)
    expect("corrected upstream text stays unchanged",
           IMPORTER.normalize_source_text("it", "Isaiah", 28, 16, corrected), corrected)
    expect("no broad spelling or whitespace correction",
           IMPORTER.normalize_source_text("it", "Isaiah", 28, 17, source), source)
    expect("source correction is language-specific",
           IMPORTER.normalize_source_text("es", "Isaiah", 28, 16, source), source)
    if IMPORTER.MARTINI_ISAIAH_PRINT not in IMPORTER.NOTES["it"]:
        failures.append("Martini whitespace correction lacks its printed source credit")


def test_committed_peshitta() -> None:
    passage_count = 0
    for arc_path in sorted(CONTENT.glob("*/content/arc.json")):
        content = json.loads(arc_path.read_text(encoding="utf-8"))
        if "Peshitta" not in content.get("$comment", "") + content.get("$scriptureSource", ""):
            continue

        prayers = content.get("prayers", {})
        syriac = content.get("transliterations", {})
        mysteries = content.get("mysteries", {})
        imported = content.get("$scriptureImport", {})
        prayer_keys = set(imported.get("prayerKeys", []))
        mystery_keys = set(imported.get("mysteryKeys", []))
        passage_count += len(prayer_keys) + len(mystery_keys)

        for key in sorted(prayer_keys):
            if key not in prayers or key not in syriac:
                failures.append(
                    f"{arc_path.parent.parent.name}:{key}: imported prayer needs both scripts")
                continue
            hebrew_body = scripture_body(prayers[key])
            syriac_body = scripture_body(syriac[key])
            expect(
                f"{arc_path.parent.parent.name}:{key}: Erez conversion",
                to_hebrew(syriac_body, keep_plural_dots=False),
                hebrew_body,
            )
            if any("ܐ" <= ch <= "ܬ" for ch in hebrew_body):
                failures.append(f"{arc_path.parent.parent.name}:{key}: Syriac letter leaked into Hebrew")

        for key in sorted(mystery_keys):
            fields = mysteries.get(key, {})
            if "description" not in fields or "transliteratedDescription" not in fields:
                failures.append(
                    f"{arc_path.parent.parent.name}:{key}: Peshitta mystery needs both scripts")
                continue
            hebrew_body = scripture_body(fields["description"])
            syriac_body = scripture_body(fields["transliteratedDescription"])
            expect(
                f"{arc_path.parent.parent.name}:{key}: mystery Erez conversion",
                to_hebrew(syriac_body, keep_plural_dots=False),
                hebrew_body,
            )
            hebrew_citation = fields["description"].rsplit("\n\n— ", 1)[-1]
            if ":" in hebrew_citation:
                failures.append(
                    f"{arc_path.parent.parent.name}:{key}: Hebrew mystery citation contains a colon")
            if re.search(r"\d-\d", hebrew_citation):
                failures.append(
                    f"{arc_path.parent.parent.name}:{key}: Hebrew mystery citation uses a hyphen")

    expect("committed Peshitta passage count", passage_count, 56)


def test_pointed_peshitta() -> None:
    # Source excerpt retains the Corpus edition's header and license. Chapter headings and
    # Syriac chapter milestones are metadata, not prayer text.
    markup = (TOOLS / "fixtures/peshitta-luke-1.xml").read_text(encoding="utf-8")
    verses = IMPORTER.parse_pointed_peshitta(markup, "Luke", {1})
    expect("pointed Luke verse selection", set(verses), {(1, 26), (1, 27), (1, 28)})
    if not verses[(1, 26)].startswith("ܒ݁ܝܰܪܚܳܐ ܕ݁ܶܝܢ"):
        failures.append("Luke 1:26 lost its source vowel signs")
    if not to_hebrew(verses[(1, 26)]).startswith("בּיַרחָא דֶּין"):
        failures.append("Luke 1:26 did not transfer source vowels through Erez's rules")
    for label, invalid, book in (
        ("wrong book", markup, "Matthew"),
        ("missing vowels", re.sub(r"[\u0730-\u074a]", "", markup), "Luke"),
        ("duplicate verse", markup.replace('type="verse" n="27"', 'type="verse" n="26"'), "Luke"),
        ("editorial note", markup.replace('type="verse" n="27">', 'type="verse" n="27"><note>editor</note>'), "Luke"),
    ):
        try:
            IMPORTER.parse_pointed_peshitta(invalid, book, {1})
            failures.append(f"pointed Peshitta accepted {label}")
        except ValueError:
            pass

    pointed_count = 0
    for path in CONTENT.glob("*/content/arc.json"):
        content = json.loads(path.read_text(encoding="utf-8"))
        imported = content.get("$scriptureImport", {})
        pairs = [(content["prayers"][key], content["transliterations"][key])
                 for key in imported.get("prayerKeys", []) if not key.startswith("o")]
        pairs += [(content["mysteries"][key]["description"],
                   content["mysteries"][key]["transliteratedDescription"])
                  for key in imported.get("mysteryKeys", [])]
        for hebrew, syriac in pairs:
            pointed_count += 1
            if not re.search(r"[\u05b0-\u05bb]", scripture_body(hebrew)):
                failures.append(f"{path}: New Testament Hebrew projection lost its vowels")
            if not re.search(r"[\u0730-\u073f]", scripture_body(syriac)):
                failures.append(f"{path}: New Testament Syriac source lost its vowels")
    expect("vocalized New Testament passage count", pointed_count, 49)


def test_supplied_pointed_isaiah() -> None:
    raw = (TOOLS / "fixtures/peshitta-isaiah-supplied.xml").read_bytes()
    expect("reviewed nine-verse Isaiah fixture hash", hashlib.sha256(raw).hexdigest(),
           "7e5db9260727fd72b882f785e1fc64b654e22c61b44cb351dc43f98dba352cc6")
    markup = raw.decode("utf-8")
    table = IMPORTER.parse_supplied_peshitta_isaiah(markup)
    expect("reviewed Isaiah selection", set(table),
           {(7, 14), (9, 2), (11, 2), (11, 3), (11, 4), (11, 5), (11, 10), (22, 22), (28, 16)})
    # The full XML hash must be checked before parsing a downloaded or cached source; an excerpt
    # is useful offline but must never pass as the reviewed complete download.
    try:
        IMPORTER.verify_supplied_peshitta_hash(raw)
        failures.append("Isaiah fixture was accepted as the hash-pinned full download")
    except ValueError:
        pass
    for label, invalid, book in (
        ("wrong book", markup, "Luke"),
        ("wrong source book", markup.replace('bname="Isaiah"', 'bname="Jeremiah"'), "Isaiah"),
        ("missing vowels", re.sub(r"[\u0730-\u074a]", "", markup), "Isaiah"),
        ("duplicate verse", markup.replace('<VERS vnumber="3">', '<VERS vnumber="2">'), "Isaiah"),
        ("missing reviewed verse", markup.replace('<VERS vnumber="14">', '<VERS vnumber="15">'), "Isaiah"),
        ("inline note", markup.replace('<VERS vnumber="14">', '<VERS vnumber="14"><NOTE>note</NOTE>'), "Isaiah"),
    ):
        try:
            IMPORTER.parse_supplied_peshitta_isaiah(invalid, book)
            failures.append(f"supplied pointed Isaiah accepted {label}")
        except ValueError:
            pass

    # Pin the supplied edition's accepted wording; do not graft its points onto ETCBC consonants.
    consonants = lambda value: re.sub(r"[^\u0710-\u072f]", "", value)
    if "ܕܝܕܥܬܐ" not in consonants(table[(11, 2)]) or "ܕܐܝܕܥܬܐ" in consonants(table[(11, 2)]):
        failures.append("Isaiah 11:2 no longer follows the supplied wording")
    if "ܗܟܢܐ" in consonants(table[(28, 16)]):
        failures.append("Isaiah 28:16 regained a word absent from the supplied edition")
    if not table[(9, 2)].startswith("ܥܰܡܳܐ"):
        failures.append("Isaiah 9:2 no longer selects the darkness/light verse")
    if "לרַשִיעֶא" not in to_hebrew(table[(11, 4)]):
        failures.append("Isaiah 11:4 lost the marked rish conversion")

    readings = {
        "oEmmanuelLectio": ("7:14", [(7, 14)]),
        "oOriensLectio": ("9:2", [(9, 2)]),
        "oSapientiaLectio": ("11:2–3", [(11, 2), (11, 3)]),
        "oAdonaiLectio": ("11:4–5", [(11, 4), (11, 5)]),
        "oRadixIesseLectio": ("11:10", [(11, 10)]),
        "oClavisDavidLectio": ("22:22", [(22, 22)]),
        "oRexGentiumLectio": ("28:16", [(28, 16)]),
    }
    content = json.loads((CONTENT / "oAntiphons/content/arc.json").read_text(encoding="utf-8"))
    for key, (reference, verses) in readings.items():
        source = " ".join(table[verse] for verse in verses)
        expect(f"{key}: exact supplied Syriac passage and citation", content["transliterations"][key],
               source + IMPORTER.citation_line("arc", "Isaiah", "ot", reference, second=True))
        expect(f"{key}: supplied points through Erez conversion", content["prayers"][key],
               to_hebrew(source, keep_plural_dots=False)
               + IMPORTER.citation_line("arc", "Isaiah", "ot", reference, second=False))
        if not re.search(r"[\u05b0-\u05bb]", scripture_body(content["prayers"][key])):
            failures.append(f"{key}: Isaiah Hebrew projection is not vocalized")


def all_strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for nested in value.values():
            yield from all_strings(nested)
    elif isinstance(value, list):
        for nested in value:
            yield from all_strings(nested)


def test_aramaic_prayer_finals() -> None:
    """Final forms change the Hebrew spelling, never the supplied Syriac prayer."""
    content = json.loads((CONTENT / "trisagion/content/arc.json").read_text(encoding="utf-8"))
    source_line = "ܩܘܪܝܐܠܝܣܘܢ"
    hebrew_line = "קוריאליסון"
    for key, repetitions in (("trisagionKyrieTitle", 1), ("trisagionKyrie", 3)):
        source = "\n".join([source_line] * repetitions)
        hebrew = "\n".join([hebrew_line] * repetitions)
        expect(f"{key}: original Syriac preserved", content["transliterations"][key], source)
        expect(f"{key}: Hebrew final nun", content["prayers"][key], hebrew)
        expect(f"{key}: source conversion", to_hebrew(content["transliterations"][key]), hebrew)

    words = re.compile(r"[א-ת][א-ת\u0591-\u05bd\u05bf-\u05c5\u05c7]*")
    marks = re.compile(r"[\u0591-\u05bd\u05bf-\u05c5\u05c7]")
    for path in sorted(CONTENT.glob("*/content/arc.json")):
        content = json.loads(path.read_text(encoding="utf-8"))
        for text in all_strings([content.get("prayers", {}), content.get("mysteries", {})]):
            # Chapter numerals such as כ׳ belong to the citation, not to an Aramaic word.
            for word in words.findall(scripture_body(text)):
                if marks.sub("", word)[-1] in "כמנפצ":
                    failures.append(f"{path.relative_to(ROOT)}: non-final word ending {word!r}")


def test_aramaic_holy_god_gestures() -> None:
    """The 2026-09-07 user-confirmed opening is paired in both scripts, without other edits."""
    content = json.loads((CONTENT / "trisagion/content/arc.json").read_text(encoding="utf-8"))
    originals = {
        "prayers": "קַדּישַת אַלָהָא\nקַדִישַת חַילתָּנָא\nקַדִישַת לָא מִיותָּא אֶתַרחַמעלִין",
        "transliterations": "ܩܰܕ݁ܝܫܰܬ݂ ܐܰܠܳܗܳܐ\nܩܰܕܺܝܫܰܬ݂ ܚܰܝܠܬ݁ܳܢܳܐ\nܩܰܕܺܝܫܰܬ݂ ܠܳܐ ܡܺܝܘܬ݁ܳܐ ܐܶܬܰܪܚܰܡܥܠܺܝܢ",
    }
    for section, original in originals.items():
        body = content[section]["trisagionAcclamation"]
        expect(f"Holy God {section}: gestures after first Qadishat", body,
               original.replace(" ", " ✠▼▲ ", 1))
        expect(f"Holy God {section}: title remains a title",
               content[section]["trisagionAcclamationTitle"], original.splitlines()[0])
        expect(f"Holy God {section}: short form has no invented gestures",
               content[section]["trisagionShortAcclamation"], original.splitlines()[-1])

    source = content["transliterations"]["trisagionAcclamation"].splitlines()[0]
    for keep_plural_dots in (False, True):
        expect(f"Holy God converter preserves gestures (seyame={keep_plural_dots})",
               to_hebrew(source, keep_plural_dots=keep_plural_dots), "קַדּישַת ✠▼▲ אַלָהָא")


def test_all_citation_style() -> None:
    """Every verse range uses an en dash; Hebrew-script citations also omit the colon."""
    paths = sorted(CONTENT.glob("*/content/*.json"))
    citation_count = 0
    for path in paths:
        content = json.loads(path.read_text(encoding="utf-8"))
        for text in all_strings(content):
            for citation in re.findall(r"(?:^|\n)— ([^\n]+)", text):
                citation_count += 1
                if re.search(r"\d-\d", citation):
                    failures.append(f"{path.relative_to(ROOT)}: citation uses a hyphen: {citation}")
                if (re.search(r"[\u0590-\u05ff]", citation)
                        and re.search(r"\d+:\d+", citation)):
                    failures.append(f"{path.relative_to(ROOT)}: Hebrew citation has a colon: {citation}")
    if citation_count == 0:
        failures.append("no citations were checked")


def test_pack_parity() -> None:
    platform_roots = [
        ROOT / "iOS" / "Prosary" / "PrayerPacks",
        ROOT / "Android" / "app" / "src" / "main" / "assets",
        ROOT / "Windows" / "Prosary" / "PrayerPacks",
    ]

    for arc_path in sorted(CONTENT.glob("*/content/arc.json")):
        bundle_id = arc_path.parent.parent.name
        dist_pack = DIST / f"{bundle_id}.prosaryprayer"
        if not dist_pack.exists():
            failures.append(f"{bundle_id}: Shared/dist pack is missing")
            continue

        with zipfile.ZipFile(dist_pack) as archive:
            expect(f"{bundle_id}: canonical arc.json in pack", archive.read("content/arc.json"), arc_path.read_bytes())

        dist_bytes = dist_pack.read_bytes()
        for platform_root in platform_roots:
            platform_pack = platform_root / dist_pack.name
            if not platform_pack.exists():
                failures.append(f"{bundle_id}: platform pack missing at {platform_pack.relative_to(ROOT)}")
                continue
            expect(
                f"{bundle_id}: {platform_pack.relative_to(ROOT)} matches Shared/dist",
                platform_pack.read_bytes(),
                dist_bytes,
            )


def main() -> int:
    test_converter()
    test_citations_and_versification()
    test_spanish_nested_footnotes()
    test_spanish_chapter_boundaries()
    test_sourced_martini_whitespace()
    test_committed_peshitta()
    test_pointed_peshitta()
    test_supplied_pointed_isaiah()
    test_aramaic_prayer_finals()
    test_aramaic_holy_god_gestures()
    test_all_citation_style()
    test_pack_parity()

    for failure in failures:
        print(f"FAIL {failure}", file=sys.stderr)
    if failures:
        print(f"\n{len(failures)} failing case(s)", file=sys.stderr)
        return 1
    print("import-scripture: all converter and bundle cases pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())

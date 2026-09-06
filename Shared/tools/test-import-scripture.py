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


def expect_value_error(label: str, source: str) -> None:
    try:
        to_hebrew(source)
    except ValueError:
        return
    failures.append(f"{label}: expected mixed-script input to raise ValueError")


def scripture_body(text: str) -> str:
    marker = "\n\n— "
    return text.rsplit(marker, 1)[0] if marker in text else text


def test_converter() -> None:
    cases = {
        "alphabet": ("ܐܒܓܕܗܘܙܚܛܝܟܠܡܢܣܥܦܨܩܪܫܬ", "אבגדהוזחטיכלמנסעפצקרשת"),
        "final letters": ("ܟ ܡ ܢ ܦ ܨ", "ך ם ן ף ץ"),
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
    expect("Peshitta citation follows Peshitta numbering",
           IMPORTER.source_reference("arc", "Isaiah", spans, "offline test"), "9:1")
    expect("Vulgate-derived Spanish numbering is unchanged",
           IMPORTER.source_reference("es", "Isaiah", spans, "offline test"), "9:2")

    hebrew_line = IMPORTER.citation_line("arc", "Isaiah", "ot", "9:1", second=False)
    expect("Hebrew Peshitta citation", hebrew_line, "\n\n— אשעיא ט׳ 1 (פשיטתא)")
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


def all_strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for nested in value.values():
            yield from all_strings(nested)
    elif isinstance(value, list):
        for nested in value:
            yield from all_strings(nested)


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

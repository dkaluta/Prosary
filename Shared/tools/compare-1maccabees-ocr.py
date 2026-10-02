# /// script
# requires-python = ">=3.12"
# dependencies = ["beautifulsoup4", "pymupdf"]
# ///
"""Build a source-comparison baseline for Kahana 1 Maccabees 1 (PDF B97–105).

This produces research evidence, never an importable or certified transcription.
OCR and Wikisource are compared after removing pointing/punctuation only; defective
spellings, prefixes, suffixes, and final letters remain meaningful differences.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import re
import subprocess
import unicodedata

from bs4 import BeautifulSoup
import pymupdf
from hebrew_ocr_baseline import align as minimal_alignment, compare as compare_texts

ROOT = Path(__file__).resolve().parents[1]
PDF_SHA256 = "656891d377d2e3d4a9216723d94205488423907bf01df424b9f0b9de1560051e"
ONLINE_URL = "https://he.wikisource.org/wiki/ספר_המקבים_א_-_כל_הספר"
# Visually located scripture bounds. Keep the marginal labels: some scripture
# lines overhang the usual body edge (notably B99), so a fixed narrow crop loses
# words. OCR boxes in the visually located margin are separated explicitly from
# the Scripture comparison; raw recognition is preserved. A page can split a verse.
REGIONS = {
    97: (.08, .150, .935, .263),
    98: (.08, .120, .935, .275),
    99: (.08, .085, .935, .155),
    100: (.08, .120, .935, .250),
    101: (.08, .120, .935, .325),
    102: (.08, .120, .935, .372),
    103: (.08, .120, .935, .550),
    104: (.08, .130, .935, .425),
    105: (.08, .105, .935, .340),
}
# Fraction of full PDF width. B99 has an unusually long second Scripture line.
# A box crossing the boundary is unresolved mixed layout, never automatically
# split into guessed letters or silently treated as Scripture.
MARGIN_BOUNDARY = {page: .82 if page != 99 else .89 for page in REGIONS}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalized(word: str) -> str:
    return "".join(char for char in unicodedata.normalize("NFKD", word)
                   if unicodedata.category(char) != "Mn")


@dataclass(frozen=True)
class Token:
    raw: str
    verse: int | None = None
    end_verse: int | None = None
    page: int | None = None

    @property
    def key(self) -> str:
        return normalized(self.raw)


def tokens(text: str, **location) -> list[Token]:
    # Keep raw marks attached to their letters, and keep Latin/other OCR noise.
    result, current = [], []
    for char in unicodedata.normalize("NFC", text):
        if unicodedata.category(char)[0] in "LNM":
            current.append(char)
        elif current:
            raw = "".join(current)
            if normalized(raw):
                result.append(Token(raw, **location))
            current = []
    if current and normalized("".join(current)):
        result.append(Token("".join(current), **location))
    return result


def online_chapters(html: bytes) -> list[list[dict]]:
    soup = BeautifulSoup(html, "html.parser")
    chapters = soup.select('ol[style="list-style-type: hebrew;"]')
    if len(chapters) != 16:
        raise ValueError("The expected sixteen Kahana chapter lists were not found.")
    result = []
    for chapter in chapters:
        rows = []
        for number, item in enumerate(chapter.find_all("li", recursive=False), 1):
            for reference in item.select("sup.reference"):
                reference.decompose()
            for line_break in item.find_all("br"):
                line_break.replace_with("\n")
            # Wikisource poetry uses empty, explicitly sized inline blocks as
            # column separators. They are whitespace, unlike an inline span
            # wrapping letters inside a word.
            for spacer in item.find_all("span", style=True):
                style = spacer["style"].replace(" ", "").lower()
                if not spacer.contents and "display:inline-block" in style and (
                        "inline-size:" in style or "width:" in style):
                    spacer.replace_with(" ")
            rows.append({"verse": number, "text": " ".join(item.get_text().split())})
        result.append(rows)
    if len(result[0]) != 64:
        raise ValueError("The chapter-one scaffold does not have its expected 64 items.")
    return result


def online_chapter(html: bytes) -> list[dict]:
    return online_chapters(html)[0]


def held_out_vocabulary(html: bytes) -> list[str]:
    # The test image is chapter one. Exclude that entire chapter, not just its
    # last page, so the dictionary never contains a supplied expected passage.
    return sorted({word.key for chapter in online_chapters(html)[1:]
                   for verse in chapter for word in tokens(verse["text"])})


def page_105_reference(draft: dict) -> str:
    chapter = next(row for row in draft["chapters"] if row["number"] == 1)
    selected = [verse for verse in chapter["verses"] if verse["verse"] >= 55]
    first = tokens(selected[0]["text"])
    if selected[0]["verse"] != 55 or [word.key for word in first].count("הבתים") != 1:
        raise ValueError("The visually located page-105 opening is no longer unambiguous.")
    start = next(index for index, word in enumerate(first) if word.key == "הבתים")
    return " ".join([word.raw for word in first[start:]] + [verse["text"] for verse in selected[1:]])


def scripture_ocr(metadata: dict, page: int, image_width: int) -> tuple[str, list[dict]]:
    if "words" not in metadata:
        raise ValueError("OCR word boxes are required to separate printed marginal labels.")
    left, _, right, _ = REGIONS[page]
    boundary = (MARGIN_BOUNDARY[page] - left) / (right - left) * image_width
    body, excluded = [], []
    for word in metadata["words"]:
        if word["bbox"]["x1"] > boundary:
            excluded.append({**word, "classification": "printed_margin" if word["bbox"]["x0"] >= boundary
                             else "mixed_margin_body_unresolved"})
        else:
            body.append(word["text"])
    return " ".join(body), excluded


def vocabulary_trial(html: bytes, draft: dict, runner: Path, images: dict[int, Path], output: Path) -> dict:
    output.mkdir(exist_ok=True)
    words = held_out_vocabulary(html)
    vocabulary = output / "chapters2-16.words"
    vocabulary.write_text("\n".join(words) + "\n")
    reference = page_105_reference(draft)
    (output / "visual-draft-reference.txt").write_text(reference + "\n")
    results, engines = {}, {}
    for mode in ("plain", "vocabulary"):
        target = output / f"{mode}.txt"
        command = ["node", str(runner), str(images[105]), str(target)]
        if mode == "vocabulary":
            command.append(str(vocabulary))
        process = subprocess.run(command, capture_output=True, text=True, check=True)
        metadata = json.loads(process.stdout.strip().splitlines()[-1])
        (output / f"{mode}.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
        (output / f"{mode}.log").write_text(process.stderr)
        comparison_text, excluded = scripture_ocr(metadata, 105, pymupdf.Pixmap(images[105]).width)
        engines[mode] = {key: value for key, value in metadata.items() if key not in {"text", "words"}}
        engines[mode]["excludedLayout"] = excluded
        results[mode] = compare_texts(reference, comparison_text, "scan-transcription", "unreviewed")
    return {"status": "research_trial_not_accuracy_measurement", "heldOutPage": 105,
            "vocabularyChapters": list(range(2, 17)), "vocabularyWords": len(words),
            "vocabularySHA256": digest(vocabulary.read_bytes()), "imageSHA256": digest(images[105].read_bytes()),
            "runnerSHA256": digest(runner.read_bytes()), "referenceStatus": "unreviewed",
            "results": results, "engine": engines}


def alignment(reference: list[Token], observed: list[Token]) -> tuple[list[tuple[int, int]], list[dict]]:
    matched, differences = [], []
    for segment in minimal_alignment([word.key for word in reference], [word.key for word in observed]):
        kind = segment["kind"]
        a0, a1 = segment["referenceStart"], segment["referenceEnd"]
        b0, b1 = segment["observedStart"], segment["observedEnd"]
        if kind == "equal":
            matched.extend(zip(range(a0, a1), range(b0, b1)))
            continue
        verses = sorted({word.verse for word in reference[a0:a1] if word.verse is not None})
        pages = sorted({word.page for word in observed[b0:b1] if word.page is not None})
        differences.append({
            "operation": kind, "referenceTokenRange": [a0, a1], "observedTokenRange": [b0, b1],
            "referenceVerses": verses, "observedPages": pages,
            "referenceWords": [word.raw for word in reference[a0:a1]],
            "observedWords": [word.raw for word in observed[b0:b1]],
            "referenceContext": [word.raw for word in reference[max(0, a0 - 3):min(len(reference), a1 + 3)]],
            "observedContext": [word.raw for word in observed[max(0, b0 - 3):min(len(observed), b1 + 3)]],
            "status": "unresolved",
        })
    return matched, differences


def render(pdf_path: Path, output: Path) -> dict[int, Path]:
    if digest(pdf_path.read_bytes()) != PDF_SHA256:
        raise ValueError("The PDF is not the pinned user-supplied volume B.")
    document = pymupdf.open(pdf_path)
    if len(document) != 530:
        raise ValueError("Unexpected PDF page count.")
    images = {}
    for number, bounds in REGIONS.items():
        page = document[number - 1]
        left, top, right, bottom = bounds
        area = pymupdf.Rect(page.rect.width * left, page.rect.height * top,
                           page.rect.width * right, page.rect.height * bottom)
        target = output / f"B-{number}.png"
        page.get_pixmap(matrix=pymupdf.Matrix(5, 5), clip=area, alpha=False).save(target)
        images[number] = target
    return images


def run_ocr(runner: Path, images: dict[int, Path], output: Path) -> list[dict]:
    result = []
    for page, image in images.items():
        text_path = output / f"B-{page}.txt"
        process = subprocess.run(["node", str(runner), str(image), str(text_path)],
                                 capture_output=True, text=True, check=True)
        metadata = json.loads(process.stdout.strip().splitlines()[-1])
        (output / f"B-{page}.ocr.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
        (output / f"B-{page}.ocr.log").write_text(process.stderr)
        comparison_text, excluded = scripture_ocr(metadata, page, pymupdf.Pixmap(image).width)
        (output / f"B-{page}.scripture.txt").write_text(comparison_text)
        result.append({"page": page, "engine": {key: value for key, value in metadata.items() if key not in {"text", "words"}},
                       "excludedLayout": excluded, "comparisonTextSHA256": digest(comparison_text.encode()),
                       "confidence": metadata.get("confidence"),
                       "imageSHA256": digest(image.read_bytes()), "textSHA256": digest(text_path.read_bytes())})
    return result


def compare(html: bytes, draft: dict, ocr_directory: Path, ocr_metadata: list[dict]) -> dict:
    online = online_chapter(html)
    reference = [word for verse in online for word in tokens(verse["text"], verse=verse["verse"])]
    observed = []
    for page in REGIONS:
        observed.extend(tokens((ocr_directory / f"B-{page}.scripture.txt").read_text(), page=page))
    source = next(chapter for chapter in draft["chapters"] if chapter["number"] == 1)["verses"]
    covered = [number for verse in source for number in range(verse["verse"], verse.get("endVerse", verse["verse"]) + 1)]
    if covered != list(range(1, 65)):
        raise ValueError("The visually drafted chapter does not cover labels 1–64 exactly once.")
    source_tokens = [word for verse in source for word in tokens(verse["text"], verse=verse["verse"], end_verse=verse.get("endVerse"))]
    matched, differences = alignment(reference, observed)
    source_matched, source_differences = alignment(reference, source_tokens)
    source_ocr_matched, source_ocr_differences = alignment(source_tokens, observed)
    # A source unit may span pages; attach all its manually located pages to draft
    # difference rows instead of pretending every word has an exact page anchor.
    by_source_label = {verse["verse"]: verse for verse in source}
    for difference in source_differences:
        a0, a1 = difference["observedTokenRange"]
        labels = {word.verse for word in source_tokens[a0:a1]}
        difference["observedPages"] = sorted({page for label in labels for page in by_source_label[label]["sourcePages"]})
    observed_by_reference = dict(matched)
    online_by_observed = {b: a for a, b in matched}
    units = []
    for verse in source:
        start, end = verse["verse"], verse.get("endVerse", verse["verse"])
        indexes = [index for index, word in enumerate(reference) if start <= word.verse <= end]
        hits = [observed_by_reference[index] for index in indexes if index in observed_by_reference]
        pages = sorted({observed[index].page for index in hits})
        expected = verse["sourcePages"]
        units.append({"verse": start, "endVerse": end, "visuallyLocatedPages": expected,
                      "matchedOCRPages": pages, "referenceWords": len(indexes), "matchedWords": len(hits),
                      "firstWordMatched": bool(indexes) and indexes[0] in observed_by_reference,
                      "lastWordMatched": bool(indexes) and indexes[-1] in observed_by_reference,
                      "unexpectedPages": sorted(set(pages) - set(expected)),
                      "status": "alignment_candidate_not_certified"})
    revision = re.search(rb'"wgRevisionId":(\d+)', html)
    # This is an assistance layer, not a corrected Scripture transcription. Only
    # exact consonantal matches get an online candidate; every other OCR word stays.
    assisted = [{"page": word.page, "ocrWord": word.raw,
                 "onlineCandidate": reference[online_by_observed[index]].raw if index in online_by_observed else None,
                 "onlineVerse": reference[online_by_observed[index]].verse if index in online_by_observed else None,
                 "status": "consonants_match_pointing_unverified" if index in online_by_observed else "unresolved"}
                for index, word in enumerate(observed)]
    return {
        "schemaVersion": 1, "book": "1MA", "chapter": 1, "status": "research_baseline_not_for_import",
        "source": {"pdfSHA256": PDF_SHA256, "onlineURL": ONLINE_URL,
                   "onlineRevision": int(revision[1]) if revision else None, "onlineHTMLSHA256": digest(html)},
        "method": "Minimum word-edit alignment using hebrew_ocr_baseline.align. Only combining marks and punctuation are removed; spelling, final letters, prefixes, suffixes, and non-Hebrew OCR noise remain. Equal blocks are candidate alignments, not proof of source accuracy or pointing.",
        "scope": {"pages": list(REGIONS), "regions": REGIONS, "marginBoundaryByPage": MARGIN_BOUNDARY,
                  "printedUnits": len(source), "coveredVerseLabels": 64},
        "counts": {"onlineWords": len(reference), "ocrWords": len(observed), "exactAlignedConsonantalWords": len(matched),
                   "ocrDifferenceBlocks": len(differences), "visuallyDraftedWords": len(source_tokens),
                   "onlineToVisualDraftMatchedWords": len(source_matched), "onlineToVisualDraftDifferenceBlocks": len(source_differences),
                   "visualDraftToOCRMatchedWords": len(source_ocr_matched), "visualDraftToOCRDifferenceBlocks": len(source_ocr_differences)},
        "ocrPages": ocr_metadata, "units": units, "ocrDifferences": differences,
        "visualDraftDifferences": source_differences, "visualDraftToOCRDifferences": source_ocr_differences,
        "comparison": compare_texts(" ".join(row["text"] for row in online),
                                    " ".join((ocr_directory / f"B-{page}.scripture.txt").read_text() for page in REGIONS),
                                    "same-translation", reference_status="unreviewed"),
        "sourceDraftNotes": draft["review"]["notes"],
        "assistedWords": assisted,
        "limitations": ["The manually typed pointed chapter is itself a draft; its differences require final print adjudication.",
                        "Crops retain full Scripture lines and marginal labels. OCR word boxes in the known margin are recorded separately, not compared as Scripture. A merged body/margin box remains unresolved and is excluded without guessing its text.",
                        "Exact consonantal agreement cannot verify niqqud, punctuation, word boundaries, or the correct occurrence of a repeated phrase.",
                        "No differing OCR token is silently replaced from Wikisource. No page or book is marked reviewed by this tool."],
    }


def markdown(report: dict) -> str:
    counts = report["counts"]
    def cell(value) -> str:
        return str(value).replace("|", "\\|").replace("\n", " ")
    lines = ["# 1 Maccabees OCR baseline — chapter 1", "", "Research draft; not a certified transcription or import source.", "",
             f"Compared PDF B97–105 with the exact Kahana Wikisource chapter (revision {report['source']['onlineRevision']}) and the visually typed print draft.", "",
             f"PDF SHA-256: `{PDF_SHA256}`. Online HTML SHA-256: `{report['source']['onlineHTMLSHA256']}`.", "",
             "The comparison uses the shared minimum-word-edit aligner and removes pointing and punctuation only. It preserves spelling, prefixes, suffixes, final letters and non-Hebrew OCR noise. Repeated-word alignments remain candidates.", "",
             f"Online words: {counts['onlineWords']}; OCR words: {counts['ocrWords']}; exactly aligned consonantal words: {counts['exactAlignedConsonantalWords']}; unresolved OCR difference blocks: {counts['ocrDifferenceBlocks']}.", "",
             f"The visual draft has {report['scope']['printedUnits']} printed units covering labels 1–64. Its {counts['onlineToVisualDraftDifferenceBlocks']} differences from Wikisource are retained for adjudication; the draft is not an independent accuracy benchmark.", "",
             "## Page evidence", "", "| PDF page | OCR engine confidence | OCR text SHA-256 |", "| --- | ---: | --- |"]
    for page in report["ocrPages"]:
        lines.append(f"| {page['page']} | {page.get('confidence', 'unavailable')} | `{page['textSHA256']}` |")
    lines += ["", "## Printed labels and unresolved mixed layout", "",
              "These OCR boxes touch the visually located label margin and are excluded from Scripture alignment. Their raw words and coordinates remain in the JSON evidence. A mixed box may include both a label and body letters; it requires manual review rather than an automatic split.", "",
              "| PDF page | OCR text | Classification |", "| --- | --- | --- |"]
    for page in report["ocrPages"]:
        for word in page["excludedLayout"]:
            lines.append(f"| {page['page']} | {cell(word['text'])} | {word['classification']} |")
    lines += ["", "## Source-unit alignment", "", "| Printed label | Located PDF pages | Aligned OCR pages | Matched words | Both endpoints matched | Unexpected pages |",
              "| --- | --- | --- | ---: | --- | --- |"]
    for unit in report["units"]:
        label = str(unit["verse"]) if unit["verse"] == unit["endVerse"] else f"{unit['verse']}–{unit['endVerse']}"
        lines.append(f"| {label} | {cell(unit['visuallyLocatedPages'])} | {cell(unit['matchedOCRPages'])} | {unit['matchedWords']}/{unit['referenceWords']} | {unit['firstWordMatched'] and unit['lastWordMatched']} | {cell(unit['unexpectedPages'])} |")
    for title, key in [("Unresolved OCR differences", "ocrDifferences"), ("Wikisource versus visual draft", "visualDraftDifferences")]:
        lines += ["", f"## {title}", "", "All rows require source review; a difference is not permission to substitute the online wording.", "",
                  "| Reference label(s) | PDF page(s) | Wikisource words | Observed/draft words |", "| --- | --- | --- | --- |"]
        for row in report[key]:
            lines.append(f"| {cell(row['referenceVerses'])} | {cell(row['observedPages'])} | {cell(' '.join(row['referenceWords']))} | {cell(' '.join(row['observedWords']))} |")
    if trial := report.get("vocabularyTrial"):
        lines += ["", "## Held-out vocabulary trial", "",
                  f"Page B105 was recognized twice with the same image, model and settings. The optional dictionary contains {trial['vocabularyWords']} distinct words from online chapters 2–16; all of chapter 1 is excluded. Its SHA-256 is `{trial['vocabularySHA256']}`.", "",
                  "| Mode | Equal words | Replaced words | Missing words | Added words |", "| --- | ---: | ---: | ---: | ---: |"]
        for mode, result in trial["results"].items():
            count = result["wordOperations"]
            lines.append(f"| {mode} | {count['equal']} | {count['replace']} | {count['delete']} | {count['insert']} |")
        lines += ["", "The reference is the visually typed draft and remains unreviewed. These are alignment counts, not an OCR accuracy measurement. Vocabulary also changes pointing, which this consonantal comparison cannot validate.", ""]
    lines += ["", "## Reproduction and limits", "", "Run `Shared/tools/compare-1maccabees-ocr.py` with the pinned PDF, cached Wikisource HTML, source draft and `Shared/tools/ocr-1maccabees-page.cjs` as `--ocr-runner`. Set `PROSARY_HEBREW_OCR_RUNTIME` to the local directory containing Tesseract.js and `heb.traineddata`. Add `--vocabulary-trial` for the held-out page experiment. The output directory holds every page crop, OCR text, OCR metadata, and a full JSON alignment including context and unchanged uncertain words. `--evidence` writes compact durable evidence with all raw page OCR; `--markdown` writes this report.", "",
              f"Source draft SHA-256: `{report.get('provenance', {}).get('sourceDraftSHA256', 'unavailable')}`. Neither the comparison nor the vocabulary trial changes that source draft.", ""]
    lines += [f"- {limitation}" for limitation in report["limitations"]]
    lines += ["", "## Print draft findings awaiting final review", ""]
    lines += [f"- {note}" for note in report["sourceDraftNotes"]]
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pdf", required=True, type=Path)
    parser.add_argument("--online-html", required=True, type=Path)
    parser.add_argument("--source-draft", type=Path, default=ROOT / "content/hebrew-deuterocanon/1MA.json")
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--ocr-runner", type=Path, help="Local Tesseract.js runner: node RUNNER IMAGE TEXT, emits JSON metadata.")
    parser.add_argument("--ocr-model", type=Path, help="Record the exact trained model SHA-256.")
    parser.add_argument("--vocabulary-trial", action="store_true", help="Compare page 105 with/without a chapters-2–16 word dictionary; requires --ocr-runner.")
    parser.add_argument("--markdown", type=Path)
    parser.add_argument("--evidence", type=Path, help="Write compact durable provenance, page OCR, and comparison evidence.")
    args = parser.parse_args()
    for destination in (args.markdown, args.evidence):
        if destination and destination.resolve() in {path.resolve() for path in (args.pdf, args.online_html, args.source_draft)}:
            parser.error("The report must not overwrite an input source.")
    if args.vocabulary_trial and not args.ocr_runner:
        parser.error("--vocabulary-trial requires the local --ocr-runner.")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    images = render(args.pdf, args.output_dir)
    if args.ocr_runner:
        metadata = run_ocr(args.ocr_runner, images, args.output_dir)
    else:
        metadata = []
        for page, image in images.items():
            prior = json.loads((args.output_dir / f"B-{page}.ocr.json").read_text())
            if prior.get("imageSHA256") != digest(image.read_bytes()):
                raise ValueError(f"Cached OCR for B{page} is not pinned to the rendered crop; rerun with --ocr-runner.")
            if prior.get("text") != (args.output_dir / f"B-{page}.txt").read_text():
                raise ValueError(f"Cached OCR text for B{page} has changed since recognition.")
            comparison_text, excluded = scripture_ocr(prior, page, pymupdf.Pixmap(image).width)
            (args.output_dir / f"B-{page}.scripture.txt").write_text(comparison_text)
            metadata.append({"page": page, "engine": {key: value for key, value in prior.items() if key not in {"text", "words"}},
                             "excludedLayout": excluded, "comparisonTextSHA256": digest(comparison_text.encode()),
                             "confidence": prior.get("confidence"), "imageSHA256": digest(image.read_bytes()),
                             "textSHA256": digest((args.output_dir / f"B-{page}.txt").read_bytes())})
    html, draft = args.online_html.read_bytes(), json.loads(args.source_draft.read_text())
    report = compare(html, draft, args.output_dir, metadata)
    report["provenance"] = {"sourceDraftSHA256": digest(args.source_draft.read_bytes()),
                            "comparisonToolSHA256": digest(Path(__file__).read_bytes()),
                            "sharedAlignerSHA256": digest(Path(__file__).with_name("hebrew_ocr_baseline.py").read_bytes()),
                            "renderer": "PyMuPDF", "rendererVersion": pymupdf.VersionBind, "renderScale": 5}
    if args.vocabulary_trial:
        report["vocabularyTrial"] = vocabulary_trial(html, draft, args.ocr_runner, images, args.output_dir / "vocabulary-trial")
    if args.ocr_runner:
        report["ocrRunnerSHA256"] = digest(args.ocr_runner.read_bytes())
    if args.ocr_model:
        report["ocrModelSHA256"] = digest(args.ocr_model.read_bytes())
    (args.output_dir / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    (args.markdown or args.output_dir / "report.markdown").write_text(markdown(report))
    if args.evidence:
        compact = {key: value for key, value in report.items() if key not in {
            "ocrDifferences", "visualDraftDifferences", "visualDraftToOCRDifferences", "assistedWords", "comparison"}}
        compact["comparison"] = {key: value for key, value in report["comparison"].items() if key != "alignment"}
        compact["rawOCRByPage"] = {str(page): (args.output_dir / f"B-{page}.txt").read_text() for page in REGIONS}
        compact["scriptureCandidateOCRByPage"] = {str(page): (args.output_dir / f"B-{page}.scripture.txt").read_text() for page in REGIONS}
        compact["referenceSnapshot"] = {"onlineChapter": online_chapter(html),
                                        "visualDraftChapter": next(row for row in draft["chapters"] if row["number"] == 1)}
        if "vocabularyTrial" in compact:
            compact["vocabularyTrial"] = {**compact["vocabularyTrial"], "results": {
                mode: {key: value for key, value in result.items() if key != "alignment"}
                for mode, result in compact["vocabularyTrial"]["results"].items()}}
        args.evidence.write_text(json.dumps(compact, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report["counts"], ensure_ascii=False))


if __name__ == "__main__":
    main()

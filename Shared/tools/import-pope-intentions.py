#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf"]
# ///
"""Import the published 2026–2027 intentions and the credited Hebrew translation.

Download the official PDFs into --source-dir or use --fetch. French, Italian and
Filipino have extractable text; Arabic uses the reviewed transcription beside this
script because the publisher's PDF has a broken character map. The reviewed 2027
snapshot records each official source. Hebrew is explicitly credited to Prosary,
not presented as a published Vatican edition. --sync copies the result.
"""
import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path

from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "Shared/data/pope-intentions.json"
BASE = "https://www.popesprayer.va/wp-content/uploads/2025/06/"
SOURCES = {
    "fr": BASE + "FRA-INTENTIONS-DE-PRIERE-DU-SAINT-PERE-2026-1.pdf",
    "it": BASE + "ITA-INTENZIONI-DI-PREGHIERA-DEL-SANTO-PADRE-2026-1.pdf",
    "tl": BASE + "TL-MGA-INTENSYONG-PAMPANALANGIN-NG-SANTO-PAPA-2026-1.pdf",
    "ar": BASE + "AR-PRAYER-INTENTIONS-OF-THE-HOLY-FATHER-2026-1.pdf",
}
MONTHS = {
    "fr": "JANVIER FÉVRIER MARS AVRIL MAI JUIN JUILLET AOÛT SEPTEMBRE OCTOBRE NOVEMBRE DÉCEMBRE".split(),
    "it": "GENNAIO FEBBRAIO MARZO APRILE MAGGIO GIUGNO LUGLIO AGOSTO SETTEMBRE OTTOBRE NOVEMBRE DICEMBRE".split(),
    "tl": "ENERO FEBRERO MARSO ABRIL MAYO HUNYO HULYO AGOSTO SEPTIEMBRE OCTUBRE NOVIEMBRE DISYEMBRE".split(),
}


def extract_intentions(path, language):
    text = "\n".join(page.extract_text() for page in PdfReader(path).pages)
    headings = MONTHS[language]
    matches = list(re.finditer(r"(?m)^\s*(" + "|".join(headings) + r")\s*$", text))
    if [match.group(1) for match in matches] != headings:
        raise ValueError(f"{language}: expected the twelve months in order")
    result = {}
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index < 11 else len(text)
        lines = [line.strip() for line in text[match.end():end].splitlines() if line.strip()]
        if index == 11:
            signature = {"fr": "Léon XIV", "it": "Leone XIV", "tl": "Leo XIV"}[language]
            lines = lines[:lines.index(signature)]
        title, body = lines[0], re.sub(r"\s+", " ", " ".join(lines[1:]))
        title = re.sub(r"(?<=\w)\s*-\s*(?=\w)", "-", title)
        body = re.sub(r"(?<=\w)\s*-\s*(?=\w)", "-", body).replace(" ,", ",")
        if not body or "\ufffd" in title + body:
            raise ValueError(f"{language}/{index + 1}: incomplete source extraction")
        result[f"2026-{index+1:02d}"] = {"title": title, "text": body}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--sync", action="store_true")
    args = parser.parse_args()
    args.source_dir.mkdir(parents=True, exist_ok=True)
    payload = json.loads(DATA.read_text())
    for language in MONTHS:
        source = args.source_dir / f"intentions-{language}.pdf"
        if args.fetch and not source.exists():
            subprocess.run(["curl", "-L", "--fail", "--silent", "--show-error", SOURCES[language], "-o", str(source)], check=True)
        for month, values in extract_intentions(source, language).items():
            row = payload["months"][month]
            for field in ("title", "text"):
                row.setdefault(field + "ByLanguage", {})[language] = values[field]
            row.setdefault("sourceByLanguage", {})[language] = SOURCES[language]
    arabic = Path(__file__).with_name("pope-intentions-2026-ar.json")
    if arabic.exists():
        for month, values in json.loads(arabic.read_text())["months"].items():
            row = payload["months"][month]
            for field in ("title", "text"):
                row.setdefault(field + "ByLanguage", {})["ar"] = values[field]
            row.setdefault("sourceByLanguage", {})["ar"] = SOURCES["ar"]
    russian = json.loads(Path(__file__).with_name("pope-intentions-2026-ru.json").read_text())
    for month, values in russian["months"].items():
        row = payload["months"][month]
        for field in ("title", "text"):
            row.setdefault(field + "ByLanguage", {})["ru"] = values[field]
        row.setdefault("sourceByLanguage", {})["ru"] = russian["source"]
        row.setdefault("translationCreditByLanguage", {})["ru"] = russian["credit"]
    published = json.loads(Path(__file__).with_name("pope-intentions-2027-published.json").read_text())
    hebrew = json.loads(Path(__file__).with_name("pope-intentions-2027-he.json").read_text())
    expected = {f"2027-{month:02d}" for month in range(1, 13)}
    if set(published["months"]) != expected or set(hebrew["months"]) != expected:
        raise ValueError("2027 must contain exactly twelve months")
    for month, translations in published["months"].items():
        row = payload["months"].setdefault(month, {})
        row.update(translations["en"])
        for language, values in translations.items():
            if any(not values[field].strip() or "\ufffd" in values[field] for field in ("title", "text")):
                raise ValueError(f"{month}/{language}: incomplete published text")
            if language != "en":
                for field in ("title", "text"):
                    row.setdefault(field + "ByLanguage", {})[language] = values[field]
            row.setdefault("sourceByLanguage", {})[language] = published["sources"][language]
        for correction, detail in published.get("sourceCorrections", {}).items():
            corrected_month, language = correction.split(".")
            if corrected_month == month:
                row["sourceByLanguage"][language] = detail["source"]
        for field in ("title", "text"):
            row.setdefault(field + "ByLanguage", {})["he"] = hebrew["months"][month][field]
    for row in payload["months"].values():
        row.setdefault("translationCreditByLanguage", {})["he"] = "Prosary — Hebrew translation of the published intention"
    payload["$comment"] = "2026–2027 intentions published by the Pope's Worldwide Prayer Network. Language source URLs identify published editions; Hebrew is Prosary's translation, not an official Vatican Hebrew edition. Missing languages fall back to the published English. Months outside this table hide the row."
    payload["generated"] = "2026-09-05"
    DATA.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    if args.sync:
        for target in ("iOS/Prosary/Data", "Android/app/src/main/assets/data", "Windows/Prosary/Data"):
            shutil.copy2(DATA, ROOT / target / DATA.name)
    print("Imported 2026–2027 published intentions and credited Hebrew translations.")


if __name__ == "__main__":
    main()

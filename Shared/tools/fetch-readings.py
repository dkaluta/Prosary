#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["requests"]
# ///
"""Fetch a rolling offline table of daily Roman-lectionary citations from Evangelizo HE.

Only citations and the API's sourced Hebrew book titles are retained; Scripture text is not
copied. Use --sync to copy the generated JSON into every native port.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import json
import re
import shutil
import time
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "Shared" / "data"
TARGETS = [
    ROOT / "iOS" / "Prosary" / "Data",
    ROOT / "Android" / "app" / "src" / "main" / "assets" / "data",
    ROOT / "Windows" / "Prosary" / "Data",
]
URL = "https://publication.evangelizo.ws/HE/days/{date}"

BOOKS = {
    "Gn": ("Gen.", "Genesis"), "Ex": ("Exod.", "Exodus"), "Lv": ("Lev.", "Leviticus"),
    "Nb": ("Num.", "Numbers"), "Dt": ("Deut.", "Deuteronomy"), "Jos": ("Josh.", "Joshua"),
    "Jg": ("Judg.", "Judges"), "Rt": ("Ruth", "Ruth"), "1_S": ("1 Sam.", "1 Samuel"),
    "2_S": ("2 Sam.", "2 Samuel"), "1_K": ("1 Kgs.", "1 Kings"), "2_K": ("2 Kgs.", "2 Kings"),
    "1_Ch": ("1 Chr.", "1 Chronicles"), "2_Ch": ("2 Chr.", "2 Chronicles"),
    "Ezr": ("Ezra", "Ezra"), "Ne": ("Neh.", "Nehemiah"), "Tb": ("Tob.", "Tobit"),
    "Jdt": ("Jdt.", "Judith"), "Est": ("Esth.", "Esther"), "1_M": ("1 Macc.", "1 Maccabees"),
    "2_M": ("2 Macc.", "2 Maccabees"), "Jb": ("Job", "Job"), "Ps": ("Ps.", "Psalm"),
    "Pr": ("Prov.", "Proverbs"), "Qo": ("Eccl.", "Ecclesiastes"), "Sg": ("Song", "Song of Songs"),
    "Ws": ("Wis.", "Wisdom"), "Si": ("Sir.", "Sirach"), "Is": ("Isa.", "Isaiah"),
    "Jr": ("Jer.", "Jeremiah"), "Lm": ("Lam.", "Lamentations"), "Ba": ("Bar.", "Baruch"),
    "Ezk": ("Ezek.", "Ezekiel"), "Dn": ("Dan.", "Daniel"), "Ho": ("Hos.", "Hosea"),
    "Jl": ("Joel", "Joel"), "Am": ("Amos", "Amos"), "Ob": ("Obad.", "Obadiah"),
    "Jon": ("Jon.", "Jonah"), "Mi": ("Mic.", "Micah"), "Na": ("Nah.", "Nahum"),
    "Hab": ("Hab.", "Habakkuk"), "Zp": ("Zeph.", "Zephaniah"), "Hg": ("Hag.", "Haggai"),
    "Zc": ("Zech.", "Zechariah"), "Ml": ("Mal.", "Malachi"), "Mt": ("Mt.", "Matthew"),
    "Mc": ("Mk.", "Mark"), "Lc": ("Lk.", "Luke"), "Jn": ("Jn.", "John"),
    "Ac": ("Acts", "Acts"), "Rm": ("Rom.", "Romans"), "1_Co": ("1 Cor.", "1 Corinthians"),
    "2_Co": ("2 Cor.", "2 Corinthians"), "Ga": ("Gal.", "Galatians"), "Ep": ("Eph.", "Ephesians"),
    "Ph": ("Phil.", "Philippians"), "Col": ("Col.", "Colossians"), "1_Th": ("1 Thess.", "1 Thessalonians"),
    "2_Th": ("2 Thess.", "2 Thessalonians"), "1_Tm": ("1 Tim.", "1 Timothy"),
    "2_Tm": ("2 Tim.", "2 Timothy"), "Tt": ("Titus", "Titus"), "Phm": ("Phlm.", "Philemon"),
    "Heb": ("Heb.", "Hebrews"), "Jas": ("Jas.", "James"), "1_P": ("1 Pet.", "1 Peter"),
    "2_P": ("2 Pet.", "2 Peter"), "1_Jn": ("1 Jn.", "1 John"), "2_Jn": ("2 Jn.", "2 John"),
    "3_Jn": ("3 Jn.", "3 John"), "Jude": ("Jude", "Jude"), "Rv": ("Rev.", "Revelation"),
}


def normalized_reference(raw: str) -> str:
    parts = []
    for segment in raw.split("#"):
        segment = re.sub(r"^[^ ]+\s+", "", segment)
        segment = re.sub(r"(\d+)-(\1)(?=$|[^\d])", r"\1", segment)
        parts.append(segment.replace(",", ":").replace("-", "–"))
    return "; ".join(parts)


def fetch(day: dt.date) -> tuple[str, dict] | None:
    response = None
    for attempt in range(4):
        try:
            response = requests.get(URL.format(date=day.isoformat()), timeout=20)
            if response.status_code == 200:
                break
        except requests.RequestException:
            pass
        time.sleep(0.5 * (attempt + 1))
    if response is None or response.status_code != 200:
        return None
    readings = []
    for item in (response.json().get("data") or {}).get("readings") or []:
        code = (item.get("reading_code") or "").strip()
        match = re.match(r"([^ ]+)\s+(.+)", code)
        if not match:
            continue
        book_code, raw_reference = match.groups()
        short_book, full_book = BOOKS.get(book_code, (book_code.replace("_", " "), book_code.replace("_", " ")))
        chapter = re.search(r"\d+", raw_reference)
        reference = normalized_reference(raw_reference)
        book = item.get("book") or {}
        hebrew_book = (book.get("full_title") or book.get("short_title") or "").strip()
        readings.append({
            "type": item.get("type") or "reading",
            "short": f"{short_book} {chapter.group(0)}" if chapter else short_book,
            "full": f"{full_book} {reference}",
            "hebrew": f"{hebrew_book} {reference}" if hebrew_book else f"{full_book} {reference}",
        })
    return (day.isoformat(), {"readings": readings}) if readings else None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--days-back", type=int, default=31)
    parser.add_argument("--days-ahead", type=int, default=100)
    parser.add_argument("--sync", action="store_true")
    args = parser.parse_args()

    today = dt.date.today()
    days = [today + dt.timedelta(days=n) for n in range(-args.days_back, args.days_ahead + 1)]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        rows = [row for row in pool.map(fetch, days) if row]
    destination = DATA / "readings.json"
    existing = {}
    if destination.exists():
        existing = json.loads(destination.read_text(encoding="utf-8")).get("days", {})
    existing.update(dict(rows))
    output = {
        "$comment": "Daily Roman-lectionary citations courtesy of Evangelizo.org — Daily Gospel (© Evangelizo.org), publication edition HE. Hebrew book titles are relayed from the source; Scripture text is not included.",
        "generated": today.isoformat(),
        "days": dict(sorted(existing.items())),
    }
    destination.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.sync:
        for target in TARGETS:
            target.mkdir(parents=True, exist_ok=True)
            shutil.copy2(destination, target / destination.name)
    print(f"Wrote {destination} ({len(existing)} days; refreshed {len(rows)})")


if __name__ == "__main__":
    main()

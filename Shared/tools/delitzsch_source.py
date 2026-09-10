#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Extract the vocalized historical Delitzsch text from delitz.fr/12 chapters.

Only numbered verse bodies inside the article are Scripture. Navigation, headings
and linked verse labels never enter the corpus. No Hebrew marks are added, removed
or normalized here; the Bible builder separately handles the Divine Name.
"""
from html.parser import HTMLParser
from functools import lru_cache
import json
from pathlib import Path
import re


class DelitzschChapterParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.in_article = False
        self.article_count = 0
        self.marker_depth = 0
        self.current = None
        self.parts = []
        self.verses = {}

    def flush(self):
        if self.current is not None:
            text = re.sub(r"\s+", " ", "".join(self.parts)).strip()
            if not text or not re.search(r"[\u05b0-\u05bb\u05c7]", text):
                raise ValueError(f"Missing vocalized Delitzsch verse {self.current}")
            self.verses[self.current] = text
        self.current = None
        self.parts = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "article":
            self.article_count += 1
            if self.article_count != 1:
                raise ValueError("Multiple Scripture articles")
            self.in_article = True
            return
        if not self.in_article:
            return
        if self.marker_depth:
            if tag not in {"br", "wbr", "hr", "img"}:
                self.marker_depth += 1
            return
        if tag in {"script", "style", "nav"}:
            raise ValueError("Unexpected non-Scripture content inside article")
        is_marker = tag == "p" and "id" in attrs or tag == "span" and attrs.get("class") == "v"
        if is_marker:
            number = attrs.get("id", "")
            if not re.fullmatch(r"[1-9]\d*", number):
                raise ValueError("Invalid Delitzsch verse marker")
            self.flush()
            self.current = int(number)
            if self.current != len(self.verses) + 1:
                raise ValueError(f"Missing, repeated or unordered Delitzsch verse {number}")
            if tag == "span":
                self.marker_depth = 1
        elif tag in {"p", "br"} and self.current is not None:
            self.parts.append(" ")

    def handle_endtag(self, tag):
        if not self.in_article:
            return
        if self.marker_depth:
            self.marker_depth -= 1
            return
        if tag == "article":
            self.flush()
            self.in_article = False

    def handle_data(self, data):
        if self.in_article and self.current is not None and not self.marker_depth:
            self.parts.append(data)


def parse_chapter(raw: bytes) -> dict[int, str]:
    parser = DelitzschChapterParser()
    parser.feed(raw.decode("utf-8"))
    parser.close()
    if parser.article_count != 1 or parser.in_article or parser.marker_depth or not parser.verses:
        raise ValueError("Incomplete Delitzsch Scripture article")
    return parser.verses


@lru_cache(maxsize=1)
def source_reviews():
    data = json.loads((Path(__file__).parent / "delitzsch-source-reviews.json").read_text())
    if data.get("schemaVersion") != 1:
        raise ValueError("Unsupported Delitzsch source review")
    return data["corrections"]


def apply_reviewed_corrections(source: dict, verses: dict[int, str]) -> dict[int, str]:
    """Apply only exact, scan-verified transcription corrections to pinned pages."""
    result = dict(verses)
    for review in source_reviews():
        if review["sourceId"] != source["id"]:
            continue
        if review["sourceSHA256"] != source["sha256"]:
            raise ValueError("Delitzsch correction source changed; review the printed page again")
        verse = review["verse"]
        before, after = review["before"], review["after"]
        if not before or not after or result.get(verse, "").count(before) != 1:
            raise ValueError("Delitzsch correction no longer matches the inspected verse")
        result[verse] = result[verse].replace(before, after, 1)
    return result

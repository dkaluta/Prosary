#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Hash-pinned, source-native Patriarchate 2020 OT chapters from peshitta.eu.

This adapter retains the website's vocalization and numbered verse bodies. It
does not infer missing text, correct copied chapters or apply calendar numbering.
Daily correspondences have a separate bounded, source-pinned review.
"""
from functools import lru_cache
from html.parser import HTMLParser
import hashlib
import json
from pathlib import Path
import re
import unicodedata

TOOLS = Path(__file__).resolve().parent
REVIEW_PATH = TOOLS / "peshitta-eu-2020-review.json"


class VerseParser(HTMLParser):
    def __init__(self, slug, chapter):
        super().__init__(convert_charrefs=True)
        self.slug, self.chapter = slug, chapter
        self.current = None
        self.words = []
        self.values = {}

    def handle_starttag(self, tag, attrs):
        fields = dict(attrs)
        if self.current is not None:
            raise ValueError("Peshitta verse contains unsupported inline markup")
        if tag == "span" and fields.get("class") == "verse":
            match = re.fullmatch(r"v([1-9][0-9]*)", fields.get("id", ""))
            if not match:
                raise ValueError("Peshitta source has an invalid verse label")
            number = int(match[1])
            if fields.get("data-ref") != f"{self.slug}.{self.chapter}.{number}":
                raise ValueError("Peshitta verse has a wrong book/chapter reference")
            if number in self.values:
                raise ValueError("Peshitta source repeats a verse label")
            self.current, self.words = number, []

    def handle_data(self, data):
        if self.current is not None:
            self.words.append(data)

    def handle_endtag(self, tag):
        if self.current is None:
            return
        if tag != "span":
            raise ValueError("Peshitta verse contains mismatched markup")
        text = "".join(self.words).strip()
        match = re.fullmatch(str(self.current) + r"\s+(.+)", text, flags=re.S)
        if match is None:
            raise ValueError("Peshitta printed verse label differs from its reference")
        text = match[1].strip()
        if not re.search(r"[\u0710-\u072f]", text):
            raise ValueError("Peshitta source verse has no Syriac wording")
        if not re.search(r"[\u0730-\u073d]", text):
            raise ValueError("Peshitta source verse has no vocalized Scripture wording")
        self.values[self.current] = text
        self.current = None


def parse_chapter(raw: bytes, slug: str, chapter: int) -> dict[int, str]:
    parser = VerseParser(slug, chapter)
    parser.feed(raw.decode("utf-8-sig"))
    parser.close()
    if parser.current is not None or not parser.values:
        raise ValueError("Peshitta source has an unfinished or empty verse body")
    if list(parser.values) != list(range(1, max(parser.values) + 1)):
        raise ValueError("Peshitta source has missing or unordered verse labels")
    return parser.values


@lru_cache(maxsize=1)
def review():
    value = json.loads(REVIEW_PATH.read_text())
    if value.get("schemaVersion") != 1:
        raise ValueError("Unsupported peshitta.eu source review")
    return value


def load_verses(source, raw):
    if hashlib.sha256(raw).hexdigest() != source["sha256"]:
        raise ValueError("Peshitta website chapter differs from its pinned source")
    excluded = review()["excludedChapters"].get(f"{source['book']}:{source['chapter']}")
    if excluded is not None:
        return {}
    values = parse_chapter(raw, source["slug"], source["chapter"])
    for row in review().get("editorialExclusions", []):
        if (row["book"], row["chapter"]) != (source["book"], source["chapter"]):
            continue
        original = values[row["verse"]]
        if hashlib.sha256(original.encode()).hexdigest() != row["sourceVerseSHA256"]:
            raise ValueError("Peshitta website editorial caption changed")
        if not original.startswith(row["text"]):
            raise ValueError("Peshitta website caption boundary changed")
        values[row["verse"]] = original[len(row["text"]):].lstrip()
    return {(source["chapter"], verse): text for verse, text in values.items()}


def consonants(text):
    """Corroborate reviewed boundaries without importing the former XML wording."""
    # The source's marked rish and word-final semkath are orthographic forms.
    text = text.replace("ܖ̈", "ܪ").replace("ܤ", "ܣ")
    return tuple("".join(char for char in word if "\u0710" <= char <= "\u072f"
                         and unicodedata.category(char).startswith("L"))
                 for word in text.split() if re.search(r"[\u0710-\u072f]", word))


def reviewed_mapping():
    value = review()
    allowed = {tuple(reference) for reference in value["reviewedReferences"]}
    overrides = {reference: (reference,) for reference in allowed}
    for group in value["compoundUnits"]:
        members = tuple(tuple(reference) for reference in group)
        if not set(members) <= allowed:
            raise ValueError("Peshitta website compound unit is incomplete")
        overrides.update({reference: members for reference in members})
    return allowed, overrides

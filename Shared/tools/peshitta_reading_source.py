#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Source-preserving Peshitta imports and their existing Hebrew-script projection.

The NT uses the same pinned BFBS 1905 TEI as the prayer importer. Isaiah remains
restricted to that importer's nine accepted verses; no other OT text is exposed.
"""
from functools import lru_cache
import importlib.util
from pathlib import Path
import re
import xml.etree.ElementTree as ET

from aramaic_script_converter import to_hebrew


@lru_cache(maxsize=1)
def scripture_importer():
    spec = importlib.util.spec_from_file_location(
        "peshitta_scripture_importer", Path(__file__).with_name("import-scripture.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_verses(source: dict, raw: bytes) -> dict:
    importer = scripture_importer()
    if source["format"] == "peshitta-isaiah":
        importer.verify_supplied_peshitta_hash(raw)
        return importer.parse_supplied_peshitta_isaiah(raw.decode("utf-8-sig"))
    if source["format"] != "peshitta-tei":
        raise ValueError("Unsupported Peshitta source format")
    ns = {"t": "http://www.tei-c.org/ns/1.0"}
    root = ET.fromstring(raw)
    numbers = [int(chapter.attrib["n"]) for chapter in root.findall(
        "t:text/t:body/t:div[@type='chapter']", ns)]
    if not numbers or len(numbers) != len(set(numbers)):
        raise ValueError("Peshitta source has missing or duplicate chapters")
    excluded = source.get("excludedChapters", {})
    if not set(map(int, excluded)) <= set(numbers):
        raise ValueError("Peshitta exclusion is outside its source chapters")
    result = {}
    for chapter in numbers:
        try:
            verses = importer.parse_pointed_peshitta(raw, source["bookName"], {chapter})
        except ValueError as error:
            if excluded.get(str(chapter)) != str(error):
                raise
            continue
        if str(chapter) in excluded:
            raise ValueError("Peshitta chapter exclusion no longer matches its source")
        result.update(verses)
    return result


def paired_text(syriac: str) -> tuple[str, str]:
    """Return Hebrew projection and untouched source; never reconstruct Syriac."""
    if not isinstance(syriac, str) or not re.search(r"[\u0710-\u072f]", syriac):
        raise ValueError("Peshitta verse lacks source Syriac letters")
    hebrew = to_hebrew(syriac)
    if not re.search(r"[\u05d0-\u05ea]", hebrew):
        raise ValueError("Peshitta verse lacks its Hebrew-script projection")
    return hebrew, syriac

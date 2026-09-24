#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Offline source checks for the two Syriac Rosary invitatory forms."""
import json
from pathlib import Path
import re

from aramaic_script_converter import to_hebrew

TOOLS = Path(__file__).resolve().parent
fixture = json.loads((TOOLS / "fixtures/syriac-invitatory-source.json").read_text())
data = json.loads((TOOLS.parent / "content/rosary/content/arc.json").read_text())
psalm = fixture["psalm"]
alleluia = fixture["alleluia"]

# This is the five-word verse after the numbered superscription, not the
# superscription itself or a modern pointed edition with similar consonants.
assert psalm["printedPage"] == 194 and psalm["pdfPage"] == 9
assert psalm["sourceReference"] == "Psalm 70:2 (superscription numbered 70:1)"
assert psalm["pdfSha256"] == "f54132b1d7e5fd6340f8bba5a8bad9f1205ad71ab9d8e8ade63b87fd2b50a0f9"
assert psalm["transcription"] == "ܐܰܠܳܗܳܐ ܦܰܨܳܢܝ ܡܳܪܝܳܐ ܠܥܽܘܕܪܳܢܝ ܟܰܬܰܪ"
assert " ".join(re.sub(r"[.*]", "", psalm["displayedOpening"]).split()) == psalm["transcription"]
assert to_hebrew(psalm["displayedOpening"]) == psalm["hebrewOpening"]

# The inherited New Testament license does not apply to Walton or the supplied
# Isaiah XML. Keep the one-word excerpt tied to its actual source verse.
assert alleluia["reference"] == "Revelation 19:1"
assert alleluia["excerpt"] == "ܗܰܠܶܠܽܘܝܰܐ"
assert f" {alleluia['excerpt']} . " in alleluia["sourceVerse"]
assert alleluia["license"] == "https://creativecommons.org/licenses/by/4.0/"
assert alleluia["sourceSha256"] == "3f253a09cf77ef1c0f0160e21167e1279a675bb54eb3725289dea8aa4649f7d1"
assert to_hebrew(alleluia["excerpt"]) == alleluia["hebrew"]

for field, opening, ending in (
    ("prayers", psalm["hebrewOpening"], alleluia["hebrew"]),
    ("transliterations", psalm["displayedOpening"], alleluia["excerpt"]),
):
    prayers = data[field]
    lent = prayers["invitatoryBodyLent"]
    ordinary = prayers["invitatoryBody"]
    assert lent == opening + "\n\n" + prayers["gloriaPatri"], field
    assert ordinary == lent + " " + ending + ".", field
    assert ending not in lent, field
    assert ordinary.count(ending) == 1, field
    assert ordinary.count("**") == 2, field

# The existing basic-prayer pair is preserved literally, rather than normalized
# through the converter while assembling the new forms.
assert data["prayers"]["gloriaPatri"] == "שוּבחָא לַאבָא ✠ ולַברָא וַלרוּחָא קַדישָא\nמֶן עָלַם וַעדַמָא לעָלַם עָלמִין. אַמִין."
assert data["transliterations"]["gloriaPatri"] == "ܫܽܘܒܚܳܐ ܠܰܐܒܳܐ ✠ ܘܠܰܒܪܳܐ ܘܰܠܪܽܘܚܳܐ ܩܰܕܝܫܳܐ\nܡܶܢ ܥܳܠܰܡ ܘܰܥܕܰܡܳܐ ܠܥܳܠܰܡ ܥܳܠܡܺܝܢ. ܐܰܡܺܝܢ."
assert "invitatoryBody" not in data.get("$scriptureImport", {}).get("prayerKeys", [])
assert "invitatoryBodyLent" not in data.get("$scriptureImport", {}).get("prayerKeys", [])
print("Syriac invitatory source, paired scripts, supplied Gloria, and Lenten form passed.")

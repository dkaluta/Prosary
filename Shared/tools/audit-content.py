#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Content audit across every bundle: flags likely-truncated texts and drift from the
hardcoded translation tables.

Two checks (run from the repo root, no arguments):
1. Terminal-punctuation lint over every prayers/mysteries value — bodies must end like
   sentences (titles/labels are exempt; citations may end in verse digits). This is what a
   truncated authoring-time extraction looks like (the Via Lucis Regina Caeli once ended
   mid-sentence at "has risen as ").
2. For any bundle key that shadows a hardcoded PrayerKey, the bundle text must equal the
   iOS translation table (extracted concatenation-aware: Swift `"a" + "b"` strings were
   exactly what clipped the Regina Caeli).

Exit 1 when anything is flagged, so it can gate CI or the packer later if wanted.
"""

import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SWIFT = {
    "la": "PrayerTranslations+Latin.swift", "en": "PrayerTranslations+English.swift",
    "ar": "PrayerTranslations+Arabic.swift", "he": "PrayerTranslations+Hebrew.swift",
    "ru": "PrayerTranslations+Russian.swift", "tl": "PrayerTranslations+Tagalog.swift",
}
TERMINATORS = tuple(".!?)*\u05f4\u201d\"'\u2026\u05c3\u061f\u06d4]")
# These complete source-supplied chants intentionally have no terminal punctuation.
# Keep the exemption scoped to their bundle, recension and key; ordinary prose still fails.
UNPUNCTUATED_CHANTS = {
    ("trisagion", language, key)
    for language in ("arc", "he-x-gamliel")
    for key in ("trisagionAcclamation", "trisagionShortAcclamation", "trisagionKyrie")
}
# The French Vatican Compendium prints this complete hymn without a final punctuation mark.
UNPUNCTUATED_CHANTS.add(("rosary", "fr", "salveRegina"))


def load_hardcoded(lang):
    path = os.path.join(ROOT, "iOS/Prosary/Mocks/Content", SWIFT[lang])
    src = open(path, encoding="utf-8").read()
    table = {}
    pattern = r'\.(\w+):\s*((?:"""[\s\S]*?"""|(?:"(?:[^"\\]|\\.)*"\s*\+?\s*)+))\s*,'
    for m in re.finditer(pattern, src):
        key, raw = m.group(1), m.group(2)
        if raw.startswith('"""'):
            body = re.sub(r"\n\s*$", "", re.sub(r"^\n", "", raw[3:-3]))
            lines = body.split("\n")
            indents = [len(l) - len(l.lstrip()) for l in lines if l.strip()]
            pad = min(indents) if indents else 0
            value = "\n".join(l[pad:] for l in lines)
        else:
            value = "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', raw))
        value = value.replace("\\n", "\n").replace('\\"', '"').replace("\\\\", "\\")
        value = re.sub(r"\\u\{([0-9A-Fa-f]+)\}", lambda m: chr(int(m.group(1), 16)), value)
        table[key] = value
    return table


def terminal_ok(text):
    t = text.rstrip("\n")
    if t != text.rstrip() or t.endswith(" "):
        return False
    if re.search(r"\d[:\-]?\d*$", t):  # citations ending in verse digits
        return True
    return t.endswith(TERMINATORS)


def main():
    hard = {lang: load_hardcoded(lang) for lang in SWIFT}
    problems = []
    for path in sorted(glob.glob(os.path.join(ROOT, "Shared/content/*/content/*.json"))):
        bundle = path.split(os.sep)[-3]
        lang = os.path.basename(path)[:-5]
        data = json.load(open(path, encoding="utf-8"))
        for contaminant in ("side_ads(", "sc_project", "TOP OF PAGE", "<script", "javascript:"):
            if contaminant.casefold() in json.dumps(data, ensure_ascii=False).casefold():
                problems.append((bundle, lang, "content", f"scraped website contamination: {contaminant}"))
        for key, text in data.get("prayers", {}).items():
            if not isinstance(text, str) or not text.strip():
                problems.append((bundle, lang, key, "empty prayer value"))
                continue
            if (key.endswith(("Title", "Label", "Subtitle"))
                    or re.fullmatch(r"stationOrdinal\d+", key)
                    or key in ("decadeOrdinalNoun", "decadeOrdinalFormat", "repetitionCounterConnector")):
                if text != text.strip():
                    problems.append((bundle, lang, key, "whitespace-padded title"))
                continue
            if not terminal_ok(text) and (bundle, lang, key) not in UNPUNCTUATED_CHANTS:
                problems.append((bundle, lang, key, f"suspicious ending: {text[-40:]!r}"))
            expected = hard.get(lang, {}).get(key)
            if expected is not None and expected != text:
                problems.append((bundle, lang, key, "differs from the hardcoded table"))
        for mkey, m in data.get("mysteries", {}).items():
            desc = m.get("description", "")
            if desc and not terminal_ok(desc):
                problems.append((bundle, lang, f"mysteries.{mkey}", f"suspicious ending: {desc[-40:]!r}"))

    for p in problems:
        print("  ", *p)
    print(f"{len(problems)} problem(s)" if problems else "content audit clean")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

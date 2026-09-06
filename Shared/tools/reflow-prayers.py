#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Break prayer texts onto sense-lines, identically across languages and platforms.

A prayer read from a screen wants the shape it is said in — one clause to a line, the way it
sits on the page of a missal — not a paragraph that rewraps differently on every window width.
The texts themselves are not touched: this tool only inserts newlines.

The three platforms carry byte-identical fixed-prayer string literals (Swift `.key:`, Kotlin
`PrayerKey.Key to`, C# `[PrayerKey.Key] =`, all `"..." + "..."` runs). The Rosary bundle also
overrides a few of those strings from canonical JSON. One pass rewrites both sources from one
description of where the lines fall; generated `.prosaryprayer` archives are rebuilt separately.

    prayer-line-breaks.json:  {"<lang>": {"<prayerKey>": ["marker", ...]}}

Each marker is a substring of the prayer; a line break goes immediately *before* it, consuming
the space that was there. The safety property is the whole point and is enforced, not assumed:
collapsing every newline in the result back to a space must reproduce the original text exactly.
A prayer's wording can never change by running this — only where its lines end.

    usage: reflow-prayers.py [--check]
           --check verifies the files already match (for CI) and writes nothing.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent.parent
BREAKS = TOOLS / "prayer-line-breaks.json"

# Per platform: the file for a language, and how a key's entry opens. {Key} is the PascalCase
# key, {key} the camelCase one.
PLATFORMS = [
    {
        "name": "iOS",
        "path": "iOS/Prosary/Mocks/Content/PrayerTranslations+{Lang}.swift",
        "opener": r"^(?P<indent>[ \t]*)\.{key}:[ \t]*",
        "continuation": "  ",
    },
    {
        "name": "Android",
        "path": "Android/app/src/main/java/com/dkaluta/prosary/content/PrayerTranslations{Lang}.kt",
        "opener": r"^(?P<indent>[ \t]*)PrayerKey\.{Key} to[ \t]*",
        "continuation": "    ",
    },
    {
        "name": "Windows",
        "path": "Windows/Prosary/Localization/PrayerTranslations.{Lang}.cs",
        "opener": r"^(?P<indent>[ \t]*)\[PrayerKey\.{Key}\] =[ \t]*",
        "continuation": "",
    },
]

# Language code -> the name each platform spells into its filename.
LANGUAGE_FILES = {
    "la": "Latin",
    "en": "English",
    "ar": "Arabic",
    "he": "Hebrew",
    "he-x-gamliel": "HebrewGamaliel",
    "ru": "Russian",
    "tl": "Tagalog",
    "el": "Greek",
    "es": "Spanish",
    "arc": "Aramaic",
}

# The Rosary bundle is the canonical source for Aramaic fixed-prayer overrides and repeats a few
# other languages' fixed prayers. Keep those repetitions on the same lines as the native tables.
ROSARY_CONTENT = ROOT / "Shared/content/rosary/content"

# The Mission's Lord's Prayer adds a doxology, so it has one honest extra sense-line.
# Erez's shorter Aramaic Glory Be has two sense-lines: the Trinitarian invocation and the
# complete "from eternity ... forever" response. Do not split that response to force the
# Vicariate Hebrew line count onto a different wording.
LINE_COUNT_EXCEPTIONS = {
    # Smelova's published medieval Melkite text has seven source lines in both scripts.
    ("arc", "subTuumPraesidium"): 7,
    ("arc-Syrc", "subTuumPraesidium"): 7,
    ("he-x-gamliel", "paterNoster"): 9,
    ("arc", "paterNoster"): 9,
    ("arc-Syrc", "paterNoster"): 9,
    ("arc", "gloriaPatri"): 2,
    ("arc-Syrc", "gloriaPatri"): 2,
}

errors: list[str] = []


def err(message: str) -> None:
    errors.append(message)


def pascal(key: str) -> str:
    return key[0].upper() + key[1:]


def scan_literal_run(text: str, start: int) -> tuple[str, int] | None:
    """Read a `"a" + "b" + "c"` run beginning at `start`. Returns (value, end index)."""
    parts: list[str] = []
    i = start
    while True:
        while i < len(text) and text[i] in " \t\r\n":
            i += 1
        if i >= len(text) or text[i] != '"':
            break
        i += 1
        chunk: list[str] = []
        while i < len(text):
            ch = text[i]
            if ch == "\\":
                chunk.append(text[i : i + 2])
                i += 2
                continue
            if ch == '"':
                i += 1
                break
            chunk.append(ch)
            i += 1
        else:
            return None
        parts.append("".join(chunk))
        # Another literal only continues the run if a '+' joins it.
        j = i
        while j < len(text) and text[j] in " \t\r\n":
            j += 1
        if j < len(text) and text[j] == "+":
            i = j + 1
            continue
        break
    if not parts:
        return None
    return "".join(parts), i


def emit(value: str, indent: str, continuation: str) -> str:
    """One source line per prayer line — the shape the prayer is actually said in.

    A multi-line value starts on its own line, which is the convention every one of these files
    already follows for long prayers. Without the leading break the first literal ends up welded
    to the key ("PrayerKey.PaterNoster to\"אָבִינוּ") — legal in C#, ugly in Swift, and asking for
    trouble from Kotlin's infix `to`.
    """
    lines = value.split("\\n")
    body = indent + continuation
    if len(lines) == 1:
        return f'"{lines[0]}"'
    out = [f'\n{body}"{lines[0]}\\n" +']
    for line in lines[1:-1]:
        out.append(f'{body}"{line}\\n" +')
    out.append(f'{body}"{lines[-1]}"')
    return "\n".join(out)


def apply_breaks(value: str, markers: list[str], where: str, newline: str = "\\n") -> str | None:
    """Replace existing line breaks, then insert `newline` before each configured marker."""
    # Reflow means the configured shape wins. Flattening first lets a later correction move or
    # remove an old break while the wording check below still guarantees a whitespace-only edit.
    result = value.replace("\\n", " ").replace("\n", " ")
    for marker in markers:
        count = result.count(marker)
        if count == 0:
            err(f"{where}: marker {marker!r} does not occur")
            return None
        if count > 1:
            err(f"{where}: marker {marker!r} occurs {count} times — make it unique")
            return None
        at = result.index(marker)
        before = result[:at]
        if before.endswith(" "):
            before = before[:-1]
        elif before:
            err(f"{where}: marker {marker!r} is mid-word, not at a line start")
            return None
        result = before + newline + result[at:]
    return result


def unbroken(value: str) -> str:
    """The text with every line break flattened back to a single space."""
    return re.sub(r"\s+", " ", value.replace("\\n", " ")).strip()


def rewrite_json(path: Path, section: str, key: str, markers: list[str], check: bool) -> bool:
    """Reflow one canonical bundle string without changing any non-whitespace character."""
    data = json.loads(path.read_text(encoding="utf-8"))
    values = data.get(section)
    if not isinstance(values, dict) or key not in values:
        return False

    value = values[key]
    if not isinstance(value, str):
        err(f"{path.name}:{section}.{key}: expected a string")
        return False

    where = f"{path.name}:{section}.{key}"
    broken = apply_breaks(value, markers, where, newline="\n")
    if broken is None:
        return False
    if unbroken(broken) != unbroken(value):
        err(f"{where}: reflow changed the wording — refusing")
        return False
    if broken == value:
        return False
    if check:
        err(f"{where}: not reflowed (run reflow-prayers.py)")
        return False

    values[key] = broken
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return True


def json_target(language: str) -> tuple[Path, str] | None:
    if language == "arc-Syrc":
        return ROSARY_CONTENT / "arc.json", "transliterations"
    path = ROSARY_CONTENT / f"{language}.json"
    return (path, "prayers") if path.exists() else None


def has_literal(path: Path, opener: str, key: str) -> bool:
    pattern = re.compile(
        opener.replace("{key}", re.escape(key)).replace("{Key}", re.escape(pascal(key))),
        re.MULTILINE)
    return pattern.search(path.read_text(encoding="utf-8")) is not None


def read_literal(path: Path, opener: str, key: str) -> str | None:
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(
        opener.replace("{key}", re.escape(key)).replace("{Key}", re.escape(pascal(key))),
        re.MULTILINE)
    match = pattern.search(text)
    if not match:
        return None
    run = scan_literal_run(text, match.end())
    return run[0] if run is not None else None


def validate_parity(breaks: dict[str, object]) -> None:
    """Make the existing CI check prove native and canonical copies cannot drift apart."""
    for language, keys in breaks.items():
        if language.startswith("$") or not isinstance(keys, dict):
            continue
        name = LANGUAGE_FILES.get(language)
        if name is None:
            continue

        native: dict[str, dict[str, str]] = {}
        for platform in PLATFORMS:
            path = ROOT / platform["path"].replace("{Lang}", name)
            if not path.exists():
                continue
            for key in keys:
                value = read_literal(path, platform["opener"], key)
                if value is not None:
                    native.setdefault(key, {})[platform["name"]] = value

        for key, values in native.items():
            if len(set(values.values())) > 1:
                err(f"{language}:{key}: native prayer text or line breaks differ by platform")

        target = json_target(language)
        if target is None:
            continue
        path, section = target
        values = json.loads(path.read_text(encoding="utf-8")).get(section, {})
        for key, copies in native.items():
            json_value = values.get(key)
            if not isinstance(json_value, str) or not copies:
                continue
            source_value = next(iter(copies.values()))
            if json_value.replace("\n", "\\n") != source_value:
                err(f"{path.name}:{section}.{key}: differs from the native fixed-prayer text")


def rewrite(path: Path, opener: str, continuation: str, key: str, markers: list[str],
            check: bool) -> bool:
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(
        opener.replace("{key}", re.escape(key)).replace("{Key}", re.escape(pascal(key))),
        re.MULTILINE)
    match = pattern.search(text)
    if not match:
        return False  # this language simply does not carry the key

    run = scan_literal_run(text, match.end())
    if run is None:
        err(f"{path}: could not read {key}'s string literal")
        return False
    value, end = run

    where = f"{path.name}:{key}"
    broken = apply_breaks(value, markers, where)
    if broken is None:
        return False

    if unbroken(broken) != unbroken(value):
        err(f"{where}: reflow changed the wording — refusing")
        return False

    replacement = emit(broken, match.group("indent"), continuation)
    updated = text[: match.end()] + replacement + text[end:]
    if updated == text:
        return False
    if check:
        err(f"{where}: not reflowed (run reflow-prayers.py)")
        return False
    path.write_text(updated, encoding="utf-8")
    return True


def main() -> int:
    check = "--check" in sys.argv[1:]
    breaks = json.loads(BREAKS.read_text(encoding="utf-8"))
    changed = 0

    reference = breaks.get("he")
    if not isinstance(reference, dict):
        err("prayer-line-breaks.json: missing Hebrew reference map")
        reference = {}
    reference_counts = {key: len(markers) + 1 for key, markers in reference.items()}

    for language, keys in breaks.items():
        if language.startswith("$"):
            continue
        name = LANGUAGE_FILES.get(language)
        target = json_target(language)
        if name is None and target is None:
            err(f"unknown language {language!r}")
            continue

        if not isinstance(keys, dict):
            err(f"{language}: expected a prayer map")
            continue

        for key, markers in keys.items():
            expected = LINE_COUNT_EXCEPTIONS.get((language, key), reference_counts.get(key))
            if expected is not None and len(markers) + 1 != expected:
                err(
                    f"{language}:{key}: has {len(markers) + 1} configured lines; "
                    f"expected {expected} from Hebrew"
                )

        if name is not None:
            for platform in PLATFORMS:
                path = ROOT / platform["path"].replace("{Lang}", name)
                if not path.exists():
                    continue
                for key in reference_counts:
                    if has_literal(path, platform["opener"], key) and key not in keys:
                        err(f"{path.name}:{key}: missing from prayer-line-breaks.json")
                for key, markers in keys.items():
                    if rewrite(path, platform["opener"], platform["continuation"], key, markers,
                               check):
                        changed += 1

        if target is not None:
            path, section = target
            data = json.loads(path.read_text(encoding="utf-8"))
            values = data.get(section, {})
            for key in reference_counts:
                if key in values and key not in keys:
                    err(f"{path.name}:{section}.{key}: missing from prayer-line-breaks.json")
            for key, markers in keys.items():
                if rewrite_json(path, section, key, markers, check):
                    changed += 1

    validate_parity(breaks)

    for message in errors:
        print(f"error: {message}", file=sys.stderr)
    if errors:
        return 1
    print(f"{'would reflow' if check else 'reflowed'} {changed} prayer(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

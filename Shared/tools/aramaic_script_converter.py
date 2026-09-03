"""Deterministic Syriac-to-Hebrew-square conversion for Prosary content.

Adapted from the interactive converter Erez supplied on 2026-09-03.  The browser tool can
guess direction, retain plural dots, and apply arbitrary user-entered swaps/removals.  Canonical
content must always rebuild identically, so this module fixes the direction to Syriac -> Hebrew,
defaults plural dots off, rejects mixed Hebrew/Syriac input, and carries only the linguistic
conversion rules:

* the twenty-two corresponding letters, with contextual Hebrew final forms;
* the five Syriac vowel signs Erez maps into Hebrew points;
* qushshaya as dagesh;
* his initial-waw, shuruk, holam, and pre-waw-u handling.

The original Syriac is never produced by this transform or reconstructed from its result.  The
Scripture importer stores that source unchanged beside the Hebrew-square projection.
"""

from __future__ import annotations


# Classical Syriac -> Hebrew square script.  The base alphabets correspond letter-for-letter;
# Hebrew final forms are applied contextually by ``to_hebrew`` rather than encoded here.
SYRIAC_TO_HEBREW = {
    "ܐ": "א",  # alaph      -> alef
    "ܒ": "ב",  # beth       -> bet
    "ܓ": "ג",  # gamal      -> gimel
    "ܕ": "ד",  # dalath     -> dalet
    "ܗ": "ה",  # he         -> he
    "ܘ": "ו",  # waw        -> vav
    "ܙ": "ז",  # zain       -> zayin
    "ܚ": "ח",  # heth       -> het
    "ܛ": "ט",  # teth       -> tet
    "ܝ": "י",  # yudh       -> yod
    "ܟ": "כ",  # kaph       -> kaf
    "ܠ": "ל",  # lamadh     -> lamed
    "ܡ": "מ",  # mim        -> mem
    "ܢ": "נ",  # nun        -> nun
    "ܣ": "ס",  # semkath    -> samekh
    "ܥ": "ע",  # e          -> ayin
    "ܦ": "פ",  # pe         -> pe
    "ܨ": "צ",  # sadhe      -> tsadi
    "ܩ": "ק",  # qaph       -> qof
    "ܪ": "ר",  # rish       -> resh
    "ܫ": "ש",  # shin       -> shin
    "ܬ": "ת",  # taw        -> tav
}

SYRIAC_TO_HEBREW_VOWELS = {
    "ܰ": "ַ",
    "ܳ": "ָ",
    "ܶ": "ֶ",
    "ܺ": "ִ",
    "ܽ": "ֻ",
    "݁": "ּ",  # qushshaya -> dagesh
}

# A final form is selected when no later Syriac letter remains in the same word token.
SYRIAC_FINALS = {
    "ܟ": "ך",
    "ܡ": "ם",
    "ܢ": "ן",
    "ܦ": "ף",
    "ܨ": "ץ",
}

# These are the marks Erez's converter removes before conversion.  U+0308 (seyame as a generic
# combining diaeresis in the ETCBC text) may be retained explicitly for the interactive use case,
# but canonical generation always leaves ``keep_plural_dots`` false.
EREZ_CHARS_TO_REMOVE = frozenset(
    "ܱܴܷܸܹܻܼܾ݂݄݆݈ܲܵܿ݀݃݅݇݉݊"
    "̠̣̤̥̭̮̰̱̃̄̇̈̊"
    "ًٌٍَُِّْٰٕٖٜٟ۪ۭٓٔٗ٘ٙٚٛٝٞۖۗۘۙۚۛۜ۟۠ۡۢۤۧۨ۫۬"
    "᷺᷸°"
)
HEBREW_MARKS_ALWAYS_REMOVE = frozenset("ֽׁׂ")
HEBREW_VOWELS = frozenset("ְֱֲֳִֵֶַָֹֺֻ")

# Used only to prove that contextual final forms do not change the underlying letter sequence.
HEBREW_TO_SYRIAC_LETTERS = {value: key for key, value in SYRIAC_TO_HEBREW.items()}
HEBREW_TO_SYRIAC_LETTERS.update({value: key for key, value in SYRIAC_FINALS.items()})


def _is_hebrew_letter(ch: str | None) -> bool:
    return ch is not None and ("א" <= ch <= "ת" or ch in "ךםןףץ")


def _is_syriac_letter(ch: str | None) -> bool:
    # Mirrors Erez's JavaScript /[ܐ-ܬ]/u predicate, including the intervening Syriac letters.
    return ch is not None and "ܐ" <= ch <= "ܬ"


def _is_syriac_combining_mark(ch: str | None) -> bool:
    return ch is not None and "ܰ" <= ch <= "݊"


def _is_hebrew_vowel(ch: str | None) -> bool:
    return ch in HEBREW_VOWELS if ch is not None else False


def _is_syriac_vowel(ch: str | None) -> bool:
    return ch in SYRIAC_TO_HEBREW_VOWELS if ch is not None else False


def _is_word_char(ch: str | None) -> bool:
    if ch is None:
        return False
    codepoint = ord(ch)
    return (
        _is_hebrew_letter(ch)
        or _is_syriac_letter(ch)
        or _is_hebrew_vowel(ch)
        or _is_syriac_vowel(ch)
        or 0x0300 <= codepoint <= 0x036F
        or 0x0591 <= codepoint <= 0x05C7
        # Erez's browser tokenizes the whole Syriac block. Keep its abbreviation mark, letters,
        # and combining marks together, but let U+0700-U+070D punctuation end a word so Hebrew
        # final forms are selected on either side of it.
        or 0x070F <= codepoint <= 0x074F
    )


def _filtered_chars(text: str, *, keep_plural_dots: bool) -> list[str]:
    filtered: list[str] = []
    for ch in text:
        if ch == "̈":
            if keep_plural_dots:
                filtered.append(ch)
            continue
        if ch in HEBREW_MARKS_ALWAYS_REMOVE or ch in EREZ_CHARS_TO_REMOVE:
            continue
        filtered.append(ch)
    return filtered


def _previous_syriac_letter(token: list[str], start: int) -> int | None:
    for index in range(start, -1, -1):
        if _is_syriac_letter(token[index]):
            return index
    return None


def _convert_syriac_token(token: list[str]) -> list[str]:
    converted: list[str] = []

    for index, ch in enumerate(token):
        previous = token[index - 1] if index else None
        following = token[index + 1] if index + 1 < len(token) else None

        # Erez's special u around waw: ܒ݁ܽܘ -> בּוּ, not בֻּו.  A following Syriac
        # combining mark guards the rewrite because it belongs to the waw itself.
        if ch == "ܽ" and following == "ܘ":
            previous_letter = _previous_syriac_letter(token, index - 1)
            after_waw = token[index + 2] if index + 2 < len(token) else None
            if previous_letter is not None and not _is_syriac_combining_mark(after_waw):
                converted.append("")
                continue

        if ch == "ܘ" and previous == "ܽ":
            previous_letter = _previous_syriac_letter(token, index - 2)
            if previous_letter is not None and not _is_syriac_combining_mark(following):
                converted.append("וּ")
                continue

        if ch == "݁":
            converted.append("ּ")
            continue

        # Initial ܘܶ is Hebrew וְ rather than וֶ.
        if index == 0 and ch == "ܘ" and following == "ܶ":
            converted.append("ו")
            continue
        if index == 1 and ch == "ܶ" and token[0] == "ܘ":
            converted.append("ְ")
            continue

        # Vowel signs attached directly to waw become shuruk or holam.
        if ch == "ܘ" and following == "ܽ":
            converted.append("ו")
            continue
        if ch == "ܽ" and previous == "ܘ":
            converted.append("ּ")
            continue
        if ch == "ܘ" and following == "ܳ":
            converted.append("ו")
            continue
        if ch == "ܳ" and previous == "ܘ":
            converted.append("ֹ")
            continue

        if ch in SYRIAC_FINALS:
            next_letter: str | None = None
            lookahead = index + 1
            while lookahead < len(token):
                candidate = token[lookahead]
                if _is_hebrew_letter(candidate) or _is_syriac_letter(candidate):
                    next_letter = candidate
                    break
                lookahead += 1
            if not _is_syriac_letter(next_letter):
                converted.append(SYRIAC_FINALS[ch])
                continue

        if ch in SYRIAC_TO_HEBREW_VOWELS:
            converted.append(SYRIAC_TO_HEBREW_VOWELS[ch])
            continue
        if _is_hebrew_vowel(ch):
            # A Hebrew point already belongs to the target script; Erez leaves it in place.
            converted.append(ch)
            continue
        if ch in SYRIAC_TO_HEBREW:
            converted.append(SYRIAC_TO_HEBREW[ch])
            continue
        if _is_hebrew_letter(ch):
            converted.append(ch)
            continue
        converted.append(ch)

    return converted


def to_hebrew(syriac: str, *, keep_plural_dots: bool = False) -> str:
    """Convert Syriac text to Hebrew-square Aramaic using Erez's deterministic rules.

    Direction detection, arbitrary swaps/removals, and DOM behavior from the interactive tool are
    intentionally absent. They are useful while editing, but would make generated content depend
    on mutable UI state. Input is deliberately limited to Syriac-source text: mixing in Hebrew
    letters or points is rejected instead of invoking the browser tool's reverse-direction rules
    and risking a hybrid generated passage.
    """

    filtered = _filtered_chars(syriac, keep_plural_dots=keep_plural_dots)
    if any(0x0590 <= ord(ch) <= 0x05FF for ch in filtered):
        raise ValueError("to_hebrew accepts Syriac-source text, not mixed Hebrew/Syriac input")
    output: list[str] = []
    index = 0

    while index < len(filtered):
        if not _is_word_char(filtered[index]):
            output.append(filtered[index])
            index += 1
            continue

        end = index
        while end < len(filtered) and _is_word_char(filtered[end]):
            end += 1
        output.extend(_convert_syriac_token(filtered[index:end]))
        index = end

    return "".join(output)


def to_syriac_letters(hebrew: str) -> str:
    """Reverse Hebrew base/final letters for losslessness checks; points stay untouched."""

    return "".join(HEBREW_TO_SYRIAC_LETTERS.get(ch, ch) for ch in hebrew)

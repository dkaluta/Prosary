#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Validates a devotion bundle source directory (Shared/content/<id>/) before packing.

Called by make-prosaryprayer.sh (and Make-ProsaryPrayer.ps1 when python3 is available).
Checks, beyond plain JSON validity (which the packer already enforces):

- devotion.json (when present) matches the v2 schema for its "type" ("steps" | "rosary" |
  "days" | "hours");
- hours-type structural rules: unique hour ids, every slot a hour's skeleton asks for is filled
  by some proper (or carries its own "default") so no slot can silently vanish, every proper
  names a slot some hour actually asks for, each "when" constrains only known calendar facets
  with valid values, and no two propers for one slot share a selector;
- every bodyKey/titleKey referenced by devotion.json resolves in every manifest language —
  either in the bundle's own content/<lang>.json "prayers" map, or in the surviving hardcoded
  PrayerKey pool (the keys every platform still ships in code after the generic-devotion
  migration), minus an optional per-bundle gap allowlist (validation-allowlist.json);
- manifest.id is one portable filename component (`[A-Za-z0-9][A-Za-z0-9._-]*`), because every
  native installer uses it as the persisted pack filename;
- every referenced imageKey exists as Shared/Images/<key>.jpg;
- rosary-type structural invariants the bead track depends on: opening[0] is the Sign of the
  Cross, decade "entries" XOR "count"+"fixedImageKey", at most one seasonalMarianAntiphon
  closing entry, and (when hasClosingCross) the final closing entry is a non-repeated Sign of
  the Cross — BeadLayout assumes the closing cross is the literal last step;
- announceMystery entries' mystery texts exist per language (bundle "mysteries" map, or the
  Rosary's shared mystery pool for reused imageKeys);
- audio.json (when present) declares valid narrated recordings: unique track ids, a manifest
  language and (when named) a declared variant per track, an existing audio/<name>.opus file
  with the Ogg Opus signature (RFC 7845), and well-formed chapters (first start 0, strictly
  increasing, title XOR titleKey with titleKey resolving in the track's language) — see
  ARCHITECTURE.markdown's "Audio".

Usage: validate-devotion.py <bundle-source-dir>
Exit code 0 = valid; non-zero with messages on stderr otherwise.
"""

import json
import re
import sys
from pathlib import Path

# PrayerKeys that remain hardcoded in every platform's PrayerTranslations after the
# generic-devotion migration (main prayers, Rosary-specific keys, Marian antiphons, Jesus
# Prayer). A bundle may reference these without shipping its own translation.
HARDCODED_PRAYER_KEYS = {
    "signumCrucis", "signumCrucisFormB", "symbolumApostolorum", "paterNoster", "aveMaria", "gloriaPatri",
    "doxologiaMinor", "oratioFatimae", "requiemAeternam", "sanctusMichael",
    "salveRegina", "almaRedemptorisMater", "aveReginaCaelorum", "reginaCaeli",
    "subTuumPraesidium",
    "versiculumStandard", "responsiumStandard", "collectaStandard",
    "versiculumPaschale", "responsiumPaschale", "collectaPaschale",
    "aveMariaProFide", "aveMariaProSpe", "aveMariaProCaritate",
    "fructusMysteriiLabel", "oratioIesu", "animaChristi",
}

# The 20 Rosary mystery imageKeys whose MysteryText ships hardcoded (and via the rosary
# bundle) on every platform — a decade entry may reuse these without shipping its own text.
SHARED_MYSTERY_IMAGE_KEYS = {
    f"{group}_{order:02d}_{name}"
    for group, names in {
        "joyful": ["annunciation", "visitation", "nativity", "presentation", "finding_in_the_temple"],
        "sorrowful": ["agony_in_the_garden", "scourging_at_the_pillar", "crowning_with_thorns",
                      "carrying_of_the_cross", "crucifixion"],
        "glorious": ["resurrection", "ascension", "descent_of_the_holy_spirit", "assumption", "coronation"],
        "luminous": ["baptism", "wedding_at_cana", "proclamation_of_the_kingdom", "transfiguration",
                     "institution_of_the_eucharist"],
    }.items()
    for order, name in enumerate(names, start=1)
}

# Seeded by every engine beside a bundle's declared options, so an entry can gate on the season
# ("invitatory & !isLent") without the bundle inventing an option for it.
CALENDAR_CONDITION_KEYS = {"isLent", "isEasterSeason"}

SIGN_OF_CROSS_KEY = "signumCrucis"
ANTIPHON_KIND = "seasonalMarianAntiphon"
OPTION_ANTIPHON_KIND = "marianAntiphon"
SLOT_KIND = "proper"
BUNDLE_ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")

# --- hours-type vocabulary -------------------------------------------------------------------
# The facets a proper may constrain. Each is a closed set the runtime calendar must be able to
# answer for a given date; the format pins the spelling so a bundle and an engine cannot drift.

# Mirrors LiturgicalSeason on every platform ("other" is Ordinary Time, named plainly here).
SEASONS = {"advent", "christmas", "lent", "easterSeason", "ordinary"}

WEEKDAYS = {"sun", "mon", "tue", "wed", "thu", "fri", "sat"}

# The ranks Shared/data/feasts.json already records per day, camelCased to the app convention.
# A day with no feasts.json entry is "ferial".
RANKS = {"solemnity", "feast", "memorial", "optionalMemorial", "sunday", "ferial"}

# Which proper wins when several match today. Compared as a tuple over these facets in this
# order — a proper that constrains an earlier facet beats one that does not, regardless of how
# many facets either constrains. This is the Church's own hierarchy, not a count of conditions:
# the proper of a saint's day (date) outranks a solemnity's (rank), which outranks the proper of
# the season (season/week/weekday), which outranks the running psalter (psalterWeek/weekday).
# Counting conditions instead would let "Advent, week 3, Sunday" (three facets) beat Christmas
# Day (one), which is exactly backwards. Ties go to the earlier declaration.
PROPER_FACET_PRECEDENCE = ["date", "rank", "season", "week", "weekday", "psalterWeek",
                           "readingYear"]

# facet -> validator for one of its values.
PROPER_FACETS = {
    "date": lambda v: isinstance(v, str) and _is_month_day(v),
    "rank": lambda v: v in RANKS,
    "season": lambda v: v in SEASONS,
    "week": lambda v: isinstance(v, int) and not isinstance(v, bool) and v >= 1,
    "weekday": lambda v: v in WEEKDAYS,
    "psalterWeek": lambda v: isinstance(v, int) and not isinstance(v, bool) and 1 <= v <= 4,
    "readingYear": lambda v: v in (1, 2),
}


def _is_month_day(value: str) -> bool:
    parts = value.split("-")
    return (len(parts) == 2 and all(p.isdigit() and len(p) == 2 for p in parts)
            and 1 <= int(parts[0]) <= 12 and 1 <= int(parts[1]) <= 31)


def unknown_fields(obj: dict, allowed: set) -> list:
    """Fields that are neither allowed nor an author's note. Any key starting with '$' is a
    note — the same convention Shared/schema uses — so a bundle can say why a proper exists
    without the format having to grow a field for prose."""
    return sorted(k for k in obj if k not in allowed and not k.startswith("$"))


def _is_hour_minute(value) -> bool:
    return (isinstance(value, str) and len(value) == 5 and value[2] == ":"
            and value[:2].isdigit() and value[3:].isdigit()
            and int(value[:2]) < 24 and int(value[3:]) < 60)

errors: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def load_json(path: Path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


MYSTERY_OVERRIDE_FIELDS = {"title", "fruit", "description", "transliteratedDescription"}


def validate_prayer_traditions(path: Path, content: dict) -> None:
    """Keep plain repository Hebrew generic; explicitly mark sourced Vicariate prayer keys."""
    traditions = content.get("$prayerTraditionByKey", {})
    label = f"content/{path.name}: $prayerTraditionByKey"
    if not isinstance(traditions, dict):
        err(f"{label} must be a map of prayer key to tradition")
        return
    if traditions and path.stem != "he":
        err(f"{label} is only supported in content/he.json")
    for key, tradition in traditions.items():
        if key not in content.get("prayers", {}):
            err(f"{label}: {key!r} must name this file's own prayer key")
        if tradition != "vicariate":
            err(f"{label}: {key!r} has unsupported tradition {tradition!r}; expected 'vicariate'")


def validate_mystery_overrides(path: Path, content: dict) -> None:
    """Mystery language entries may override any subset of the presentation fields.

    This is intentionally field-wise: a rite can provide its own Scripture body and source-native
    citation without having to invent a translated mystery title or fruit. The Syriac-script
    companion is provenance-coupled to that same description, so it may not float by itself.
    """
    mysteries = content.get("mysteries", {})
    label = f"content/{path.name}"
    if not isinstance(mysteries, dict):
        err(f"{label}: 'mysteries' must be a map of image key to field overrides")
        return
    for key, value in mysteries.items():
        where = f"{label}: mysteries[{key!r}]"
        if not isinstance(key, str) or not key:
            err(f"{label}: mystery image keys must be non-empty strings")
            continue
        if not isinstance(value, dict):
            err(f"{where} must be an object")
            continue
        extra = unknown_fields(value, MYSTERY_OVERRIDE_FIELDS)
        if extra:
            err(f"{where}: unknown fields {extra}")
        authored = [field for field in ("title", "fruit", "description") if field in value]
        if not authored:
            err(f"{where}: must override title, fruit, or description")
        for field in MYSTERY_OVERRIDE_FIELDS:
            if field in value and not isinstance(value[field], str):
                err(f"{where}: {field} must be a string")
        if "transliteratedDescription" in value and "description" not in value:
            err(f"{where}: transliteratedDescription requires description in the same override")


def _all_strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for nested in value.values():
            yield from _all_strings(nested)
    elif isinstance(value, list):
        for nested in value:
            yield from _all_strings(nested)


def validate_citation_style(path: Path, content: dict) -> None:
    """Keep citation punctuation semantic and uniform without touching dates or identifiers."""
    label = f"content/{path.name}"
    for text in _all_strings(content):
        for citation in re.findall(r"(?:^|\n)— ([^\n]+)", text):
            if re.search(r"\d-\d", citation):
                err(f"{label}: citation ranges must use an en dash, not a hyphen: {citation!r}")
            if (re.search(r"[\u0590-\u05ff]", citation)
                    and re.search(r"\d+:\d+", citation)):
                err(f"{label}: Hebrew-script citations use a gematria chapter and no colon: "
                    f"{citation!r}")


# (where, expr) for every entry-level "if" — checked against options.json declarations after
# all entry lists are walked.
if_refs: list = []


# (where, optionKey) for every marianAntiphon entry — checked against options.json after all
# entry lists are walked (the named option must be a choice).
antiphon_option_refs: list = []


# The liturgical families in canonical order — the order the Church's own taxonomies use, and
# the order a bundle must declare tradition-named variants in. Because the first declared
# variant is the default, this ordering IS the default rule: everyone without a rite claim gets
# the Latin form when the bundle ships one (the Vicariate's Hebrew among them), else the
# Byzantine, and so on down. defaultForLanguages then overrides per rite (the Mission opening
# the Trisagion in its Syriac form). Ids that name no tradition (traditional, scriptural,
# shorter…) stay ordered however the author likes.
TRADITION_RANK = {
    "latin": 0, "roman": 0,
    "byzantine": 1, "greek": 1,
    "westSyriac": 2, "syriac": 2, "antiochene": 2, "maronite": 2,
    "armenian": 3,
    "alexandrian": 4, "coptic": 4, "geez": 4, "ethiopian": 4,
    "eastSyriac": 5, "chaldean": 5, "assyrian": 5,
}


def check_variant_defaults(variants: list) -> None:
    """Cross-variant rules: no two variants may claim the same default language (the winner
    would silently be declaration order), and tradition-named variants must be declared in the
    canonical order TRADITION_RANK encodes."""
    claimed: set = set()
    for v, variant in enumerate(variants):
        if not isinstance(variant, dict):
            continue
        for lang in variant.get("defaultForLanguages") or []:
            if lang in claimed:
                err(f"variants[{v}]: {lang!r} is already another variant's default language")
            claimed.add(lang)
    ranked = [(v, TRADITION_RANK[variant["id"]])
              for v, variant in enumerate(variants)
              if isinstance(variant, dict) and variant.get("id") in TRADITION_RANK]
    for (_, earlier), (v, later) in zip(ranked, ranked[1:]):
        if later < earlier:
            err(f"variants[{v}]: tradition-named variants must follow the canonical order "
                "latin, byzantine, west syriac, armenian, alexandrian, east syriac — the first "
                "declared variant is the default, and the default belongs to the earliest "
                "tradition the bundle ships")


def check_default_for_languages(variant: dict, where: str) -> None:
    """A variant may declare the prayer languages (exact codes, rites included) whose sessions
    open in it when the favorite has no explicit choice — the Mission's rite opening the
    Trisagion in its Syriac form. Exact codes only: a rite is a deliberate choice, and its base
    language keeps the bundle's ordinary default."""
    langs = variant.get("defaultForLanguages")
    if langs is None:
        return
    if not isinstance(langs, list) or not langs or not all(isinstance(x, str) and x for x in langs):
        err(f"{where}: defaultForLanguages must be a non-empty array of language codes")


def validate_entry(entry: dict, where: str, allow_kind: bool, slots: set | None = None) -> None:
    if "if" in entry:
        if not isinstance(entry["if"], str) or not entry["if"]:
            err(f"{where}: 'if' must be a non-empty string")
        else:
            if_refs.append((where, entry["if"]))
    # hours type: a placeholder for whatever the calendar says belongs here today. It is the one
    # entry that is not itself a step — the propers table fills it, or its own `default` does.
    if slots is not None and entry.get("kind") == SLOT_KIND:
        slot = entry.get("slot")
        if not slot or not isinstance(slot, str):
            err(f"{where}: a {SLOT_KIND} entry needs a slot name")
        else:
            slots.add(slot)
        for i, fallback in enumerate(entry.get("default") or []):
            validate_entry(fallback, f"{where}.default[{i}]", allow_kind=False)
        extra = set(entry) - {"kind", "slot", "default", "if"}
        if extra:
            err(f"{where}: a {SLOT_KIND} entry must have no other fields (has {sorted(extra)})")
        return
    if allow_kind and entry.get("kind") == ANTIPHON_KIND:
        extra = set(entry) - {"kind", "if"}
        if extra:
            err(f"{where}: a {ANTIPHON_KIND} entry must have no other fields (has {sorted(extra)})")
        return
    if allow_kind and entry.get("kind") == OPTION_ANTIPHON_KIND:
        extra = set(entry) - {"kind", "optionKey", "if"}
        if extra:
            err(f"{where}: a {OPTION_ANTIPHON_KIND} entry must have no other fields (has {sorted(extra)})")
        if not entry.get("optionKey") or not isinstance(entry.get("optionKey"), str):
            err(f"{where}: a {OPTION_ANTIPHON_KIND} entry needs an optionKey")
        else:
            antiphon_option_refs.append((where, entry["optionKey"]))
        return
    if "kind" in entry:
        err(f"{where}: unknown entry kind {entry['kind']!r}")
        return
    if not entry.get("bodyKey"):
        err(f"{where}: missing bodyKey")
    if not entry.get("imageKey"):
        err(f"{where}: missing imageKey")
    if not entry.get("title") and not entry.get("titleKey"):
        err(f"{where}: needs a literal title or a titleKey")
    if entry.get("title") and entry.get("titleKey"):
        err(f"{where}: title and titleKey are mutually exclusive")
    if entry.get("subtitle") and entry.get("subtitleKey"):
        err(f"{where}: subtitle and subtitleKey are mutually exclusive")
    if "repeat" in entry and (not isinstance(entry["repeat"], int) or entry["repeat"] < 2):
        err(f"{where}: repeat must be an integer >= 2")
    counter_index = entry.get("counterIndex")
    counter_total = entry.get("counterTotal")
    if (counter_index is None) != (counter_total is None):
        err(f"{where}: counterIndex and counterTotal must be supplied together")
    elif counter_index is not None:
        if (isinstance(counter_index, bool) or not isinstance(counter_index, int)
                or isinstance(counter_total, bool) or not isinstance(counter_total, int)
                or counter_index < 1 or counter_total < 1 or counter_index > counter_total):
            err(f"{where}: counterIndex/counterTotal must be positive integers with index <= total")
        if "repeat" in entry:
            err(f"{where}: counterIndex/counterTotal cannot be combined with repeat")
    if "isScripture" in entry and not isinstance(entry["isScripture"], bool):
        err(f"{where}: isScripture must be a boolean")
    if "isScriptureByLanguage" in entry:
        value = entry["isScriptureByLanguage"]
        if not isinstance(value, dict) or not value or not all(isinstance(v, bool) for v in value.values()):
            err(f"{where}: isScriptureByLanguage must be a non-empty map of language -> boolean")


def validate_audio(src: Path, languages: list, variant_ids: set) -> None:
    """audio.json (when present): narrated Ogg Opus recordings + chapter seek points — see
    ARCHITECTURE.markdown's "Audio". Runs for override-only bundles too (audio needs no
    devotion.json), with an empty variant-id set there so any variantId reference errors."""
    audio_path = src / "audio.json"
    if not audio_path.exists():
        return
    doc = load_json(audio_path)
    extra = set(doc) - {"tracks"}
    if extra:
        err(f"audio.json: unknown fields {sorted(extra)}")
    tracks = doc.get("tracks")
    if not isinstance(tracks, list) or not tracks:
        err("audio.json: 'tracks' must be a non-empty array")
        return

    allowlist_path = src / "validation-allowlist.json"
    allowlist = load_json(allowlist_path).get("missingKeys", {}) if allowlist_path.exists() else {}

    seen_ids: set = set()
    for i, track in enumerate(tracks):
        where = f"audio.tracks[{i}]"
        track_id = track.get("id")
        if not track_id or not isinstance(track_id, str):
            err(f"{where}: missing id")
        elif track_id in seen_ids:
            err(f"{where}: duplicate id {track_id!r}")
        else:
            seen_ids.add(track_id)
        lang = track.get("language")
        if lang not in languages:
            err(f"{where}: language {lang!r} is not one of the manifest's languages")
        file = track.get("file")
        if not isinstance(file, str) or not file.startswith("audio/") or not file.endswith(".opus"):
            err(f"{where}: file must be a bundle-relative audio/<name>.opus path")
        elif not (src / file).exists():
            err(f"{where}: {file} is missing")
        else:
            with open(src / file, "rb") as f:
                header = f.read(36)
            # An Ogg page starts "OggS"; the first page's payload of an Opus stream is the
            # "OpusHead" identification header at a fixed offset 28 (RFC 7845 §5.1).
            if header[:4] != b"OggS" or header[28:36] != b"OpusHead":
                err(f"{where}: {file} is not an Ogg Opus file (RFC 7845)")
        variant_id = track.get("variantId")
        if variant_id is not None and variant_id not in variant_ids:
            err(f"{where}: variantId {variant_id!r} is not a declared variant")
        extra = set(track) - {"id", "language", "file", "variantId", "name", "nameByLanguage", "chapters"}
        if extra:
            err(f"{where}: unknown fields {sorted(extra)}")

        chapters = track.get("chapters")
        if not isinstance(chapters, list) or not chapters:
            err(f"{where}: 'chapters' must be a non-empty array")
            continue
        lang_file = src / "content" / f"{lang}.json" if isinstance(lang, str) else None
        prayers = load_json(lang_file).get("prayers", {}) if lang_file and lang_file.exists() else {}
        allowed_missing = set(allowlist.get(lang, [])) if isinstance(lang, str) else set()
        previous_start = None
        for j, chapter in enumerate(chapters):
            cwhere = f"{where}.chapters[{j}]"
            start = chapter.get("start")
            if not isinstance(start, (int, float)) or isinstance(start, bool) or start < 0:
                err(f"{cwhere}: start must be a number >= 0")
            else:
                if j == 0 and start != 0:
                    err(f"{cwhere}: the first chapter must start at 0")
                if previous_start is not None and start <= previous_start:
                    err(f"{cwhere}: starts must be strictly increasing")
                previous_start = start
            if not chapter.get("title") and not chapter.get("titleKey"):
                err(f"{cwhere}: needs a literal title or a titleKey")
            if chapter.get("title") and chapter.get("titleKey"):
                err(f"{cwhere}: title and titleKey are mutually exclusive")
            title_key = chapter.get("titleKey")
            if title_key and title_key not in prayers and title_key not in HARDCODED_PRAYER_KEYS \
                    and title_key not in allowed_missing:
                err(f"{cwhere}: unresolved titleKey {title_key!r} in content/{lang}.json")
            if "stepIndex" in chapter and (not isinstance(chapter["stepIndex"], int)
                                           or isinstance(chapter["stepIndex"], bool)
                                           or chapter["stepIndex"] < 0):
                err(f"{cwhere}: stepIndex must be an integer >= 0")
            extra = set(chapter) - {"start", "title", "titleKey", "stepIndex"}
            if extra:
                err(f"{cwhere}: unknown fields {sorted(extra)}")


def collect_entry_refs(entry: dict, body_keys: set, title_keys: set, image_keys: set) -> None:
    if entry.get("kind"):
        # A slot's own fallback steps are ordinary entries and must resolve like any other.
        for fallback in entry.get("default") or []:
            collect_entry_refs(fallback, body_keys, title_keys, image_keys)
        return
    if entry.get("bodyKey"):
        body_keys.add(entry["bodyKey"])
    if entry.get("acclamationKey"):
        body_keys.add(entry["acclamationKey"])
    if entry.get("titleKey"):
        title_keys.add(entry["titleKey"])
    if entry.get("subtitleKey"):
        title_keys.add(entry["subtitleKey"])
    if entry.get("imageKey"):
        image_keys.add(entry["imageKey"])


def validate_rosary_form(opening, decades, closing, has_closing_cross, prefix,
                         body_keys, title_keys, image_keys, mystery_keys):
    """The bead-track invariants and decade rules for one rosary-type form.

    Factored out when variants grew to cover the rosary type: a devotion offering several
    forms must satisfy these once per form, not once per bundle — otherwise a second form
    could ship without an opening cross and crash the bead track that assumes one.
    """

    if not opening:
        err(prefix + "rosary-type devotion needs an opening")
    elif opening[0].get("bodyKey") != SIGN_OF_CROSS_KEY:
        err(prefix + "opening[0] must be the Sign of the Cross (bead track assumes step 0 is the opening cross)")
    for i, entry in enumerate(opening):
        validate_entry(entry, f"{prefix}opening[{i}]", allow_kind=False)
        collect_entry_refs(entry, body_keys, title_keys, image_keys)

    antiphons = 0
    for i, entry in enumerate(closing):
        validate_entry(entry, f"{prefix}closing[{i}]", allow_kind=True)
        if entry.get("kind") in (ANTIPHON_KIND, OPTION_ANTIPHON_KIND):
            antiphons += 1
        collect_entry_refs(entry, body_keys, title_keys, image_keys)
    if antiphons > 1:
        err(prefix + "at most one antiphon-kind closing entry is allowed (single 'M' bead)")
    if has_closing_cross:
        last = closing[-1] if closing else {}
        if last.get("bodyKey") != SIGN_OF_CROSS_KEY or "repeat" in last:
            err(prefix + "hasClosingCross: the final closing entry must be a non-repeated Sign of the "
                "Cross (BeadLayout assumes the closing cross is the literal last step)")

    entries = decades.get("entries")
    count = decades.get("count")
    fixed_image = decades.get("fixedImageKey")
    source = decades.get("source")
    if source is not None and source != "mysteryGroups":
        err(f"{prefix}decades: unknown source {source!r}")
    if source is not None:
        # Engine-cataloged decades (the Rosary): the decade list comes from the
        # mystery-group machinery, so a bundle catalog would be dead data.
        if entries is not None or count is not None or fixed_image:
            err(prefix + "decades: 'source' is mutually exclusive with 'entries'/'count'/'fixedImageKey'")
    elif (entries is None) == (count is None):
        err(prefix + "decades: exactly one of 'entries' or 'count' is required (or a 'source')")
    if count is not None and not fixed_image:
        err(prefix + "decades: 'count' requires 'fixedImageKey'")
    if entries is not None and fixed_image:
        err(prefix + "decades: 'entries' and 'fixedImageKey' are mutually exclusive")
    # The noun a decade is counted in ("Mystery"/"Joy"/…) — a literal, or a key so it
    # reads in the language being prayed.
    if not (decades.get("ordinalNoun") or decades.get("ordinalNounKey")):
        err(prefix + "decades: ordinalNoun (or ordinalNounKey) is required")
    if decades.get("ordinalNoun") and decades.get("ordinalNounKey"):
        err(prefix + "decades: ordinalNoun and ordinalNounKey are mutually exclusive")
    if decades.get("ordinalNounKey"):
        title_keys.add(decades["ordinalNounKey"])
    if decades.get("announceMystery") and entries is None and source is None:
        err(prefix + "decades: announceMystery requires 'entries' (or an engine 'source')")
    if not isinstance(decades.get("minorCount"), int) or decades.get("minorCount", 0) < 1:
        err(prefix + "decades: minorCount must be an integer >= 1")
    for role in ("majorStep", "minorStep"):
        step = decades.get(role) or {}
        # A literal title or a titleKey, same as every other entry — the decade steps
        # carry titleKeys so "Our Father"/"Hail Mary" read in the prayer's own language.
        if not (step.get("title") or step.get("titleKey")) or not step.get("bodyKey"):
            err(f"{prefix}decades.{role}: needs a title (or titleKey) and bodyKey")
        else:
            body_keys.add(step["bodyKey"])
        if step.get("title") and step.get("titleKey"):
            err(f"{prefix}decades.{role}: title and titleKey are mutually exclusive")
        if step.get("titleKey"):
            title_keys.add(step["titleKey"])
        if step.get("imageKey"):
            image_keys.add(step["imageKey"])
    for i, entry in enumerate(entries or []):
        if not entry.get("imageKey"):
            err(f"{prefix}decades.entries[{i}]: missing imageKey")
        else:
            image_keys.add(entry["imageKey"])
            if decades.get("announceMystery"):
                mystery_keys.add(entry["imageKey"])
    if fixed_image:
        image_keys.add(fixed_image)
    # Said before each decade's announcement, not after its beads — the Servite chaplet asks
    # Our Lady to recall her Son's sorrows before naming each one. postMinor could not express
    # it: the invocation precedes the first sorrow, and postMinor fires after a decade.
    for i, entry in enumerate(decades.get("preAnnouncement") or []):
        validate_entry(entry, f"{prefix}decades.preAnnouncement[{i}]", allow_kind=False)
        collect_entry_refs(entry, body_keys, title_keys, image_keys)
    for i, entry in enumerate(decades.get("postMinor") or []):
        validate_entry(entry, f"decades.postMinor[{i}]", allow_kind=False)
        collect_entry_refs(entry, body_keys, title_keys, image_keys)
    presenter = decades.get("presenter")
    if presenter is not None:
        if not (presenter.get("combinedTitle") or presenter.get("combinedTitleKey")):
            err("decades.presenter: needs a combinedTitle (or combinedTitleKey)")
        if presenter.get("combinedTitleKey"):
            title_keys.add(presenter["combinedTitleKey"])
        if not presenter.get("bodyKeys"):
            err("decades.presenter: needs a non-empty bodyKeys list")
        for key in presenter.get("bodyKeys") or []:
            body_keys.add(key)


def main() -> int:
    src = Path(sys.argv[1]).resolve()
    shared_images = Path(__file__).resolve().parent.parent / "Images"

    manifest = load_json(src / "manifest.json")
    bundle_id = manifest.get("id")
    if not isinstance(bundle_id, str) or BUNDLE_ID_PATTERN.fullmatch(bundle_id) is None:
        err("manifest.id: must match [A-Za-z0-9][A-Za-z0-9._-]*")
    languages = manifest.get("languages", [])
    devotion_path = src / "devotion.json"

    # Manifest images must exist regardless of devotion.json.
    for key in manifest.get("images", []):
        if not (shared_images / f"{key}.jpg").exists():
            err(f"manifest.images: {key} has no Shared/Images/{key}.jpg")

    if not devotion_path.exists():
        # Override-only bundle (rosary/angelus pre-migration shape) — audio may still ship.
        validate_audio(src, languages, set())
        return report()

    devotion = load_json(devotion_path)
    dtype = devotion.get("type")

    # --- options.json: user-configurable toggles/choices whose keys entry-level "if"s gate on ---
    declared_options: dict = {}
    options_path = src / "options.json"
    if options_path.exists():
        option_list = load_json(options_path).get("options")
        if not isinstance(option_list, list) or not option_list:
            err("options.json: 'options' must be a non-empty array")
            option_list = []
        for i, option in enumerate(option_list):
            where = f"options[{i}]"
            key = option.get("key")
            if not key or not isinstance(key, str):
                err(f"{where}: missing key")
                key = None
            elif key in declared_options:
                err(f"{where}: duplicate key {key!r}")
            kind = option.get("kind")
            if kind not in ("toggle", "choice"):
                err(f"{where}: kind must be 'toggle' or 'choice'")
            if not option.get("name"):
                err(f"{where}: missing name")
            case_ids: list = []
            if kind == "toggle":
                if "cases" in option:
                    err(f"{where}: a toggle must not have cases")
                if not isinstance(option.get("default"), bool):
                    err(f"{where}: a toggle's default must be a boolean")
            elif kind == "choice":
                cases = option.get("cases")
                if not isinstance(cases, list) or len(cases) < 2:
                    err(f"{where}: a choice needs at least 2 cases")
                    cases = []
                for j, case in enumerate(cases):
                    cid = case.get("id")
                    if not cid or not isinstance(cid, str):
                        err(f"{where}.cases[{j}]: missing id")
                    elif cid in case_ids:
                        err(f"{where}.cases[{j}]: duplicate id {cid!r}")
                    else:
                        case_ids.append(cid)
                    if not case.get("name"):
                        err(f"{where}.cases[{j}]: missing name")
                    extra = set(case) - {"id", "name", "nameByLanguage"}
                    if extra:
                        err(f"{where}.cases[{j}]: unknown fields {sorted(extra)}")
                if option.get("default") not in case_ids:
                    err(f"{where}: default must be one of the declared case ids")
            extra = set(option) - {"key", "kind", "name", "nameByLanguage", "default", "cases"}
            if extra:
                err(f"{where}: unknown fields {sorted(extra)}")
            if key:
                declared_options[key] = (kind, set(case_ids))
    body_keys: set = set()
    title_keys: set = set()
    image_keys: set = set()
    mystery_keys: set = set()
    declared_variant_ids: set = set()

    if dtype == "steps":
        def check_step_list(steps, where):
            if not steps:
                err(f"{where}: empty step list")
            for i, entry in enumerate(steps):
                validate_entry(entry, f"{where}[{i}]", allow_kind=False)
                collect_entry_refs(entry, body_keys, title_keys, image_keys)

        variants = devotion.get("variants")
        if variants is not None:
            # Alternate step-sets: mutually exclusive with top-level steps; first is default.
            if "steps" in devotion or "eastertideSteps" in devotion:
                err("a devotion with variants must not also have top-level steps/eastertideSteps")
            if not variants:
                err("variants must not be empty")
            seen_ids = set()
            check_variant_defaults(variants)
            for v, variant in enumerate(variants):
                where = f"variants[{v}]"
                vid = variant.get("id")
                if not vid or not isinstance(vid, str):
                    err(f"{where}: missing id")
                elif vid in seen_ids:
                    err(f"{where}: duplicate id {vid!r}")
                else:
                    seen_ids.add(vid)
                    declared_variant_ids.add(vid)
                if not variant.get("name"):
                    err(f"{where}: missing name")
                check_step_list(variant.get("steps") or [], f"{where}.steps")
                if "eastertideSteps" in variant:
                    check_step_list(variant["eastertideSteps"], f"{where}.eastertideSteps")
                check_default_for_languages(variant, where)
                extra = set(variant) - {"id", "name", "nameByLanguage", "steps", "eastertideSteps",
                                        "defaultForLanguages"}
                if extra:
                    err(f"{where}: unknown fields {sorted(extra)}")
        else:
            check_step_list(devotion.get("steps") or [], "steps")
            if "eastertideSteps" in devotion:
                check_step_list(devotion["eastertideSteps"], "eastertideSteps")
        for field in ("opening", "decades", "closing", "hasClosingCross"):
            if field in devotion:
                err(f"steps-type devotion must not have {field!r}")

    elif dtype == "days":
        def check_entry_list(entries, where):
            for i, entry in enumerate(entries):
                validate_entry(entry, f"{where}[{i}]", allow_kind=False)
                collect_entry_refs(entry, body_keys, title_keys, image_keys)

        days = devotion.get("days")
        if not isinstance(days, list) or not days:
            err("days-type devotion needs a non-empty 'days' array")
        for i, day in enumerate(days or []):
            where = f"days[{i}]"
            if not day.get("name"):
                err(f"{where}: missing name")
            if not day.get("steps"):
                err(f"{where}: empty step list")
            check_entry_list(day.get("steps") or [], f"{where}.steps")
            extra = set(day) - {"name", "nameByLanguage", "period", "steps"}
            if extra:
                err(f"{where}: unknown fields {sorted(extra)}")
        # How the days relate to each other, which is the difference between a novena you work
        # through on consecutive days and a weekly cycle you pick from.
        progression = devotion.get("dayProgression", "series")
        if progression not in ("series", "free"):
            err('dayProgression must be "series" (consecutive days, tracked) or "free" (pick any)')
        reminder = devotion.get("suggestedReminderTime")
        if reminder is not None:
            ok = (isinstance(reminder, str) and len(reminder) == 5 and reminder[2] == ":"
                  and reminder[:2].isdigit() and reminder[3:].isdigit()
                  and int(reminder[:2]) < 24 and int(reminder[3:]) < 60)
            if not ok:
                err('suggestedReminderTime must be "HH:mm"')
            elif progression != "series":
                err("suggestedReminderTime only means anything for a series")
        # When a series traditionally begins, so a pinned devotion can announce itself before
        # the day arrives ("Starts 29 November"). Annual month-day, not a full date.
        start = devotion.get("suggestedStart")
        if start is not None:
            parts = start.split("-") if isinstance(start, str) else []
            ok = (len(parts) == 2 and all(p.isdigit() for p in parts)
                  and 1 <= int(parts[0]) <= 12 and 1 <= int(parts[1]) <= 31)
            if not ok:
                err('suggestedStart must be "MM-DD"')
            elif progression != "series":
                err("suggestedStart only means anything for a series")
        # What to offer when the last day is prayed. A bundle id, possibly one this device does
        # not have — a bundle is validated on its own, so the reference is checked at runtime
        # and simply not offered when it cannot be resolved.
        nxt = devotion.get("suggestedNext")
        if nxt is not None:
            if not isinstance(nxt, str) or not nxt:
                err("suggestedNext must be a devotion id")
            elif nxt == manifest.get("id"):
                err("suggestedNext points at this devotion")
            elif progression != "series":
                err("suggestedNext only means anything for a series")
        check_entry_list(devotion.get("opening") or [], "opening")
        check_entry_list(devotion.get("closing") or [], "closing")
        for field in ("steps", "eastertideSteps", "variants", "decades", "hasClosingCross"):
            if field in devotion:
                err(f"days-type devotion must not have {field!r}")

    elif dtype == "hours":
        # An office is not chosen by a counter the way a novena's day is — the calendar chooses
        # it. So a bundle declares the *skeleton* of each hour once, leaves the parts that vary
        # as slots, and files every variable part in one propers table keyed by which days it
        # belongs to. See ARCHITECTURE.markdown's "Hours".
        def check_entry_list(entries, where, slots=None):
            for i, entry in enumerate(entries):
                validate_entry(entry, f"{where}[{i}]", allow_kind=False, slots=slots)
                collect_entry_refs(entry, body_keys, title_keys, image_keys)

        # slot name -> the hour ids whose skeleton asks for it.
        slots_by_hour: dict = {}
        hours = devotion.get("hours")
        if not isinstance(hours, list) or not hours:
            err("hours-type devotion needs a non-empty 'hours' array")
            hours = []
        hour_ids: list = []
        for i, hour in enumerate(hours):
            where = f"hours[{i}]"
            hid = hour.get("id")
            if not hid or not isinstance(hid, str):
                err(f"{where}: missing id")
                hid = None
            elif hid in hour_ids:
                err(f"{where}: duplicate id {hid!r}")
                hid = None
            else:
                hour_ids.append(hid)
            if not hour.get("name"):
                err(f"{where}: missing name")
            # The hour's traditional time, which is what a reminder for it should default to.
            # Advisory exactly like a series' suggestedReminderTime: the user's own time wins.
            if "suggestedTime" in hour and not _is_hour_minute(hour["suggestedTime"]):
                err(f'{where}: suggestedTime must be "HH:mm"')
            steps = hour.get("steps")
            if not steps:
                err(f"{where}: empty step list")
            mine: set = set()
            check_entry_list(steps or [], f"{where}.steps", slots=mine)
            for slot in mine:
                slots_by_hour.setdefault(slot, set()).add(hid)
            extra = unknown_fields(hour, {"id", "name", "nameByLanguage", "suggestedTime",
                                          "steps"})
            if extra:
                err(f"{where}: unknown fields {extra}")

        # Prayed around every hour — the introduction and doxology that open each one, and
        # whatever closes it. Same shape and purpose as a days-type devotion's shared pair.
        check_entry_list(devotion.get("opening") or [], "opening")
        for i, entry in enumerate(devotion.get("closing") or []):
            validate_entry(entry, f"closing[{i}]", allow_kind=True)
            collect_entry_refs(entry, body_keys, title_keys, image_keys)

        propers = devotion.get("propers") or []
        if not isinstance(propers, list):
            err("propers must be an array")
            propers = []
        filled: dict = {}
        seen_selectors: dict = {}
        for i, proper in enumerate(propers):
            where = f"propers[{i}]"
            slot = proper.get("slot")
            if not slot or not isinstance(slot, str):
                err(f"{where}: missing slot")
                slot = None
            elif slot not in slots_by_hour:
                err(f"{where}: slot {slot!r} is not asked for by any hour's steps")
            hour_id = proper.get("hour")
            if hour_id is not None:
                if hour_id not in hour_ids:
                    err(f"{where}: hour {hour_id!r} is not a declared hour")
                elif slot in slots_by_hour and hour_id not in slots_by_hour[slot]:
                    err(f"{where}: hour {hour_id!r} has no {slot!r} slot to fill")

            when = proper.get("when")
            if when is None:
                # The catch-all for a slot: legal, and how an author says "unless the calendar
                # says otherwise, this". Distinct from an unconstrained {} only in spelling.
                when = {}
            if not isinstance(when, dict):
                err(f"{where}: 'when' must be an object of calendar facets")
                when = {}
            for facet, values in when.items():
                check = PROPER_FACETS.get(facet)
                if check is None:
                    err(f"{where}.when: unknown facet {facet!r} "
                        f"(expected one of {sorted(PROPER_FACETS)})")
                    continue
                if not isinstance(values, list) or not values:
                    err(f"{where}.when.{facet}: must be a non-empty array of values")
                    continue
                for value in values:
                    if not check(value):
                        err(f"{where}.when.{facet}: {value!r} is not a valid {facet}")

            # Two propers that can never be told apart would make the day's office depend on
            # declaration order alone — almost always an authoring slip, never worth guessing at.
            selector = (hour_id, slot, json.dumps(when, sort_keys=True))
            if selector in seen_selectors:
                err(f"{where}: same slot and 'when' as {seen_selectors[selector]} — one of them "
                    f"can never be chosen")
            else:
                seen_selectors[selector] = where

            steps = proper.get("steps")
            if not steps:
                err(f"{where}: empty step list")
            check_entry_list(steps or [], f"{where}.steps")
            if slot:
                filled.setdefault(slot, set()).update(
                    hour_ids if hour_id is None else [hour_id])
            extra = unknown_fields(proper, {"when", "hour", "slot", "steps"})
            if extra:
                err(f"{where}: unknown fields {extra}")

        # A slot no proper ever fills, and with no fallback of its own, is a hole in the office —
        # it would simply vanish from the sequence, silently, on every day of the year.
        defaults_by_hour: dict = {}
        for i, hour in enumerate(hours):
            for entry in hour.get("steps") or []:
                if entry.get("kind") == SLOT_KIND and entry.get("default"):
                    defaults_by_hour.setdefault(entry.get("slot"), set()).add(hour.get("id"))
        for slot, asking in slots_by_hour.items():
            for hid in asking:
                if hid in filled.get(slot, set()) or hid in defaults_by_hour.get(slot, set()):
                    continue
                err(f"hours[{hid!r}]: slot {slot!r} has no proper to fill it and no 'default' — "
                    f"it can never produce a step")

        for field in ("steps", "eastertideSteps", "variants", "days", "dayProgression",
                      "decades", "hasClosingCross"):
            if field in devotion:
                err(f"hours-type devotion must not have {field!r}")

    elif dtype == "rosary":
        # Alternate forms of one devotion, the same idea the steps type has carried since the
        # Stations grew a scriptural form — a rosary-type devotion can differ in its opening,
        # its per-decade invocations and its closing while praying the same seven sorrows.
        variants = devotion.get("variants")
        if variants is not None:
            if any(f in devotion for f in ("opening", "decades", "closing", "hasClosingCross")):
                err("a rosary devotion with variants must not also have top-level "
                    "opening/decades/closing/hasClosingCross")
            if not variants:
                err("variants must not be empty")
            seen_ids = set()
            check_variant_defaults(variants)
            for v, variant in enumerate(variants):
                where = f"variants[{v}]"
                vid = variant.get("id")
                if not vid or not isinstance(vid, str):
                    err(f"{where}: missing id")
                elif vid in seen_ids:
                    err(f"{where}: duplicate id {vid!r}")
                else:
                    seen_ids.add(vid)
                    declared_variant_ids.add(vid)
                if not variant.get("name"):
                    err(f"{where}: missing name")
                validate_rosary_form(
                    variant.get("opening") or [], variant.get("decades") or {},
                    variant.get("closing") or [], variant.get("hasClosingCross"),
                    f"{where}.", body_keys, title_keys, image_keys, mystery_keys)
                check_default_for_languages(variant, where)
                extra = unknown_fields(variant, {"id", "name", "nameByLanguage", "opening",
                                                 "decades", "closing", "hasClosingCross",
                                                 "defaultForLanguages"})
                if extra:
                    err(f"{where}: unknown fields {extra}")
        else:
            validate_rosary_form(
                devotion.get("opening") or [], devotion.get("decades") or {},
                devotion.get("closing") or [], devotion.get("hasClosingCross"),
                "", body_keys, title_keys, image_keys, mystery_keys)

    else:
        err(f"devotion.json: unknown type {dtype!r}")
        return report()

    # --- Entry "if" expressions must reference declared options ---
    # "a & b": every term must hold, which is how a step gates on a choice *and* the season.
    for where, expr in if_refs:
        for term in (t.strip() for t in expr.split("&")):
            key, wanted_case = term, None
            if "=" in term:
                key, _, wanted_case = term.partition("=")
            elif term.startswith("!"):
                key = term[1:]
            # Calendar facts the engines seed beside a bundle's declared options; a bundle may
            # gate on them but never declare them (the engine would shadow the season).
            if key in CALENDAR_CONDITION_KEYS:
                if wanted_case is not None:
                    err(f"{where}: '{term}' — {key!r} is a calendar fact, not a choice")
                continue
            declared = declared_options.get(key)
            if declared is None:
                err(f"{where}: 'if' references undeclared option {key!r}")
                continue
            kind, case_ids = declared
            if wanted_case is not None:
                if kind != "choice":
                    err(f"{where}: '{term}' — {key!r} is a {kind}, not a choice")
                elif wanted_case not in case_ids:
                    err(f"{where}: '{term}' — {wanted_case!r} is not a case of {key!r}")
            elif kind != "toggle":
                err(f"{where}: '{term}' — bare/negated 'if' needs a toggle, {key!r} is a {kind}")

    for where, option_key in antiphon_option_refs:
        declared = declared_options.get(option_key)
        if declared is None:
            err(f"{where}: optionKey references undeclared option {option_key!r}")
        elif declared[0] != "choice":
            err(f"{where}: optionKey must name a choice option, {option_key!r} is a {declared[0]}")

    # --- Reference resolution per language ---
    allowlist_path = src / "validation-allowlist.json"
    allowlist = load_json(allowlist_path).get("missingKeys", {}) if allowlist_path.exists() else {}

    # Validate every authored language overlay, not only the complete languages advertised in
    # manifest.json. Scripture import overlays (Aramaic/Greek/Spanish today) are intentionally
    # partial, but their mystery objects still have the same field-wise contract.
    for content_path in sorted((src / "content").glob("*.json")):
        overlay = load_json(content_path)
        validate_prayer_traditions(content_path, overlay)
        validate_mystery_overrides(content_path, overlay)
        validate_citation_style(content_path, overlay)

    contents = {}
    for lang in languages:
        lang_file = src / "content" / f"{lang}.json"
        contents[lang] = load_json(lang_file) if lang_file.exists() else {"prayers": {}, "mysteries": {}}

    for lang in languages:
        prayers = contents[lang].get("prayers", {})
        mysteries = contents[lang].get("mysteries", {})
        allowed_missing = set(allowlist.get(lang, []))
        for key in sorted(body_keys | title_keys):
            if key in prayers or key in HARDCODED_PRAYER_KEYS or key in allowed_missing:
                continue
            err(f"content/{lang}.json: unresolved key {key!r} (not bundle-local, not a hardcoded "
                f"PrayerKey, not allowlisted)")
        for key in sorted(mystery_keys):
            if key in mysteries or key in SHARED_MYSTERY_IMAGE_KEYS or key in allowed_missing:
                continue
            err(f"content/{lang}.json: no mystery text for {key!r}")
        # Optional transliterations (v0.7): a parallel reading aid per prayer key — every
        # entry must transliterate a key this language actually ships.
        transliterations = contents[lang].get("transliterations", {})
        if not isinstance(transliterations, dict):
            err(f"content/{lang}.json: 'transliterations' must be a map of prayer key to text")
        else:
            for key in sorted(transliterations):
                if key not in prayers:
                    err(f"content/{lang}.json: transliteration for unknown key {key!r} "
                        f"(must transliterate one of this language's own prayers)")

    # Step imageKeys only need to resolve at runtime (pack data or the platform asset
    # catalogs), so .png counts too — cross_placeholder, every platform's built-in fallback,
    # ships as a png. manifest.images stays .jpg-only above: those are what the packers stage.
    for key in sorted(image_keys):
        if not (shared_images / f"{key}.jpg").exists() and not (shared_images / f"{key}.png").exists():
            err(f"imageKey {key!r} has no Shared/Images/{key}.jpg or .png")

    validate_audio(src, languages, declared_variant_ids)

    return report()


def report() -> int:
    if errors:
        for e in errors:
            print(f"validate-devotion: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

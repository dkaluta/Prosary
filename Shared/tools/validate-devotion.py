#!/usr/bin/env python3
"""Validates a devotion bundle source directory (Shared/content/<id>/) before packing.

Called by make-prosaryprayer.sh (and Make-ProsaryPrayer.ps1 when python3 is available).
Checks, beyond plain JSON validity (which the packer already enforces):

- devotion.json (when present) matches the v2 schema for its "type" ("steps" | "rosary");
- every bodyKey/titleKey referenced by devotion.json resolves in every manifest language —
  either in the bundle's own content/<lang>.json "prayers" map, or in the surviving hardcoded
  PrayerKey pool (the keys every platform still ships in code after the generic-devotion
  migration), minus an optional per-bundle gap allowlist (validation-allowlist.json);
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
  ARCHITECTURE.md's "Audio".

Usage: validate-devotion.py <bundle-source-dir>
Exit code 0 = valid; non-zero with messages on stderr otherwise.
"""

import json
import sys
from pathlib import Path

# PrayerKeys that remain hardcoded in every platform's PrayerTranslations after the
# generic-devotion migration (main prayers, Rosary-specific keys, Marian antiphons, Jesus
# Prayer). A bundle may reference these without shipping its own translation.
HARDCODED_PRAYER_KEYS = {
    "signumCrucis", "symbolumApostolorum", "paterNoster", "aveMaria", "gloriaPatri",
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

SIGN_OF_CROSS_KEY = "signumCrucis"
ANTIPHON_KIND = "seasonalMarianAntiphon"
OPTION_ANTIPHON_KIND = "marianAntiphon"

errors: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def load_json(path: Path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


# (where, expr) for every entry-level "if" — checked against options.json declarations after
# all entry lists are walked.
if_refs: list = []


# (where, optionKey) for every marianAntiphon entry — checked against options.json after all
# entry lists are walked (the named option must be a choice).
antiphon_option_refs: list = []


def validate_entry(entry: dict, where: str, allow_kind: bool) -> None:
    if "if" in entry:
        if not isinstance(entry["if"], str) or not entry["if"]:
            err(f"{where}: 'if' must be a non-empty string")
        else:
            if_refs.append((where, entry["if"]))
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
    if "isScripture" in entry and not isinstance(entry["isScripture"], bool):
        err(f"{where}: isScripture must be a boolean")
    if "isScriptureByLanguage" in entry:
        value = entry["isScriptureByLanguage"]
        if not isinstance(value, dict) or not value or not all(isinstance(v, bool) for v in value.values()):
            err(f"{where}: isScriptureByLanguage must be a non-empty map of language -> boolean")


def validate_audio(src: Path, languages: list, variant_ids: set) -> None:
    """audio.json (when present): narrated Ogg Opus recordings + chapter seek points — see
    ARCHITECTURE.md's "Audio". Runs for override-only bundles too (audio needs no
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


def main() -> int:
    src = Path(sys.argv[1]).resolve()
    shared_images = Path(__file__).resolve().parent.parent / "Images"

    manifest = load_json(src / "manifest.json")
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
                extra = set(variant) - {"id", "name", "nameByLanguage", "steps", "eastertideSteps"}
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
        check_entry_list(devotion.get("opening") or [], "opening")
        check_entry_list(devotion.get("closing") or [], "closing")
        for field in ("steps", "eastertideSteps", "variants", "decades", "hasClosingCross"):
            if field in devotion:
                err(f"days-type devotion must not have {field!r}")

    elif dtype == "rosary":
        opening = devotion.get("opening") or []
        closing = devotion.get("closing") or []
        decades = devotion.get("decades") or {}

        if not opening:
            err("rosary-type devotion needs an opening")
        elif opening[0].get("bodyKey") != SIGN_OF_CROSS_KEY:
            err("opening[0] must be the Sign of the Cross (bead track assumes step 0 is the opening cross)")
        for i, entry in enumerate(opening):
            validate_entry(entry, f"opening[{i}]", allow_kind=False)
            collect_entry_refs(entry, body_keys, title_keys, image_keys)

        antiphons = 0
        for i, entry in enumerate(closing):
            validate_entry(entry, f"closing[{i}]", allow_kind=True)
            if entry.get("kind") in (ANTIPHON_KIND, OPTION_ANTIPHON_KIND):
                antiphons += 1
            collect_entry_refs(entry, body_keys, title_keys, image_keys)
        if antiphons > 1:
            err("at most one antiphon-kind closing entry is allowed (single 'M' bead)")
        if devotion.get("hasClosingCross"):
            last = closing[-1] if closing else {}
            if last.get("bodyKey") != SIGN_OF_CROSS_KEY or "repeat" in last:
                err("hasClosingCross: the final closing entry must be a non-repeated Sign of the "
                    "Cross (BeadLayout assumes the closing cross is the literal last step)")

        entries = decades.get("entries")
        count = decades.get("count")
        fixed_image = decades.get("fixedImageKey")
        source = decades.get("source")
        if source is not None and source != "mysteryGroups":
            err(f"decades: unknown source {source!r}")
        if source is not None:
            # Engine-cataloged decades (the Rosary): the decade list comes from the
            # mystery-group machinery, so a bundle catalog would be dead data.
            if entries is not None or count is not None or fixed_image:
                err("decades: 'source' is mutually exclusive with 'entries'/'count'/'fixedImageKey'")
        elif (entries is None) == (count is None):
            err("decades: exactly one of 'entries' or 'count' is required (or a 'source')")
        if count is not None and not fixed_image:
            err("decades: 'count' requires 'fixedImageKey'")
        if entries is not None and fixed_image:
            err("decades: 'entries' and 'fixedImageKey' are mutually exclusive")
        if not decades.get("ordinalNoun"):
            err("decades: ordinalNoun is required")
        if decades.get("announceMystery") and entries is None and source is None:
            err("decades: announceMystery requires 'entries' (or an engine 'source')")
        if not isinstance(decades.get("minorCount"), int) or decades.get("minorCount", 0) < 1:
            err("decades: minorCount must be an integer >= 1")
        for role in ("majorStep", "minorStep"):
            step = decades.get(role) or {}
            if not step.get("title") or not step.get("bodyKey"):
                err(f"decades.{role}: needs title and bodyKey")
            else:
                body_keys.add(step["bodyKey"])
            if step.get("imageKey"):
                image_keys.add(step["imageKey"])
        for i, entry in enumerate(entries or []):
            if not entry.get("imageKey"):
                err(f"decades.entries[{i}]: missing imageKey")
            else:
                image_keys.add(entry["imageKey"])
                if decades.get("announceMystery"):
                    mystery_keys.add(entry["imageKey"])
        if fixed_image:
            image_keys.add(fixed_image)
        for i, entry in enumerate(decades.get("postMinor") or []):
            validate_entry(entry, f"decades.postMinor[{i}]", allow_kind=False)
            collect_entry_refs(entry, body_keys, title_keys, image_keys)
        presenter = decades.get("presenter")
        if presenter is not None:
            if not presenter.get("combinedTitle"):
                err("decades.presenter: needs combinedTitle")
            if not presenter.get("bodyKeys"):
                err("decades.presenter: needs a non-empty bodyKeys list")
            for key in presenter.get("bodyKeys") or []:
                body_keys.add(key)
    else:
        err(f"devotion.json: unknown type {dtype!r}")
        return report()

    # --- Entry "if" expressions must reference declared options ---
    for where, expr in if_refs:
        key, wanted_case = expr, None
        if "=" in expr:
            key, _, wanted_case = expr.partition("=")
        elif expr.startswith("!"):
            key = expr[1:]
        declared = declared_options.get(key)
        if declared is None:
            err(f"{where}: 'if' references undeclared option {key!r}")
            continue
        kind, case_ids = declared
        if wanted_case is not None:
            if kind != "choice":
                err(f"{where}: '{expr}' — {key!r} is a {kind}, not a choice")
            elif wanted_case not in case_ids:
                err(f"{where}: '{expr}' — {wanted_case!r} is not a case of {key!r}")
        elif kind != "toggle":
            err(f"{where}: '{expr}' — bare/negated 'if' needs a toggle, {key!r} is a {kind}")

    for where, option_key in antiphon_option_refs:
        declared = declared_options.get(option_key)
        if declared is None:
            err(f"{where}: optionKey references undeclared option {option_key!r}")
        elif declared[0] != "choice":
            err(f"{where}: optionKey must name a choice option, {option_key!r} is a {declared[0]}")

    # --- Reference resolution per language ---
    allowlist_path = src / "validation-allowlist.json"
    allowlist = load_json(allowlist_path).get("missingKeys", {}) if allowlist_path.exists() else {}

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

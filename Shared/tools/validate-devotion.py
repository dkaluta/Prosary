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
  Rosary's shared mystery pool for reused imageKeys).

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
    "fructusMysteriiLabel", "oratioIesu",
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

errors: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def load_json(path: Path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def validate_entry(entry: dict, where: str, allow_kind: bool) -> None:
    if allow_kind and entry.get("kind") == ANTIPHON_KIND:
        extra = set(entry) - {"kind"}
        if extra:
            err(f"{where}: a {ANTIPHON_KIND} entry must have no other fields (has {sorted(extra)})")
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
    if "repeat" in entry and (not isinstance(entry["repeat"], int) or entry["repeat"] < 2):
        err(f"{where}: repeat must be an integer >= 2")


def collect_entry_refs(entry: dict, body_keys: set, title_keys: set, image_keys: set) -> None:
    if entry.get("kind") == ANTIPHON_KIND:
        return
    if entry.get("bodyKey"):
        body_keys.add(entry["bodyKey"])
    if entry.get("titleKey"):
        title_keys.add(entry["titleKey"])
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
        # Override-only bundle (rosary/angelus pre-migration shape) — nothing more to check.
        return report()

    devotion = load_json(devotion_path)
    dtype = devotion.get("type")
    body_keys: set = set()
    title_keys: set = set()
    image_keys: set = set()
    mystery_keys: set = set()

    if dtype == "steps":
        steps = devotion.get("steps") or []
        if not steps:
            err("steps-type devotion has no steps")
        for i, entry in enumerate(steps):
            validate_entry(entry, f"steps[{i}]", allow_kind=False)
            collect_entry_refs(entry, body_keys, title_keys, image_keys)
        for i, entry in enumerate(devotion.get("eastertideSteps") or []):
            validate_entry(entry, f"eastertideSteps[{i}]", allow_kind=False)
            collect_entry_refs(entry, body_keys, title_keys, image_keys)
        for field in ("opening", "decades", "closing", "hasClosingCross"):
            if field in devotion:
                err(f"steps-type devotion must not have {field!r}")

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
            if entry.get("kind") == ANTIPHON_KIND:
                antiphons += 1
            collect_entry_refs(entry, body_keys, title_keys, image_keys)
        if antiphons > 1:
            err("at most one seasonalMarianAntiphon closing entry is allowed (single 'M' bead)")
        if devotion.get("hasClosingCross"):
            last = closing[-1] if closing else {}
            if last.get("bodyKey") != SIGN_OF_CROSS_KEY or "repeat" in last:
                err("hasClosingCross: the final closing entry must be a non-repeated Sign of the "
                    "Cross (BeadLayout assumes the closing cross is the literal last step)")

        entries = decades.get("entries")
        count = decades.get("count")
        fixed_image = decades.get("fixedImageKey")
        if (entries is None) == (count is None):
            err("decades: exactly one of 'entries' or 'count' is required")
        if count is not None and not fixed_image:
            err("decades: 'count' requires 'fixedImageKey'")
        if entries is not None and fixed_image:
            err("decades: 'entries' and 'fixedImageKey' are mutually exclusive")
        if not decades.get("ordinalNoun"):
            err("decades: ordinalNoun is required")
        if decades.get("announceMystery") and entries is None:
            err("decades: announceMystery requires 'entries'")
        if not isinstance(decades.get("minorCount"), int) or decades.get("minorCount", 0) < 1:
            err("decades: minorCount must be an integer >= 1")
        for role in ("majorStep", "minorStep"):
            step = decades.get(role) or {}
            if not step.get("title") or not step.get("bodyKey"):
                err(f"decades.{role}: needs title and bodyKey")
            else:
                body_keys.add(step["bodyKey"])
        for i, entry in enumerate(entries or []):
            if not entry.get("imageKey"):
                err(f"decades.entries[{i}]: missing imageKey")
            else:
                image_keys.add(entry["imageKey"])
                if decades.get("announceMystery"):
                    mystery_keys.add(entry["imageKey"])
        if fixed_image:
            image_keys.add(fixed_image)
    else:
        err(f"devotion.json: unknown type {dtype!r}")
        return report()

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

    for key in sorted(image_keys):
        if not (shared_images / f"{key}.jpg").exists():
            err(f"imageKey {key!r} has no Shared/Images/{key}.jpg")

    return report()


def report() -> int:
    if errors:
        for e in errors:
            print(f"validate-devotion: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

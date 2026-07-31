// Fixed catalogs mirrored from the apps — see Shared/ARCHITECTURE.md ("Content bundles") and
// Shared/tools/validate-devotion.py. These must track the apps, not the other way round.

/** The 6 prayer languages every platform ships (LanguageCatalog). */
export const LANGUAGES = [
  { code: "la", name: "Latin", rtl: false },
  { code: "en", name: "English", rtl: false },
  { code: "ar", name: "Arabic", rtl: true },
  { code: "he", name: "Hebrew", rtl: true },
  { code: "ru", name: "Russian", rtl: false },
  { code: "tl", name: "Tagalog", rtl: false },
] as const;

export type LanguageCode = (typeof LANGUAGES)[number]["code"];

export function isRtl(code: LanguageCode): boolean {
  return LANGUAGES.find((l) => l.code === code)?.rtl ?? false;
}

/**
 * Prayers whose text ships hardcoded in every app (validate-devotion.py's
 * HARDCODED_PRAYER_KEYS, minus Rosary-machinery keys that make no sense as standalone steps).
 * A bundle references these by key and must NOT duplicate their text — the "main" five are
 * deliberately absent from every bundle, and the rest resolve from the shared tables.
 * `image` is the traditional override illustration the built-in devotions pair each with.
 */
export const COMMON_PRAYERS = [
  { key: "signumCrucis", label: "Sign of the Cross", image: "crucifix", main: true },
  { key: "paterNoster", label: "Our Father", image: "our_father", main: true },
  { key: "aveMaria", label: "Hail Mary", image: "madonna_and_child", main: true },
  { key: "gloriaPatri", label: "Glory Be", image: "glory_be", main: true },
  { key: "symbolumApostolorum", label: "Apostles' Creed", image: "crucifix", main: true },
  { key: "oratioFatimae", label: "Fatima Prayer", image: "jesus_portrait", main: false },
  { key: "requiemAeternam", label: "Eternal Rest", image: "eternal_rest", main: false },
  { key: "sanctusMichael", label: "Prayer to St. Michael", image: "st_michael", main: false },
  { key: "salveRegina", label: "Hail Holy Queen (Salve Regina)", image: "madonna_and_child", main: false },
  { key: "subTuumPraesidium", label: "Beneath Thy Protection", image: "madonna_and_child", main: false },
  { key: "animaChristi", label: "Anima Christi", image: "jesus_portrait", main: false },
  { key: "oratioIesu", label: "Jesus Prayer", image: "jesus_portrait", main: false },
] as const;

export type CommonPrayerKey = (typeof COMMON_PRAYERS)[number]["key"];

export function commonPrayer(key: string) {
  return COMMON_PRAYERS.find((p) => p.key === key);
}

/** Shared-pool illustration a custom step falls back to when the author attaches no artwork. */
export const PLACEHOLDER_IMAGE_KEY = "cross_placeholder";

/**
 * Icons every platform can render: the SF Symbol names in each port's fixed mapping table
 * (Android CustomDevotionIcons.kt / the Windows Segoe glyph table). Anything else falls back
 * to a star, so the picker offers exactly these.
 */
export const ICONS = [
  { systemName: "star", label: "Star", glyph: "★" },
  { systemName: "bell", label: "Bell", glyph: "🔔" },
  { systemName: "crown", label: "Crown", glyph: "👑" },
  { systemName: "drop", label: "Drop", glyph: "💧" },
  { systemName: "sun.max", label: "Sun", glyph: "☀️" },
  { systemName: "triangle", label: "Triangle", glyph: "△" },
  { systemName: "figure.walk", label: "Pilgrim", glyph: "🚶" },
] as const;

/** Bundle ids the apps ship — installPack rejects collisions with any loaded bundle. */
export const RESERVED_IDS = [
  "rosary",
  "angelus",
  "stationsOfTheCross",
  "viaLucis",
  "franciscanCrown",
  "sevenSorrows",
  "divineMercyChaplet",
  "trisagion",
  "jesusPrayer",
];

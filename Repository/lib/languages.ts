// The prayer languages the repository currently accepts. Keep publication validation and
// catalog filtering on this one list so a bundle cannot be advertised with a language the
// repository did not validate. This mirrors the native and Compose prayer-language catalogs.
export const LANGUAGE_NAMES = {
  la: "Latina",
  en: "English",
  ar: "العربية",
  he: "עברית",
  "he-x-gamliel": "עברית",
  arc: "ܐܪܡܐܝܬ / ארמית",
  el: "Ελληνικά",
  es: "Español",
  ru: "Русский",
  tl: "Tagalog",
  fr: "Français",
  it: "Italiano",
} as const;

export type SupportedLanguage = keyof typeof LANGUAGE_NAMES;

export const SUPPORTED_LANGUAGES = Object.freeze(
  Object.keys(LANGUAGE_NAMES) as SupportedLanguage[],
);

const SUPPORTED_LANGUAGE_SET: ReadonlySet<string> = new Set(SUPPORTED_LANGUAGES);

export function isSupportedLanguage(value: string): value is SupportedLanguage {
  return SUPPORTED_LANGUAGE_SET.has(value);
}

export function languageName(value: string): string {
  return isSupportedLanguage(value) ? LANGUAGE_NAMES[value] : value;
}

/** Display Hebrew once while retaining every historical content code in stored bundles. */
export function displayLanguageCodes(codes: readonly string[]): string[] {
  return [...new Set(codes.map((code) => code === "he-x-gamliel" ? "he" : code))];
}

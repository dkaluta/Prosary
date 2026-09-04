// The prayer languages the repository currently accepts. Keep publication validation and
// catalog filtering on this one list so a bundle cannot be advertised with a language the
// repository did not validate. See README.markdown for the wider native-app catalog.
export const LANGUAGE_NAMES = {
  la: "Latina",
  en: "English",
  ar: "العربية",
  he: "עברית",
  ru: "Русский",
  tl: "Tagalog",
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

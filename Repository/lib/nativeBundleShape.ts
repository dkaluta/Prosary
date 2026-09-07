// The runtime JSON shapes shared by the native installers, not the stricter authoring schema.
// Keep in step with Android's PrayerPackLoader.kt and Apple's PrayerPackLoader.swift. Unknown
// metadata is retained, optional fields may stay absent, and legacy bundles need no version
// field. Reference coverage, option expressions, source authenticity and media decoding remain
// the authoring validator/runtime's work; passing this check is not a full content audit.

type Check = (value: unknown, path: string) => void;
type Fields = Record<string, Check>;

function invalid(path: string, expected: string): never {
  throw new Error(`${path} must be ${expected}.`);
}

export function nativeObject(value: unknown, path: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    invalid(path, "an object");
  }
  return value as Record<string, unknown>;
}

const string: Check = (value, path) => {
  if (typeof value !== "string") invalid(path, "a string");
};
const boolean: Check = (value, path) => {
  if (typeof value !== "boolean") invalid(path, "a boolean");
};
const number: Check = (value, path) => {
  if (typeof value !== "number" || !Number.isFinite(value)) invalid(path, "a finite number");
};
const integer: Check = (value, path) => {
  if (typeof value !== "number" || !Number.isInteger(value) || value < -2147483648 || value > 2147483647) {
    invalid(path, "a 32-bit integer");
  }
};
const choice = (...values: string[]): Check => (value, path) => {
  if (typeof value !== "string" || !values.includes(value)) invalid(path, values.join(" or "));
};
const array = (entry: Check): Check => (value, path) => {
  if (!Array.isArray(value)) invalid(path, "an array");
  value.forEach((item, index) => entry(item, `${path}[${index}]`));
};
const map = (entry: Check): Check => (value, path) => {
  for (const [key, item] of Object.entries(nativeObject(value, path))) entry(item, `${path}.${key}`);
};
const object = (required: Fields, optional: Fields = {}, defaulted: Fields = {}): Check => (value, path) => {
  const fields = nativeObject(value, path);
  for (const [key, check] of Object.entries(required)) check(fields[key], `${path}.${key}`);
  // Native nullable fields accept both omitted keys and JSON null. Defaulted non-null maps
  // accept omission but cannot contain null (Kotlin serialization rejects it).
  for (const [key, check] of Object.entries(optional)) {
    if (fields[key] != null) check(fields[key], `${path}.${key}`);
  }
  for (const [key, check] of Object.entries(defaulted)) {
    if (Object.hasOwn(fields, key)) check(fields[key], `${path}.${key}`);
  }
};
const strings = map(string);
const stringList = array(string);
const translatedName = { nameByLanguage: strings };

const step = object({}, {
  title: string, titleKey: string, subtitle: string, subtitleKey: string,
  bodyKey: string, acclamationKey: string, imageKey: string, optionKey: string,
  repeat: integer, counterIndex: integer, counterTotal: integer,
  isScripture: boolean, isScriptureByLanguage: map(boolean), if: string,
  kind: choice("seasonalMarianAntiphon", "marianAntiphon"),
});
const steps = array(step);
const fixedStep = object({ bodyKey: string }, { title: string, titleKey: string, imageKey: string });
const decades = object({
  announceMystery: boolean, majorStep: fixedStep, minorStep: fixedStep, minorCount: integer,
}, {
  ordinalNoun: string, ordinalNounKey: string, source: string, count: integer,
  fixedImageKey: string,
  entries: array(object({ imageKey: string }, { isScripture: boolean })),
  preAnnouncement: steps, postMinor: steps,
  presenter: object({ bodyKeys: stringList }, { combinedTitle: string, combinedTitleKey: string }),
});
const formFields = {
  steps, eastertideSteps: steps, opening: steps, closing: steps, decades, hasClosingCross: boolean,
};

export const checkNativeDevotion: Check = object({ type: choice("steps", "rosary", "days") }, {
  ...formFields,
  dayProgression: choice("series", "free"), suggestedReminderTime: string, suggestedStart: string, suggestedNext: string,
  days: array(object({ name: string, steps }, { ...translatedName, period: string })),
  variants: array(object({ id: string, name: string }, {
    ...formFields, ...translatedName, defaultForLanguages: stringList,
  })),
});

// Identity is re-stamped by the repository before a native installer sees this manifest.
export const checkNativeManifest: Check = object({
  displayName: string, languages: stringList, hasCatalog: boolean,
}, {
  builtinKind: string, accentColorHex: string, accentColorDarkHex: string,
  iconSystemName: string, iconGlyph: string, displayNameByLanguage: strings,
  reminderBody: strings, reminderPresetHours: array(integer), reminderPresetFooter: strings,
  tags: stringList,
});

export const checkNativeContent: Check = object({
  prayers: strings,
  mysteries: map(object({}, {
    title: string, fruit: string, description: string, transliteratedDescription: string,
  })),
}, {}, { transliterations: strings, $prayerTraditionByKey: strings });

const optionDefault: Check = (value, path) => {
  if (typeof value !== "string" && typeof value !== "boolean") invalid(path, "a boolean or string");
};
export const checkNativeOptions: Check = object({ options: array(object({
  key: string, kind: choice("toggle", "choice"), name: string, default: optionDefault,
}, {
  ...translatedName,
  cases: array(object({ id: string, name: string }, translatedName)),
})) });

export const checkNativeAudio: Check = object({ tracks: array(object({
  id: string, language: string, file: string,
  chapters: array(object({ start: number }, { title: string, titleKey: string, stepIndex: integer })),
}, { variantId: string, name: string, ...translatedName })) });

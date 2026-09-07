// Import is intentionally narrower than the native reader. Every accepted field must have
// an editor representation; otherwise reopening and publishing would erase authored data.

type ObjectValue = Record<string, unknown>;

export function unsupportedImport(detail: string): never {
  throw new Error(`This bundle includes ${detail}, which the composer cannot preserve yet. Nothing has been imported.`);
}

export function importObject(value: unknown, label: string): ObjectValue {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`The bundle's ${label} is not a valid object. Nothing has been imported.`);
  }
  return value as ObjectValue;
}

const fieldDescriptions: Record<string, string> = {
  subtitle: "prayer subtitles", subtitleKey: "translated prayer subtitles",
  acclamationKey: "separate prayer acclamations",
  isScriptureByLanguage: "Scripture formatting that changes by language",
  counterIndex: "custom prayer counters", counterTotal: "custom prayer counters",
  opening: "shared daily opening prayers", closing: "shared daily closing prayers",
  period: "day grouping labels", eastertideSteps: "seasonal Eastertide steps",
  if: "option-gated prayers", kind: "special prayer steps",
  reminderBody: "custom reminder text", reminderPresetHours: "preset reminder times",
  reminderPresetFooter: "preset reminder descriptions", builtinKind: "a built-in prayer identity",
};

export function importFields(value: ObjectValue, allowed: string[], label: string): void {
  for (const key of Object.keys(value)) {
    if (!allowed.includes(key)) unsupportedImport(fieldDescriptions[key] ?? `extra ${label} metadata (“${key}”)`);
  }
}

export function importString(value: unknown, label: string): string {
  if (typeof value !== "string") throw new Error(`The bundle's ${label} must be text. Nothing has been imported.`);
  return value;
}

export function importStrings(value: unknown, label: string): string[] {
  if (!Array.isArray(value)) throw new Error(`The bundle's ${label} must be a list. Nothing has been imported.`);
  return value.map((item) => importString(item, label));
}

export function importStringMap(value: unknown, label: string, languages?: readonly string[]): Record<string, string> {
  const map = importObject(value, label);
  for (const [key, text] of Object.entries(map)) {
    importString(text, label);
    if (languages && !languages.includes(key)) unsupportedImport(`${label} in a language absent from the bundle's language list (“${key}”)`);
  }
  return map as Record<string, string>;
}

function optionalStrings(value: ObjectValue, keys: string[], label: string): void {
  for (const key of keys) if (key in value) importString(value[key], label);
}

export function validateManifestImport(value: unknown, knownLanguages: readonly string[]): string[] {
  const manifest = importObject(value, "manifest");
  importFields(manifest, ["schemaVersion", "id", "kind", "displayName", "displayNameByLanguage", "languages",
    "hasCatalog", "images", "mainPrayerKeysOmitted", "accentColorHex", "accentColorDarkHex", "iconSystemName", "iconGlyph", "tags"], "manifest");
  optionalStrings(manifest, ["id", "kind", "displayName", "accentColorHex", "accentColorDarkHex", "iconSystemName", "iconGlyph"], "manifest text");
  if (manifest.schemaVersion !== undefined && manifest.schemaVersion !== 1) unsupportedImport("a newer manifest version");
  if (manifest.hasCatalog !== undefined && manifest.hasCatalog !== false) unsupportedImport("a mystery catalog");
  if (manifest.kind !== undefined && manifest.kind !== manifest.id) unsupportedImport("a separate prayer kind and identity");
  const languages = importStrings(manifest.languages, "language list");
  if (!languages.length || new Set(languages).size !== languages.length) unsupportedImport("an empty or repeated language list");
  for (const language of languages) if (!knownLanguages.includes(language)) unsupportedImport(`an unsupported language (“${language}”)`);
  if (manifest.displayNameByLanguage !== undefined) importStringMap(manifest.displayNameByLanguage, "translated names", languages);
  for (const key of ["tags", "images", "mainPrayerKeysOmitted"]) if (key in manifest) importStrings(manifest[key], key);
  return languages;
}

export function validateDevotionImport(value: unknown, languages: readonly string[]): void {
  const devotion = importObject(value, "prayer structure");
  if (devotion.type !== "steps" && devotion.type !== "days") unsupportedImport("an unsupported prayer structure, such as bead-based prayers");
  importFields(devotion, devotion.type === "steps" ? ["type", "steps", "variants"]
    : ["type", "days", "dayProgression", "suggestedStart", "suggestedReminderTime", "suggestedNext"], "prayer structure");
  const validateSteps = (value: unknown) => {
    if (!Array.isArray(value) || !value.length) unsupportedImport("a missing or empty prayer sequence");
    for (const item of value) {
      const step = importObject(item, "prayer step");
      importFields(step, ["title", "titleKey", "bodyKey", "imageKey", "isScripture", "repeat"], "prayer step");
      optionalStrings(step, ["title", "titleKey", "bodyKey", "imageKey"], "prayer step text");
      if (!step.bodyKey || (!step.title && !step.titleKey) || (step.title !== undefined && step.titleKey !== undefined)) {
        unsupportedImport("a prayer without one unambiguous title and body reference");
      }
      if (step.isScripture !== undefined && typeof step.isScripture !== "boolean") unsupportedImport("invalid Scripture formatting");
      if (step.repeat !== undefined && (typeof step.repeat !== "number" || !Number.isSafeInteger(step.repeat) || step.repeat < 1)) {
        unsupportedImport("an invalid prayer repeat count");
      }
    }
  };
  if (devotion.type === "steps") {
    if (("steps" in devotion) === ("variants" in devotion)) unsupportedImport("overlapping or missing prayer sequences and alternate forms");
    if ("steps" in devotion) validateSteps(devotion.steps);
    else {
      if (!Array.isArray(devotion.variants) || !devotion.variants.length) unsupportedImport("an empty alternate-form list");
      for (const item of devotion.variants) {
        const variant = importObject(item, "alternate form");
        importFields(variant, ["id", "name", "nameByLanguage", "defaultForLanguages", "steps"], "alternate form");
        importString(variant.id, "alternate-form identity");
        importString(variant.name, "alternate-form name");
        if (variant.nameByLanguage !== undefined) importStringMap(variant.nameByLanguage, "translated form names", languages);
        if (variant.defaultForLanguages !== undefined) importStrings(variant.defaultForLanguages, "default form languages");
        validateSteps(variant.steps);
      }
    }
  } else {
    if (devotion.dayProgression !== undefined && !["series", "free"].includes(devotion.dayProgression as string)) unsupportedImport("an unsupported day progression");
    optionalStrings(devotion, ["suggestedStart", "suggestedReminderTime", "suggestedNext"], "day suggestions");
    if (!Array.isArray(devotion.days) || !devotion.days.length) unsupportedImport("a missing or empty day list");
    for (const item of devotion.days) {
      const day = importObject(item, "day");
      importFields(day, ["name", "nameByLanguage", "steps"], "day");
      importString(day.name, "day name");
      if (day.nameByLanguage !== undefined) importStringMap(day.nameByLanguage, "translated day names", languages);
      validateSteps(day.steps);
    }
  }
}

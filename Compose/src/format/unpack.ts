// .prosaryprayer -> Project, the best-effort inverse of pack.ts so an author can reopen and
// keep editing a bundle. Only the wizard's own subset round-trips: steps-type devotions (flat
// or with alternate forms) and days-type ones (what this composer emits). Anything richer —
// the rosary type, seasonal step swaps, option-gated steps — is declined with a plain-language
// message rather than silently flattened.

import type { CommonPrayerKey, LanguageCode } from "./catalog";
import { LANGUAGES, PLACEHOLDER_IMAGE_KEY, commonPrayer } from "./catalog";
import type { EditorStep, EditorVariant, PerLanguage, Project } from "./project";
import { newProject, newUid, pruneUnusedImages } from "./project";
import { ZIP_LIMITS, ZipReader } from "./zip";
import { newImageFileId, UUID7_PATTERN } from "./imageIdentity";
import {
  importFields, importObject, importString, importStringMap, unsupportedImport,
  validateDevotionImport, validateManifestImport,
} from "./importCompatibility";

interface RawStep {
  title?: string;
  titleKey?: string;
  bodyKey?: string;
  imageKey?: string;
  isScripture?: boolean;
  repeat?: number;
}

export async function openBundle(bytes: Uint8Array): Promise<Project> {
  let zip: ZipReader;
  try {
    zip = ZipReader.open(bytes);
  } catch (error) {
    const detail = error instanceof Error ? ` ${error.message}` : "";
    throw new Error(`This file is not a readable .prosaryprayer bundle.${detail}`);
  }
  if (!zip.has("manifest.json")) throw new Error("This file is not a readable .prosaryprayer bundle.");

  const manifest = (await zip.json("manifest.json")) as {
    id?: string;
    displayName?: string;
    displayNameByLanguage?: Record<string, string>;
    languages?: string[];
    accentColorHex?: string;
    accentColorDarkHex?: string;
    iconSystemName?: string;
    iconGlyph?: string;
    builtinKind?: string;
    tags?: string[];
    galleryImageKey?: string;
  };
  const languages = validateManifestImport(manifest, LANGUAGES.map((language) => language.code));
  for (const name of zip.names()) {
    if (name.endsWith("/")) continue;
    if (name.startsWith("content/")) {
      if (!languages.some((language) => name === `content/${language}.json`)) {
        unsupportedImport(`additional language content (“${name}”) outside the advertised language list`);
      }
    } else if (!["manifest.json", "devotion.json", "audio.json"].includes(name)
      && !name.startsWith("images/") && !name.startsWith("audio/")) {
      unsupportedImport(name === "options.json" ? "configurable prayer options" : `an additional bundle file (“${name}”)`);
    }
  }
  if (!zip.has("devotion.json")) {
    throw new Error("This bundle has no prayer steps the composer can edit.");
  }
  const devotion = (await zip.json("devotion.json")) as {
    type?: string;
    steps?: RawStep[];
    days?: { name: string; nameByLanguage?: Record<string, string>; steps: RawStep[] }[];
    dayProgression?: "series" | "free";
    suggestedStart?: string;
    suggestedReminderTime?: string;
    suggestedNext?: string;
    eastertideSteps?: unknown;
    variants?: {
      id?: string;
      name?: string;
      nameByLanguage?: Record<string, string>;
      defaultForLanguages?: string[];
      steps?: RawStep[];
      eastertideSteps?: unknown;
    }[];
  };
  validateDevotionImport(devotion, languages);
  const rawVariants = devotion.variants ?? [];
  if (rawVariants.length > 0 && zip.has("audio.json")) {
    throw new Error(
      "This bundle has recordings tied to its alternate forms — the composer can't edit that combination yet.",
    );
  }

  // Read every step in prayed order first; a days project later hands them back out to its days.
  // Knowing the references up front means unused files in a bloated bundle are never decoded or
  // retained merely because they happen to sit under images/.
  const rawSteps =
    devotion.steps ??
    (rawVariants.length > 0
      ? rawVariants.flatMap((form) => form.steps ?? [])
      : (devotion.days ?? []).flatMap((day) => day.steps));
  const referencedImageKeys = new Set(
    rawSteps.flatMap((step) => (typeof step.imageKey === "string" ? [step.imageKey] : [])),
  );
  const galleryImageKey = manifest.galleryImageKey;
  if (galleryImageKey && !zip.has(`images/${galleryImageKey}.jpg`)) {
    throw new Error("The bundle's Gallery cover image is missing. Nothing has been imported.");
  }

  const project = newProject();
  project.id = manifest.id ?? "";
  project.idEdited = true;
  project.name = manifest.displayName ?? "";
  project.languages = languages as LanguageCode[];
  project.accentColorHex = manifest.accentColorHex ?? project.accentColorHex;
  project.accentColorDarkHex = manifest.accentColorDarkHex ?? project.accentColorDarkHex;
  project.iconSystemName = manifest.iconSystemName ?? project.iconSystemName;
  project.iconGlyph = manifest.iconGlyph ?? "";
  project.tags = Array.isArray(manifest.tags)
    ? manifest.tags.filter((t): t is string => typeof t === "string")
    : [];
  for (const [language, name] of Object.entries(manifest.displayNameByLanguage ?? {})) {
    if (project.languages.includes(language as LanguageCode)) {
      project.nameByLanguage[language as LanguageCode] = name;
    }
  }

  const contentByLanguage = new Map<LanguageCode, Record<string, string>>();
  const transliterationsByLanguage = new Map<LanguageCode, Record<string, string>>();
  const titleKeys = new Set(rawSteps.flatMap((step) => step.titleKey ? [step.titleKey] : []));
  const bodyKeys = new Set(rawSteps.flatMap((step) => step.bodyKey ? [step.bodyKey] : []));
  const contentKeys = new Set([...titleKeys, ...bodyKeys]);
  let hebrewTraditions: Record<string, string> = {};
  for (const language of project.languages) {
    if (!zip.has(`content/${language}.json`)) continue;
    const content = importObject(await zip.json(`content/${language}.json`), `${language} content`);
    importFields(content, ["prayers", "mysteries", "transliterations", "$prayerTraditionByKey"], `${language} content`);
    const prayers = importStringMap(content.prayers ?? {}, `${language} prayers`);
    const transliterations = importStringMap(content.transliterations ?? {}, `${language} reading aids`);
    if (Object.keys(importObject(content.mysteries ?? {}, `${language} mysteries`)).length) {
      unsupportedImport("mystery content");
    }
    for (const [key, text] of Object.entries(prayers)) {
      if (!contentKeys.has(key)) unsupportedImport(`unreferenced prayer content (“${key}” in ${language})`);
      if (!text.trim() || text !== text.trim()) unsupportedImport(`empty or space-padded prayer content (“${key}” in ${language})`);
    }
    for (const [key, text] of Object.entries(transliterations)) {
      if (!bodyKeys.has(key) || !prayers[key]) unsupportedImport(`a reading aid without an editable matching body (“${key}” in ${language})`);
      if (!text.trim() || text !== text.trim()) unsupportedImport(`empty or space-padded reading aids (“${key}” in ${language})`);
    }
    const traditions = importStringMap(content.$prayerTraditionByKey ?? {}, `${language} prayer traditions`);
    for (const [key, tradition] of Object.entries(traditions)) {
      if (language !== "he" || tradition !== "vicariate" || !prayers[key]) {
        unsupportedImport(`unsupported prayer-tradition metadata (“${key}” in ${language})`);
      }
    }
    contentByLanguage.set(language, prayers);
    transliterationsByLanguage.set(language, transliterations);
    if (language === "he") hebrewTraditions = traditions;
  }
  const perLanguage = (key: string | undefined): PerLanguage => {
    const result: PerLanguage = {};
    if (!key) return result;
    for (const [language, prayers] of contentByLanguage) {
      if (prayers[key] !== undefined) result[language] = prayers[key];
    }
    return result;
  };
  const perLanguageTransliteration = (key: string | undefined): PerLanguage => {
    const result: PerLanguage = {};
    if (!key) return result;
    for (const [language, transliterations] of transliterationsByLanguage) {
      if (transliterations[key] !== undefined) result[language] = transliterations[key];
    }
    return result;
  };

  // Uploaded artwork ships inside the zip; anything else is a shared-pool reference.
  const imageUidByKey = new Map<string, string>();
  for (const name of zip.names()) {
    if (!name.startsWith("images/") || name.endsWith("/")) continue;
    // Native readers also accept PNG artwork. The editor writes JPEG only, so never turn
    // a referenced non-JPEG upload into an apparently missing shared-pool image.
    const stem = name.slice("images/".length).replace(/\.[^.]+$/, "");
    if ((referencedImageKeys.has(stem) || stem === galleryImageKey) && !name.endsWith(".jpg")) unsupportedImport("uploaded artwork in a format other than JPEG");
    if (!name.endsWith(".jpg")) continue;
    const key = name.slice("images/".length, -".jpg".length);
    if (!referencedImageKeys.has(key) && key !== galleryImageKey) continue;
    const jpeg = await zip.contents(name, ZIP_LIMITS.imageBytes);
    if (key === galleryImageKey && jpeg.length === 0) {
      throw new Error("The bundle's Gallery cover image is empty. Nothing has been imported.");
    }
    const uid = newUid();
    const portableIdentity = UUID7_PATTERN.test(key);
    const label = key === galleryImageKey ? "Gallery cover" : portableIdentity ? `Image ${project.images.length + 1}` : key;
    const image = { uid, fileId: portableIdentity ? key : newImageFileId(), label, jpeg };
    if (key === galleryImageKey) project.galleryImage = image;
    if (referencedImageKeys.has(key)) {
      imageUidByKey.set(key, uid);
      project.images.push(image);
    }
  }

  // A days project reads back day by day; the content keys were numbered across the whole
  // devotion at pack time, so the flat walk below still lines up.
  if (devotion.type === "days") {
    project.devotionType = "days";
    project.dayProgression = devotion.dayProgression ?? "series";
    if (devotion.suggestedStart) project.suggestedStart = devotion.suggestedStart;
    if (devotion.suggestedReminderTime) project.suggestedReminderTime = devotion.suggestedReminderTime;
    if (devotion.suggestedNext) project.suggestedNext = devotion.suggestedNext;
  }

  // Content keys were numbered across the whole devotion at pack time, so this single walk also
  // keeps day/form content aligned before the arrays are handed back out below.
  const readSteps: EditorStep[] = [];
  for (const raw of rawSteps) {
    const common = raw.bodyKey ? commonPrayer(raw.bodyKey) : undefined;
    const bodies = perLanguage(raw.bodyKey);
    const hasOwnBody = Object.keys(bodies).length > 0;
    // A bundle-local override has precedence over a native common prayer. Preserve a full
    // override as custom content; a sparse override cannot be converted without changing
    // which languages fall through to the app's common prayer.
    const usesCommon = !!common && !hasOwnBody;
    if (usesCommon && raw.titleKey) unsupportedImport("a common prayer with a separately translated title");
    const titles = raw.titleKey ? perLanguage(raw.titleKey)
      : Object.fromEntries(project.languages.map((language) => [language, raw.title!])) as PerLanguage;
    if (!usesCommon && project.languages.some((language) => !bodies[language] || !titles[language])) {
      unsupportedImport("partial translations or sparse common-prayer overrides that depend on native fallback");
    }
    if (!usesCommon && Object.values(titles).some((title) => !title?.trim() || title !== title.trim())) {
      unsupportedImport("empty or space-padded prayer titles");
    }
    const uploadUid = raw.imageKey ? imageUidByKey.get(raw.imageKey) : undefined;
    const image: EditorStep["image"] = uploadUid
      ? { kind: "upload", uid: uploadUid }
      : raw.imageKey && raw.imageKey !== (usesCommon ? common?.image : PLACEHOLDER_IMAGE_KEY)
        ? { kind: "shared", key: raw.imageKey }
        : undefined;
    readSteps.push({
      uid: newUid(),
      kind: usesCommon ? "common" : "custom",
      commonKey: usesCommon ? common?.key as CommonPrayerKey : undefined,
      title: raw.title ?? common?.label ?? "",
      titleByLanguage: usesCommon ? {} : titles,
      bodyByLanguage: usesCommon ? {} : bodies,
      transliterationByLanguage: usesCommon ? {} : perLanguageTransliteration(raw.bodyKey),
      hebrewTitleTradition: raw.titleKey && hebrewTraditions[raw.titleKey] === "vicariate" ? "vicariate" : undefined,
      hebrewBodyTradition: !usesCommon && raw.bodyKey && hebrewTraditions[raw.bodyKey] === "vicariate" ? "vicariate" : undefined,
      image,
      isScripture: raw.isScripture === true,
      repeat: raw.repeat,
    });
  }

  if (devotion.type === "days") {
    let cursor = 0;
    project.days = (devotion.days ?? []).map((day) => {
      const steps = readSteps.slice(cursor, cursor + day.steps.length);
      cursor += day.steps.length;
      return {
        uid: newUid(),
        name: day.name,
        nameByLanguage: (day.nameByLanguage ?? {}) as PerLanguage,
        steps,
      };
    });
  } else if (rawVariants.length > 0) {
    let cursor = 0;
    project.variants = rawVariants.map((form): EditorVariant => {
      const count = (form.steps ?? []).length;
      const steps = readSteps.slice(cursor, cursor + count);
      cursor += count;
      return {
        uid: newUid(),
        variantId: form.id ?? "",
        variantIdEdited: true,
        name: form.name ?? "",
        nameByLanguage: (form.nameByLanguage ?? {}) as PerLanguage,
        defaultForLanguages: (form.defaultForLanguages ?? []).filter(
          (code): code is string => typeof code === "string",
        ),
        steps,
      };
    });
  } else {
    project.steps = readSteps;
  }

  if (zip.has("audio.json")) {
    const audio = importObject(await zip.json("audio.json"), "recordings");
    importFields(audio, ["tracks"], "recording");
    if (!Array.isArray(audio.tracks)) unsupportedImport("an invalid recording list");
    const audioBytesByFile = new Map<string, Uint8Array>();
    const languageCounts = new Map<string, number>();
    for (const item of audio.tracks) {
      const track = importObject(item, "recording");
      importFields(track, ["id", "language", "file", "chapters"], "recording");
      const language = importString(track.language, "recording language") as LanguageCode;
      if (!project.languages.includes(language)) unsupportedImport("a recording in a language outside the bundle's language list");
      const count = (languageCounts.get(language) ?? 0) + 1;
      languageCounts.set(language, count);
      const expectedId = count === 1 ? language : `${language}-${count}`;
      // Track identities are persisted by the apps in audio bookmarks. The editor currently
      // derives IDs from language/order, so decline identities it would silently rename.
      if (track.id !== expectedId) unsupportedImport("custom recording identities");
      const file = importString(track.file, "recording file");
      if (!file.startsWith("audio/") || !file.endsWith(".opus") || !zip.has(file)) {
        unsupportedImport("a missing recording file or a recording format other than Opus");
      }
      if (!Array.isArray(track.chapters)) unsupportedImport("a recording without editable chapter markers");
      const chapters = track.chapters.map((item) => {
        const chapter = importObject(item, "recording chapter");
        importFields(chapter, ["start", "stepIndex", "title", "titleKey"], "recording chapter");
        if (typeof chapter.start !== "number" || !Number.isFinite(chapter.start) || chapter.start < 0) {
          unsupportedImport("an invalid recording chapter time");
        }
        if (typeof chapter.stepIndex !== "number" || !Number.isSafeInteger(chapter.stepIndex) || chapter.stepIndex < 0) {
          unsupportedImport("a recording chapter without an exact prayer-step reference");
        }
        const index = authoredIndexForBuilt(readSteps, chapter.stepIndex);
        if (index < 0) unsupportedImport("a recording chapter inside a repeated prayer or outside the prayer sequence");
        const raw = rawSteps[index];
        if (chapter.title !== raw.title || chapter.titleKey !== raw.titleKey) {
          unsupportedImport("custom recording chapter labels independent of prayer titles");
        }
        return { start: chapter.start, stepUid: readSteps[index].uid };
      });
      let bytes = audioBytesByFile.get(file);
      if (!bytes) {
        bytes = await zip.contents(file, ZIP_LIMITS.audioBytes);
        audioBytesByFile.set(file, bytes);
      }
      project.audio.push({
        uid: newUid(),
        language,
        fileName: file.slice("audio/".length),
        bytes,
        chapters,
      });
    }
  }

  return pruneUnusedImages(project);
}

/** Only the first repetition is representable by an editor chapter. Do not round an
 * interior or out-of-range bookmark to a different prayer position. */
function authoredIndexForBuilt(steps: EditorStep[], builtIndex: number): number {
  let cursor = 0;
  for (let i = 0; i < steps.length; i++) {
    const span = Math.max(steps[i].repeat ?? 1, 1);
    if (builtIndex === cursor) return i;
    cursor += span;
  }
  return -1;
}

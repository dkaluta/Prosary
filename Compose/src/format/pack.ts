// Project -> .prosaryprayer bundle files. The output must satisfy both the apps'
// PrayerPackStore.installPack checks and Shared/tools/validate-devotion.py — the shell packer
// and this module are two writers of one format, with ARCHITECTURE.markdown's "Content bundles" as
// the spec.

import { COMMON_PRAYERS, PLACEHOLDER_IMAGE_KEY, commonPrayer } from "./catalog";
import type { EditorStep, Project } from "./project";
import { projectSteps, slugify } from "./project";
import { buildZip, type ZipFile } from "./zip";
import { UUID7_PATTERN } from "./imageIdentity";
import { isSdrSrgbJpeg } from "./jpegColor";

/** Bundle-local content key base for the i-th step ("step03"). */
function stepKeyBase(index: number): string {
  return `step${String(index + 1).padStart(2, "0")}`;
}

/** Uploaded step artwork has a persisted UUIDv7 key; shared illustrations retain their keys. */
function imageKey(project: Project, uid: string): string | undefined {
  return project.images.find((image) => image.uid === uid)?.fileId;
}

/** The imageKey a step's devotion.json entry carries. */
export function stepImageKey(project: Project, step: EditorStep): string {
  if (step.image?.kind === "upload") {
    const key = imageKey(project, step.image.uid);
    if (key) return key;
  }
  if (step.image?.kind === "shared") return step.image.key;
  if (step.kind === "common" && step.commonKey) {
    return commonPrayer(step.commonKey)?.image ?? PLACEHOLDER_IMAGE_KEY;
  }
  return PLACEHOLDER_IMAGE_KEY;
}

/** The chapter label for a step: common prayers get the literal English title (the app-wide
 * step-title convention), custom steps their translated titleKey. */
function chapterTitle(step: EditorStep, index: number): { title?: string; titleKey?: string } {
  return step.kind === "custom" ? { titleKey: `${stepKeyBase(index)}Title` } : { title: step.title };
}

/** Built-sequence index of the i-th authored step. The apps' engines expand `repeat: n` into
 * n consecutive built steps, and chapters' advisory stepIndex hints point into that BUILT
 * sequence — an authored index would land every post-repeat chapter on the wrong page. A
 * repeated step's chapter points at its first repetition. */
/** Every authored step in order, whichever project type it is — days projects number their
 * content keys across the whole devotion so a step's key never shifts when a day is edited. */
export function authoredSteps(project: Project): EditorStep[] {
  return projectSteps(project);
}

/** One step's devotion.json entry; identical in both project types. */
function packStep(
  project: Project,
  step: EditorStep,
  index: number,
  imageKeysByUid: ReadonlyMap<string, string>,
) {
  return {
    ...(step.kind === "custom" ? { titleKey: `${stepKeyBase(index)}Title` } : { title: step.title }),
    bodyKey: step.kind === "common" ? step.commonKey : `${stepKeyBase(index)}Body`,
    imageKey:
      step.image?.kind === "upload"
        ? imageKeysByUid.get(step.image.uid) ?? PLACEHOLDER_IMAGE_KEY
        : stepImageKey(project, step),
    ...(step.isScripture ? { isScripture: true } : {}),
    ...(step.repeat && step.repeat >= 2 ? { repeat: step.repeat } : {}),
  };
}

export function builtStepIndex(steps: EditorStep[], authoredIndex: number): number {
  let built = 0;
  for (let i = 0; i < authoredIndex && i < steps.length; i++) {
    built += Math.max(steps[i].repeat ?? 1, 1);
  }
  return built;
}

function jsonBytes(value: unknown): Uint8Array {
  return new TextEncoder().encode(JSON.stringify(value, null, 2) + "\n");
}

export function buildBundleFiles(project: Project): ZipFile[] {
  const files: ZipFile[] = [];
  const allSteps = authoredSteps(project);
  const stepIndexes = new Map(allSteps.map((step, index) => [step, index] as const));
  const activeImageUids = new Set(
    allSteps.flatMap((step) =>
      step.image?.kind === "upload" ? [step.image.uid] : [],
    ),
  );
  const activeImages = project.images.filter((image) => activeImageUids.has(image.uid));
  if ([...activeImages, ...(project.galleryImage ? [project.galleryImage] : [])].some((image) => !isSdrSrgbJpeg(image.jpeg))) {
    throw new Error("Prepare the artwork in Compose before exporting: new images must be standard-color JPEGs.");
  }
  const imageKeysByUid = new Map(
    activeImages.map(
      (image) => {
        if (!image.fileId || !UUID7_PATTERN.test(image.fileId)) {
          throw new Error("This artwork has no portable image identity. Save and reopen the project before exporting.");
        }
        return [image.uid, image.fileId] as const;
      },
    ),
  );
  const usedMainKeys = COMMON_PRAYERS.filter(
    (p) => p.main && allSteps.some((s) => s.kind === "common" && s.commonKey === p.key),
  ).map((p) => p.key);
  const usedImageKeys: string[] = [];
  const seenImageKeys = new Set<string>();
  for (const step of allSteps) {
    const key = step.image?.kind === "upload" ? imageKeysByUid.get(step.image.uid) : undefined;
    if (key && !seenImageKeys.has(key)) {
      seenImageKeys.add(key);
      usedImageKeys.push(key);
    }
  }
  const galleryImage = project.galleryImage;
  // The default cover is pack-scoped. Steps must use UUID keys even when their
  // bytes match the cover, because native step artwork also has a shared pool.
  const galleryImageKey = galleryImage ? "default" : undefined;
  if (galleryImageKey && !seenImageKeys.has(galleryImageKey)) {
    usedImageKeys.push(galleryImageKey);
    seenImageKeys.add(galleryImageKey);
    files.push({ name: `images/${galleryImageKey}.jpg`, data: galleryImage!.jpeg });
  }

  const nameByLanguage = Object.fromEntries(
    Object.entries(project.nameByLanguage).filter(([, v]) => v?.trim()),
  );
  files.push({
    name: "manifest.json",
    data: jsonBytes({
      schemaVersion: 1,
      id: project.id,
      kind: project.id,
      displayName: project.name,
      languages: project.languages,
      hasCatalog: false,
      images: usedImageKeys,
      ...(galleryImageKey ? { galleryImageKey } : {}),
      ...(usedMainKeys.length > 0 ? { mainPrayerKeysOmitted: usedMainKeys } : {}),
      ...(project.tags.length > 0 ? { tags: project.tags } : {}),
      ...(Object.keys(nameByLanguage).length > 0 ? { displayNameByLanguage: nameByLanguage } : {}),
      accentColorHex: project.accentColorHex,
      accentColorDarkHex: project.accentColorDarkHex,
      iconSystemName: project.iconSystemName,
      ...(project.iconGlyph ? { iconGlyph: project.iconGlyph } : {}),
    }),
  });

  // A days project carries its steps inside days[]; the entry shape is identical, so the same
  // key numbering runs across every day (see authoredSteps).
  const devotionBody =
    project.devotionType === "days"
      ? {
          type: "days" as const,
          dayProgression: project.dayProgression,
          ...(project.suggestedStart ? { suggestedStart: project.suggestedStart } : {}),
          ...(project.suggestedReminderTime
            ? { suggestedReminderTime: project.suggestedReminderTime }
            : {}),
          ...(project.suggestedNext ? { suggestedNext: project.suggestedNext } : {}),
          days: project.days.map((day) => ({
            name: day.name,
            ...(Object.keys(day.nameByLanguage).length
              ? { nameByLanguage: day.nameByLanguage }
              : {}),
            steps: day.steps.map((step) =>
              packStep(project, step, stepIndexes.get(step) ?? 0, imageKeysByUid),
            ),
          })),
        }
      : project.variants.length > 0
        ? {
            type: "steps" as const,
            variants: project.variants.map((form) => {
              const nameByLanguage = Object.fromEntries(
                Object.entries(form.nameByLanguage).filter(([, v]) => v?.trim()),
              );
              return {
                id: form.variantId || slugify(form.name),
                name: form.name,
                ...(Object.keys(nameByLanguage).length > 0 ? { nameByLanguage } : {}),
                ...(form.defaultForLanguages.length > 0
                  ? { defaultForLanguages: form.defaultForLanguages }
                  : {}),
                steps: form.steps.map((step) =>
                  packStep(project, step, stepIndexes.get(step) ?? 0, imageKeysByUid),
                ),
              };
            }),
          }
        : {
          type: "steps" as const,
          steps: project.steps.map((step, i) => packStep(project, step, i, imageKeysByUid)),
        };

  files.push({
    name: "devotion.json",
    data: jsonBytes(devotionBody),
  });


  for (const language of project.languages) {
    const prayers: Record<string, string> = {};
    const transliterations: Record<string, string> = {};
    const prayerTraditionByKey: Record<string, "vicariate"> = {};
    allSteps.forEach((step, i) => {
      if (step.kind !== "custom") return;
      prayers[`${stepKeyBase(i)}Title`] = step.titleByLanguage[language]?.trim() ?? "";
      prayers[`${stepKeyBase(i)}Body`] = step.bodyByLanguage[language]?.trim() ?? "";
      const transliteration = step.transliterationByLanguage?.[language]?.trim();
      if (transliteration) transliterations[`${stepKeyBase(i)}Body`] = transliteration;
      if (language === "he") {
        if (step.hebrewTitleTradition) prayerTraditionByKey[`${stepKeyBase(i)}Title`] = step.hebrewTitleTradition;
        if (step.hebrewBodyTradition) prayerTraditionByKey[`${stepKeyBase(i)}Body`] = step.hebrewBodyTradition;
      }
    });
    files.push({
      name: `content/${language}.json`,
      data: jsonBytes({
        prayers,
        mysteries: {},
        ...(Object.keys(transliterations).length > 0 ? { transliterations } : {}),
        ...(Object.keys(prayerTraditionByKey).length > 0 ? { $prayerTraditionByKey: prayerTraditionByKey } : {}),
      }),
    });
  }

  for (const image of activeImages) {
    const key = imageKeysByUid.get(image.uid);
    if (key && seenImageKeys.has(key)) {
      files.push({ name: `images/${key}.jpg`, data: image.jpeg });
    }
  }

  if (project.audio.length > 0) {
    const languageCounts = new Map<string, number>();
    const tracks = project.audio.map((track) => {
      const n = (languageCounts.get(track.language) ?? 0) + 1;
      languageCounts.set(track.language, n);
      const id = n === 1 ? track.language : `${track.language}-${n}`;
      const file = `audio/${id}.opus`;
      files.push({ name: file, data: track.bytes });
      return {
        id,
        language: track.language,
        file,
        chapters: track.chapters.map((chapter) => {
          const index = allSteps.findIndex((s) => s.uid === chapter.stepUid);
          const step = allSteps[index];
          return {
            start: chapter.start,
            ...(step ? chapterTitle(step, index) : { title: "Chapter" }),
            ...(index >= 0 ? { stepIndex: builtStepIndex(allSteps, index) } : {}),
          };
        }),
      };
    });
    files.push({ name: "audio.json", data: jsonBytes({ tracks }) });
  }

  return files;
}

export function buildBundle(project: Project): Uint8Array {
  return buildZip(buildBundleFiles(project));
}

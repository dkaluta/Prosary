// Project -> .prosaryprayer bundle files. The output must satisfy both the apps'
// PrayerPackStore.installPack checks and Shared/tools/validate-devotion.py — the shell packer
// and this module are two writers of one format, with ARCHITECTURE.md's "Content bundles" as
// the spec.

import { COMMON_PRAYERS, PLACEHOLDER_IMAGE_KEY, commonPrayer } from "./catalog";
import type { EditorStep, Project } from "./project";
import { usedPrayers } from "./project";
import { buildZip, type ZipFile } from "./zip";

/** Bundle-local content key base per library prayer ("prayer03"). Only prayers some step
 * actually prays get a key and ship; steps praying the same prayer share its bodyKey/titleKey,
 * exactly like the built-in bundles' repeated acclamations (the Trisagion's five steps). */
function prayerKeyBases(project: Project): Map<string, string> {
  const bases = new Map<string, string>();
  usedPrayers(project).forEach((prayer, index) => {
    bases.set(prayer.uid, `prayer${String(index + 1).padStart(2, "0")}`);
  });
  return bases;
}

/** The zip-shipped key for the i-th uploaded image, namespaced by bundle id so a user upload
 * can never collide with (and override) a shared-pool key like "our_father". */
function imageKey(project: Project, uid: string): string | undefined {
  const index = project.images.findIndex((image) => image.uid === uid);
  return index < 0 ? undefined : `${project.id}_art_${String(index + 1).padStart(2, "0")}`;
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

function jsonBytes(value: unknown): Uint8Array {
  return new TextEncoder().encode(JSON.stringify(value, null, 2) + "\n");
}

export function buildBundleFiles(project: Project): ZipFile[] {
  const files: ZipFile[] = [];
  const keyBases = prayerKeyBases(project);
  const usedMainKeys = COMMON_PRAYERS.filter(
    (p) => p.main && project.steps.some((s) => s.kind === "common" && s.commonKey === p.key),
  ).map((p) => p.key);
  const usedImageKeys = [
    ...new Set(
      project.steps
        .map((step) => (step.image?.kind === "upload" ? imageKey(project, step.image.uid) : undefined))
        .filter((key): key is string => key !== undefined),
    ),
  ];

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
      ...(usedMainKeys.length > 0 ? { mainPrayerKeysOmitted: usedMainKeys } : {}),
      ...(Object.keys(nameByLanguage).length > 0 ? { displayNameByLanguage: nameByLanguage } : {}),
      accentColorHex: project.accentColorHex,
      accentColorDarkHex: project.accentColorDarkHex,
      iconSystemName: project.iconSystemName,
    }),
  });

  files.push({
    name: "devotion.json",
    data: jsonBytes({
      type: "steps",
      steps: project.steps.map((step) => {
        const base = step.prayerUid ? keyBases.get(step.prayerUid) : undefined;
        const prayer = project.prayers.find((p) => p.uid === step.prayerUid);
        return {
          ...(step.kind === "common"
            ? { title: commonPrayer(step.commonKey ?? "")?.label ?? "Prayer", bodyKey: step.commonKey }
            : { titleKey: `${base}Title`, bodyKey: `${base}Body` }),
          imageKey: stepImageKey(project, step),
          ...(step.kind === "own" && prayer?.isScripture ? { isScripture: true } : {}),
          ...(step.repeat && step.repeat >= 2 ? { repeat: step.repeat } : {}),
        };
      }),
    }),
  });

  for (const language of project.languages) {
    const prayers: Record<string, string> = {};
    for (const prayer of usedPrayers(project)) {
      const base = keyBases.get(prayer.uid)!;
      prayers[`${base}Title`] = prayer.titleByLanguage[language]?.trim() ?? "";
      prayers[`${base}Body`] = prayer.bodyByLanguage[language]?.trim() ?? "";
    }
    files.push({ name: `content/${language}.json`, data: jsonBytes({ prayers, mysteries: {} }) });
  }

  for (const image of project.images) {
    const key = imageKey(project, image.uid);
    if (key && usedImageKeys.includes(key)) {
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
          const index = project.steps.findIndex((s) => s.uid === chapter.stepUid);
          const step = project.steps[index];
          const base = step?.prayerUid ? keyBases.get(step.prayerUid) : undefined;
          return {
            start: chapter.start,
            ...(step?.kind === "own" && base
              ? { titleKey: `${base}Title` }
              : { title: step ? commonPrayer(step.commonKey ?? "")?.label ?? "Prayer" : "Chapter" }),
            ...(index >= 0 ? { stepIndex: index } : {}),
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

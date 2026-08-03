// .prosaryprayer -> Project, the best-effort inverse of pack.ts so an author can reopen and
// keep editing a bundle. Only the wizard's own subset round-trips: flat steps-type devotions
// (what this composer emits). Anything richer — rosary/days types, variants, options — is
// declined with a plain-language message rather than silently flattened.

import type { CommonPrayerKey, LanguageCode } from "./catalog";
import { LANGUAGES, PLACEHOLDER_IMAGE_KEY, commonPrayer } from "./catalog";
import type { EditorStep, PerLanguage, Project } from "./project";
import { newProject, newUid } from "./project";
import { ZipReader } from "./zip";

interface RawStep {
  title?: string;
  titleKey?: string;
  bodyKey?: string;
  imageKey?: string;
  isScripture?: boolean;
  repeat?: number;
  kind?: string;
  if?: string;
  acclamationKey?: string;
  subtitle?: string;
  subtitleKey?: string;
}

function bytesToDataUrl(bytes: Uint8Array, mime: string): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return `data:${mime};base64,${btoa(binary)}`;
}

export async function openBundle(bytes: Uint8Array): Promise<Project> {
  let zip: ZipReader;
  try {
    zip = ZipReader.open(bytes);
  } catch {
    throw new Error("This file is not a readable .prosaryprayer bundle.");
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
  };
  if (!zip.has("devotion.json")) {
    throw new Error("This bundle has no prayer steps the composer can edit.");
  }
  const devotion = (await zip.json("devotion.json")) as {
    type?: string;
    steps?: RawStep[];
    eastertideSteps?: unknown;
    variants?: unknown;
  };
  if (devotion.type !== "steps" || devotion.variants || devotion.eastertideSteps) {
    throw new Error(
      "This bundle uses a richer structure (beads, variants, or seasonal forms) than the composer can edit yet.",
    );
  }

  const project = newProject();
  project.id = manifest.id ?? "";
  project.idEdited = true;
  project.name = manifest.displayName ?? "";
  project.languages = (manifest.languages ?? []).filter((l): l is LanguageCode =>
    LANGUAGES.some((known) => known.code === l),
  );
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
  for (const language of project.languages) {
    if (!zip.has(`content/${language}.json`)) continue;
    const content = (await zip.json(`content/${language}.json`)) as { prayers?: Record<string, string> };
    contentByLanguage.set(language, content.prayers ?? {});
  }
  const perLanguage = (key: string | undefined): PerLanguage => {
    const result: PerLanguage = {};
    if (!key) return result;
    for (const [language, prayers] of contentByLanguage) {
      if (prayers[key] !== undefined) result[language] = prayers[key];
    }
    return result;
  };

  // Uploaded artwork ships inside the zip; anything else is a shared-pool reference.
  const imageUidByKey = new Map<string, string>();
  for (const name of zip.names()) {
    if (!name.startsWith("images/") || !name.endsWith(".jpg")) continue;
    const key = name.slice("images/".length, -".jpg".length);
    const jpeg = await zip.contents(name);
    const uid = newUid();
    imageUidByKey.set(key, uid);
    project.images.push({ uid, label: key, jpeg, dataUrl: bytesToDataUrl(jpeg, "image/jpeg") });
  }

  for (const raw of devotion.steps ?? []) {
    if (raw.kind) {
      throw new Error("This bundle uses a special step the composer can't edit yet.");
    }
    const common = raw.bodyKey ? commonPrayer(raw.bodyKey) : undefined;
    const uploadUid = raw.imageKey ? imageUidByKey.get(raw.imageKey) : undefined;
    const image: EditorStep["image"] = uploadUid
      ? { kind: "upload", uid: uploadUid }
      : raw.imageKey &&
          raw.imageKey !== PLACEHOLDER_IMAGE_KEY &&
          raw.imageKey !== (common?.image ?? PLACEHOLDER_IMAGE_KEY)
        ? { kind: "shared", key: raw.imageKey }
        : undefined;
    project.steps.push({
      uid: newUid(),
      kind: common ? "common" : "custom",
      commonKey: common?.key as CommonPrayerKey | undefined,
      title: raw.title ?? common?.label ?? "",
      titleByLanguage: perLanguage(raw.titleKey),
      bodyByLanguage: common ? {} : perLanguage(raw.bodyKey),
      image,
      isScripture: raw.isScripture === true,
      repeat: raw.repeat,
    });
  }

  if (zip.has("audio.json")) {
    const audio = (await zip.json("audio.json")) as {
      tracks?: {
        id?: string;
        language?: string;
        file?: string;
        chapters?: { start?: number; stepIndex?: number }[];
      }[];
    };
    for (const track of audio.tracks ?? []) {
      if (!track.file || !zip.has(track.file)) continue;
      const language = project.languages.includes(track.language as LanguageCode)
        ? (track.language as LanguageCode)
        : project.languages[0];
      if (!language) continue;
      project.audio.push({
        uid: newUid(),
        language,
        fileName: track.file.slice("audio/".length),
        bytes: await zip.contents(track.file),
        chapters: (track.chapters ?? []).map((chapter) => ({
          start: chapter.start ?? 0,
          // stepIndex hints point into the BUILT sequence (repeat-expanded) — invert the
          // expansion to find the authored step the hint falls inside.
          stepUid:
            project.steps[authoredIndexForBuilt(project.steps, chapter.stepIndex ?? 0)]?.uid ??
            project.steps[0]?.uid ??
            "",
        })),
      });
    }
  }

  return project;
}

/** Inverse of pack.ts's builtStepIndex: the authored step whose repeat-expanded span contains
 * the given built-sequence index. */
function authoredIndexForBuilt(steps: Project["steps"], builtIndex: number): number {
  let cursor = 0;
  for (let i = 0; i < steps.length; i++) {
    const span = Math.max(steps[i].repeat ?? 1, 1);
    if (builtIndex < cursor + span) return i;
    cursor += span;
  }
  return Math.max(steps.length - 1, 0);
}

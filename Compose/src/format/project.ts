// The editor's working state — what the wizard screens read and write. `pack.ts` turns a
// Project into .prosaryprayer bundle files; `unpack.ts` does the reverse for editing an
// existing bundle. Portable project files encode binary payloads as base64; browser autosaves
// keep the native bytes in IndexedDB so ordinary typing never re-encodes large media.

import type { CommonPrayerKey, LanguageCode } from "./catalog";

export type PerLanguage = Partial<Record<LanguageCode, string>>;

/** One step of the devotion as authored. */
export interface EditorStep {
  uid: string;
  /** "common": a prayer every app already carries (referenced by key, text never bundled).
   * "custom": the author's own text, written per language. */
  kind: "common" | "custom";
  commonKey?: CommonPrayerKey;
  /** English display label (the app-wide convention for step titles). */
  title: string;
  /** Custom steps only: translated titles, emitted as bundle-local titleKey content. */
  titleByLanguage: PerLanguage;
  /** Custom steps only: the prayer text per language. */
  bodyByLanguage: PerLanguage;
  /** Custom steps only, optional (v0.7): the prayer transliterated into another script, per
   * language — a reading aid for praying along in a script one can't read. */
  transliterationByLanguage?: PerLanguage;
  /** Source provenance retained through import/export; plain repository Hebrew stays generic. */
  hebrewTitleTradition?: "vicariate";
  hebrewBodyTradition?: "vicariate";
  /** Artwork: the author's own upload, or one of the app's shared illustrations. Absent =
   * the step's default (the common prayer's traditional image, or the cross placeholder). */
  image?: { kind: "upload"; uid: string } | { kind: "shared"; key: string };
  /** The body is quoted Scripture, so the apps render it in the scripture typeface. */
  isScripture: boolean;
  /** Pray this step n times in a row (emitted as the format's `repeat`, n >= 2). */
  repeat?: number;
}

/** An uploaded illustration, already center-cropped square and re-encoded as JPEG. */
export interface EditorImage {
  uid: string;
  label: string;
  jpeg: Uint8Array;
}

/** A narrated recording (Ogg Opus) with its chapter seek points. */
export interface EditorAudioTrack {
  uid: string;
  language: LanguageCode;
  fileName: string;
  bytes: Uint8Array;
  /** Chapters point at authored steps; titles derive from the step at pack time. */
  chapters: { start: number; stepUid: string }[];
}

/** One named alternate form of a steps devotion — the Stations' traditional vs. scriptural
 * sets, a Trisagion's Byzantine vs. Syriac. Its steps are authored exactly like a single-form
 * devotion's; the first form is the default. */
export interface EditorVariant {
  uid: string;
  /** Bundle variant id ("byzantine") — fills in from the name until edited by hand, and is
   * preserved on round-trip so a republish never breaks a favorite's saved choice. */
  variantId: string;
  variantIdEdited: boolean;
  /** English display label (the app-wide convention). */
  name: string;
  nameByLanguage: PerLanguage;
  /** Exact prayer-language codes (rites included, e.g. "he-x-gamliel") whose sessions open in
   * this form when the pray-er hasn't chosen one — see the format's defaultForLanguages. */
  defaultForLanguages: string[];
  steps: EditorStep[];
}

/** A day of a multi-day devotion: a novena's nine, a triduum's three. Its steps are authored
 * exactly like a single-day devotion's. */
export interface EditorDay {
  uid: string;
  /** English label ("Day 1", "First Day of the Novena"). */
  name: string;
  nameByLanguage: PerLanguage;
  steps: EditorStep[];
}

/** How a multi-day devotion's days relate — see Shared/schema/domain-model.json. */
export type DayProgression = "series" | "free";

export interface Project {
  name: string;
  nameByLanguage: PerLanguage;
  id: string;
  /** Once the author edits the id by hand it stops tracking the name. */
  idEdited: boolean;
  languages: LanguageCode[];
  accentColorHex: string;
  accentColorDarkHex: string;
  iconSystemName: string;
  /** One grapheme (a letter or emoji) drawn as the devotion's icon instead of the fixed icon
   * set — Gamaliel item 6. Empty string = use iconSystemName. */
  iconGlyph: string;
  /** Free-form category tags ("marian", "evening") — packed into the manifest and used as
   * the repository's default tags on submission; the apps group and search devotions by them. */
  tags: string[];
  /** "steps" — one sequence — or "days", a multi-day devotion. A days project authors its
   * steps inside `days` and leaves `steps` empty. */
  devotionType: "steps" | "days";
  steps: EditorStep[];
  /** steps type only: alternate forms. Empty = a single-form devotion using `steps`; non-empty
   * means each form carries its own steps and `steps` is unused. */
  variants: EditorVariant[];
  /** days type only. */
  days: EditorDay[];
  /** days type only: consecutive series (tracked, remindable) or a set to pick from. */
  dayProgression: DayProgression;
  /** days/series only, all advisory — the apps treat them as suggestions. */
  suggestedStart?: string;
  suggestedReminderTime?: string;
  suggestedNext?: string;
  images: EditorImage[];
  audio: EditorAudioTrack[];
}

export function newUid(): string {
  return globalThis.crypto?.randomUUID?.() ?? Math.random().toString(36).slice(2, 10);
}

export function newProject(): Project {
  return {
    name: "",
    nameByLanguage: {},
    id: "",
    idEdited: false,
    languages: ["la", "en"],
    accentColorHex: "#7A1F3D",
    accentColorDarkHex: "#D8A8B5",
    iconSystemName: "star",
    iconGlyph: "",
    tags: [],
    devotionType: "steps",
    steps: [],
    variants: [],
    days: [],
    dayProgression: "series",
    images: [],
    audio: [],
  };
}

/** Every step that belongs to the project's active shape. */
export function projectSteps(project: Project): EditorStep[] {
  if (project.devotionType === "days") return project.days.flatMap((day) => day.steps);
  if (project.variants.length > 0) return project.variants.flatMap((form) => form.steps);
  return project.steps;
}

function retainedProjectSteps(project: Project): EditorStep[] {
  return [
    ...project.steps,
    ...project.variants.flatMap((form) => form.steps),
    ...project.days.flatMap((day) => day.steps),
  ];
}

/** Attach a converted upload and its step reference as one state transition. Replacing existing
 * art keeps its uid, so IndexedDB updates one binary record rather than briefly duplicating it. */
export function attachUploadedArtwork(
  project: Project,
  stepUid: string,
  label: string,
  jpeg: Uint8Array,
): Project {
  const target = retainedProjectSteps(project).find((step) => step.uid === stepUid);
  if (!target) return project;
  const imageUid = target.image?.kind === "upload" ? target.image.uid : newUid();
  const replaceIn = (steps: EditorStep[]) =>
    steps.map((step) =>
      step.uid === stepUid
        ? { ...step, image: { kind: "upload" as const, uid: imageUid } }
        : step,
    );
  const existingImage = project.images.some((image) => image.uid === imageUid);
  return {
    ...project,
    steps: replaceIn(project.steps),
    variants: project.variants.map((form) => ({ ...form, steps: replaceIn(form.steps) })),
    days: project.days.map((day) => ({ ...day, steps: replaceIn(day.steps) })),
    images: existingImage
      ? project.images.map((image) =>
          image.uid === imageUid ? { ...image, label, jpeg } : image,
        )
      : [...project.images, { uid: imageUid, label, jpeg }],
  };
}

/** Replace a recording's media without changing the stable uid used by IndexedDB. */
export function replaceAudioTrackMedia(
  project: Project,
  trackUid: string,
  fileName: string,
  bytes: Uint8Array,
): Project {
  if (!project.audio.some((track) => track.uid === trackUid)) return project;
  return {
    ...project,
    audio: project.audio.map((track) =>
      track.uid === trackUid ? { ...track, fileName, bytes } : track,
    ),
  };
}

/** Drop uploaded image payloads that no retained step references. All three containers matter here:
 * changing shape intentionally preserves the inactive work so an author can switch back, and
 * multiple base steps/days/forms may deliberately share one upload. */
export function pruneUnusedImages(project: Project): Project {
  if (project.images.length === 0) return project;
  const referenced = new Set<string>();
  for (const step of retainedProjectSteps(project)) {
    if (step.image?.kind === "upload") referenced.add(step.image.uid);
  }
  const images = project.images.filter((image) => referenced.has(image.uid));
  return images.length === project.images.length ? project : { ...project, images };
}

/** "My Little Devotion" -> "myLittleDevotion" — bundle ids are camelCase like the built-ins'. */
export function slugify(name: string): string {
  const words = name
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-zA-Z0-9]+/g, " ")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (words.length === 0) return "";
  return words
    .map((w, i) => (i === 0 ? w.toLowerCase() : w[0].toUpperCase() + w.slice(1).toLowerCase()))
    .join("");
}

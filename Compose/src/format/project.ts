// The editor's working state — what the wizard screens read and write. `pack.ts` turns a
// Project into .prosaryprayer bundle files; `unpack.ts` does the reverse for editing an
// existing bundle. Kept JSON-serializable (binary payloads as base64 when saved) so a project
// can round-trip through localStorage autosave and "Save project" files.

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
  /** data: URL of `jpeg`, for previews. */
  dataUrl: string;
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
  return Math.random().toString(36).slice(2, 10);
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

// --- Project file / autosave serialization (binary as base64) ---

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

function fromBase64(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

export function serializeProject(project: Project): string {
  return JSON.stringify({
    prosaryCompose: 1,
    ...project,
    images: project.images.map((image) => ({ ...image, jpeg: toBase64(image.jpeg) })),
    audio: project.audio.map((track) => ({ ...track, bytes: toBase64(track.bytes) })),
  });
}

export function deserializeProject(json: string): Project {
  const raw = JSON.parse(json);
  if (raw?.prosaryCompose !== 1) throw new Error("Not a Prosary Compose project file.");
  const { prosaryCompose: _, ...rest } = raw;
  return {
    // Every field a saved project might predate, defaulted in one go. A project saved before a
    // feature landed simply has no key for it — and the screens read those keys without asking.
    // This used to name `iconGlyph` alone, so when multi-day authoring added `days`, every
    // autosave written before it restored with `days: undefined`, and opening the Prayers screen
    // threw on `.find` and left a blank page: the bad state sits in the browser, so it followed
    // the one person who had it and no clean profile could reproduce it. Spreading the real
    // defaults means the next field costs nothing to remember.
    ...newProject(),
    ...rest,
    images: (rest.images ?? []).map((image: EditorImage & { jpeg: string }) => {
      const jpeg = fromBase64(image.jpeg);
      return { ...image, jpeg };
    }),
    audio: (rest.audio ?? []).map((track: EditorAudioTrack & { bytes: string }) => ({
      ...track,
      bytes: fromBase64(track.bytes),
    })),
  };
}

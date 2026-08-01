// The editor's working state — what the wizard screens read and write. `pack.ts` turns a
// Project into .prosaryprayer bundle files; `unpack.ts` does the reverse for editing an
// existing bundle. Kept JSON-serializable (binary payloads as base64 when saved) so a project
// can round-trip through localStorage autosave and "Save project" files.

import type { CommonPrayerKey, LanguageCode } from "./catalog";

export type PerLanguage = Partial<Record<LanguageCode, string>>;

/**
 * One prayer the author wrote, independent of where it appears — the editor's counterpart of
 * a bundle-local content key. Several steps may pray the same prayer (the Trisagion prays its
 * acclamation five times), which is why texts live here and the sequence in [EditorStep].
 */
export interface EditorPrayer {
  uid: string;
  /** The prayer's name per language, emitted as its steps' titleKey content. */
  titleByLanguage: PerLanguage;
  /** The prayer text per language, emitted as the shared bodyKey content. */
  bodyByLanguage: PerLanguage;
  /** The text is quoted Scripture, so the apps render it in the scripture typeface —
   * emitted as isScripture on every step that prays it. */
  isScripture: boolean;
}

/** One step of the devotion's sequence. */
export interface EditorStep {
  uid: string;
  /** "common": a prayer every app already carries (referenced by key, text never bundled).
   * "own": one of the author's prayers from the project's library. */
  kind: "common" | "own";
  commonKey?: CommonPrayerKey;
  prayerUid?: string;
  /** Artwork: the author's own upload, or one of the app's shared illustrations. Absent =
   * the step's default (the common prayer's traditional image, or the cross placeholder). */
  image?: { kind: "upload"; uid: string } | { kind: "shared"; key: string };
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
  prayers: EditorPrayer[];
  steps: EditorStep[];
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
    prayers: [],
    steps: [],
    images: [],
    audio: [],
  };
}

/** The prayers actually prayed by at least one step — the ones a bundle ships. */
export function usedPrayers(project: Project): EditorPrayer[] {
  return project.prayers.filter((prayer) =>
    project.steps.some((step) => step.kind === "own" && step.prayerUid === prayer.uid),
  );
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
    prosaryCompose: 2,
    ...project,
    images: project.images.map((image) => ({ ...image, jpeg: toBase64(image.jpeg) })),
    audio: project.audio.map((track) => ({ ...track, bytes: toBase64(track.bytes) })),
  });
}

/** Version-1 projects stored each custom step's text inline; version 2 moved the texts into
 * the prayer library. Old autosaves/project files migrate to one prayer per old step. */
function migrateV1(project: Project): Project {
  interface V1Step extends EditorStep {
    titleByLanguage?: PerLanguage;
    bodyByLanguage?: PerLanguage;
    isScripture?: boolean;
  }
  const prayers: EditorPrayer[] = [];
  const steps = (project.steps as V1Step[]).map((step) => {
    const { titleByLanguage, bodyByLanguage, isScripture, ...bare } = step;
    if ((step.kind as string) !== "custom") return bare;
    const prayer: EditorPrayer = {
      uid: newUid(),
      titleByLanguage: titleByLanguage ?? {},
      bodyByLanguage: bodyByLanguage ?? {},
      isScripture: isScripture === true,
    };
    prayers.push(prayer);
    return { ...bare, kind: "own" as const, prayerUid: prayer.uid };
  });
  return { ...project, prayers, steps };
}

export function deserializeProject(json: string): Project {
  const raw = JSON.parse(json);
  if (raw?.prosaryCompose !== 1 && raw?.prosaryCompose !== 2) {
    throw new Error("Not a Prosary Compose project file.");
  }
  const { prosaryCompose: version, ...rest } = raw;
  const project: Project = {
    ...rest,
    prayers: rest.prayers ?? [],
    images: (rest.images ?? []).map((image: EditorImage & { jpeg: string }) => ({
      ...image,
      jpeg: fromBase64(image.jpeg),
    })),
    audio: (rest.audio ?? []).map((track: EditorAudioTrack & { bytes: string }) => ({
      ...track,
      bytes: fromBase64(track.bytes),
    })),
  };
  return version === 1 ? migrateV1(project) : project;
}

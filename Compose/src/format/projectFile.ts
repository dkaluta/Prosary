// Portable .prosarycompose files remain JSON so users can save/share them. Binary payloads are
// base64 only on this explicit import/export path; routine browser autosaves use IndexedDB.

import type { EditorAudioTrack, EditorImage, Project } from "./project";
import { newProject, pruneUnusedImages } from "./project";

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
  const normalized = pruneUnusedImages(project);
  return JSON.stringify({
    prosaryCompose: 1,
    ...normalized,
    images: normalized.images.map((image) => ({
      uid: image.uid,
      label: image.label,
      jpeg: toBase64(image.jpeg),
    })),
    audio: normalized.audio.map((track) => ({ ...track, bytes: toBase64(track.bytes) })),
  });
}

export function deserializeProject(json: string): Project {
  const raw = JSON.parse(json);
  if (raw?.prosaryCompose !== 1) throw new Error("Not a Prosary Compose project file.");
  const { prosaryCompose: _, ...rest } = raw;
  return pruneUnusedImages({
    // Every field a saved project might predate, defaulted in one go. A project saved before a
    // feature landed simply has no key for it — and the screens read those keys without asking.
    ...newProject(),
    ...rest,
    // Explicit fields discard the old derived `dataUrl` copy written by early versions.
    images: (rest.images ?? []).map((image: EditorImage & { jpeg: string }) => ({
      uid: image.uid,
      label: image.label,
      jpeg: fromBase64(image.jpeg),
    })),
    audio: (rest.audio ?? []).map((track: EditorAudioTrack & { bytes: string }) => ({
      ...track,
      bytes: fromBase64(track.bytes),
    })),
  });
}

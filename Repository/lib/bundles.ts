// Submission pipeline: validate an uploaded .prosaryprayer against the format's install
// checks (mirroring the apps' PrayerPackStore.installPack — see Shared/ARCHITECTURE.md
// § Content bundles) and re-stamp its id into the submitter's namespace,
// `repo.<username>.<name>`. Compose can't author dotted ids (its id shape forbids them),
// so authors upload ordinary compose output and the repository claims the namespace here —
// rebuilding the zip with the same dependency-free writer the webapp packs with.

import { buildZip, ZipReader, type ZipFile } from "./zip.ts";

const KNOWN_LANGUAGES = new Set(["la", "en", "ar", "he", "ru", "tl"]);
const MAX_BUNDLE_BYTES = 8 * 1024 * 1024;
const LOCAL_NAME_SHAPE = /^[a-z][a-zA-Z0-9]*$/;

export class BundleError extends Error {}

export type ValidatedBundle = {
  id: string;
  displayName: string;
  languages: string[];
  bytes: Uint8Array;
};

function slugify(name: string): string {
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

export async function validateAndRestamp(bytes: Uint8Array, username: string): Promise<ValidatedBundle> {
  if (bytes.length > MAX_BUNDLE_BYTES) {
    throw new BundleError("The bundle is larger than 8 MB.");
  }

  let zip: ZipReader;
  try {
    zip = ZipReader.open(bytes);
  } catch {
    throw new BundleError("This file is not a readable .prosaryprayer bundle.");
  }
  if (!zip.has("manifest.json") || !zip.has("devotion.json")) {
    throw new BundleError("The bundle is missing its manifest or devotion definition.");
  }

  let manifest: Record<string, unknown>;
  try {
    manifest = (await zip.json("manifest.json")) as Record<string, unknown>;
  } catch {
    throw new BundleError("The bundle's manifest is not valid JSON.");
  }
  try {
    await zip.json("devotion.json");
  } catch {
    throw new BundleError("The bundle's devotion definition is not valid JSON.");
  }
  if (manifest.builtinKind) {
    throw new BundleError("Bundles backing built-in devotions can't be published.");
  }

  const displayName = typeof manifest.displayName === "string" ? manifest.displayName.trim() : "";
  if (!displayName) throw new BundleError("The bundle has no display name.");

  const languages = Array.isArray(manifest.languages)
    ? manifest.languages.filter((l): l is string => typeof l === "string" && KNOWN_LANGUAGES.has(l))
    : [];
  if (languages.length === 0) {
    throw new BundleError("The bundle declares no known prayer languages.");
  }
  for (const language of languages) {
    if (!zip.has(`content/${language}.json`)) {
      throw new BundleError(`The bundle declares ${language} but ships no content for it.`);
    }
    try {
      await zip.json(`content/${language}.json`);
    } catch {
      throw new BundleError(`The bundle's ${language} content is not valid JSON.`);
    }
  }

  // The local name: the manifest's own id when it's a plain compose-style id, a previous
  // repo.<user>.<name>'s tail on resubmission, else a slug of the display name.
  const rawId = typeof manifest.id === "string" ? manifest.id : "";
  const repoTail = rawId.startsWith("repo.") ? rawId.split(".").slice(2).join(".") : null;
  const localName =
    repoTail && LOCAL_NAME_SHAPE.test(repoTail)
      ? repoTail
      : LOCAL_NAME_SHAPE.test(rawId)
        ? rawId
        : slugify(displayName);
  if (!LOCAL_NAME_SHAPE.test(localName)) {
    throw new BundleError("A publishable name could not be derived from the bundle.");
  }
  const id = `repo.${username}.${localName}`;

  // Re-stamp manifest id/kind and rebuild the zip byte-for-byte otherwise.
  const restamped = { ...manifest, id, kind: id };
  const files: ZipFile[] = [];
  for (const name of zip.names()) {
    files.push({
      name,
      data:
        name === "manifest.json"
          ? new TextEncoder().encode(JSON.stringify(restamped, null, 2) + "\n")
          : await zip.contents(name),
    });
  }

  return { id, displayName, languages, bytes: buildZip(files) };
}

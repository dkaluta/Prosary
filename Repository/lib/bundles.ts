// Submission pipeline: validate an uploaded .prosaryprayer against the format's install
// checks (mirroring the apps' PrayerPackStore.installPack — see Shared/ARCHITECTURE.markdown
// § Content bundles) and re-stamp its id into the submitter's namespace,
// `repo.<username>.<name>`. Compose can't author dotted ids (its id shape forbids them),
// so authors upload ordinary compose output and the repository claims the namespace here —
// rebuilding the zip with the same dependency-free writer the webapp packs with.

import { buildZip, ZipReader, type ZipFile } from "./zip.ts";
import { isSupportedLanguage } from "./languages.ts";
import {
  checkNativeAudio,
  checkNativeContent,
  checkNativeDevotion,
  checkNativeManifest,
  checkNativeOptions,
  nativeObject,
} from "./nativeBundleShape.ts";

export const MAX_BUNDLE_BYTES = 8 * 1024 * 1024;
const REPOSITORY_ZIP_LIMITS = {
  maxEntryUncompressedBytes: MAX_BUNDLE_BYTES,
  maxTotalUncompressedBytes: MAX_BUNDLE_BYTES,
} as const;
const LOCAL_NAME_SHAPE = /^[a-z][a-zA-Z0-9]*$/;

export class BundleError extends Error {}

export function assertBundleByteLength(byteLength: number): void {
  if (byteLength > MAX_BUNDLE_BYTES) {
    throw new BundleError("The bundle is larger than 8 MB.");
  }
}

export type ValidatedBundle = {
  id: string;
  displayName: string;
  languages: string[];
  /** The manifest's own tags (Compose writes them) — the submission form can override. */
  tags: string[];
  bytes: Uint8Array;
};

async function nativeJson(
  zip: ZipReader,
  name: string,
  check?: (value: unknown, path: string) => void,
): Promise<Record<string, unknown>> {
  let value: unknown;
  try {
    value = await zip.json(name);
  } catch {
    throw new BundleError(`The bundle's ${name} is not valid JSON.`);
  }
  try {
    const record = nativeObject(value, name);
    check?.(record, name);
    return record;
  } catch (error) {
    const detail = error instanceof Error ? ` ${error.message}` : "";
    throw new BundleError(`The bundle's ${name} cannot be read by the native apps.${detail}`);
  }
}

function slugify(name: string): string {
  const words = name
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-zA-Z0-9]+/g, " ")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (!name.trim()) return "";
  const latin = words
    .map((w, i) => (i === 0 ? w.toLowerCase() : w[0].toUpperCase() + w.slice(1).toLowerCase()))
    .join("");
  if (LOCAL_NAME_SHAPE.test(latin)) return latin;
  // Keep this deterministic fallback in step with Compose's slugify. Display names retain
  // their original script while the portable identifier stays within native filename rules.
  let hash = BigInt("0xcbf29ce484222325");
  for (const byte of new TextEncoder().encode(name.trim().normalize("NFC"))) {
    hash = BigInt.asUintN(64, (hash ^ BigInt(byte)) * BigInt("0x100000001b3"));
  }
  return `prayer${hash.toString(16).padStart(16, "0")}`;
}

export async function validateAndRestamp(bytes: Uint8Array, username: string): Promise<ValidatedBundle> {
  assertBundleByteLength(bytes.length);

  let zip: ZipReader;
  try {
    zip = ZipReader.open(bytes, REPOSITORY_ZIP_LIMITS);
  } catch {
    throw new BundleError("This file is not a readable .prosaryprayer bundle.");
  }
  if (!zip.has("manifest.json") || !zip.has("devotion.json")) {
    throw new BundleError("The bundle is missing its manifest or devotion definition.");
  }

  const manifest = await nativeJson(zip, "manifest.json");
  await nativeJson(zip, "devotion.json", checkNativeDevotion);
  if (manifest.builtinKind != null) {
    throw new BundleError("Bundles backing built-in devotions can't be published.");
  }

  const displayName = typeof manifest.displayName === "string" ? manifest.displayName.trim() : "";
  if (!displayName) throw new BundleError("The bundle has no display name.");

  const declaredLanguages = Array.isArray(manifest.languages) ? manifest.languages : [];
  const invalidLanguages = declaredLanguages.filter(
    (language): boolean => typeof language !== "string" || !isSupportedLanguage(language),
  );
  if (invalidLanguages.length > 0) {
    const labels = invalidLanguages.map((language) =>
      typeof language === "string" ? language : JSON.stringify(language) ?? String(language),
    );
    throw new BundleError(
      `Unsupported prayer language${labels.length === 1 ? "" : "s"}: ${labels.join(", ")}.`,
    );
  }
  const languages = [...new Set(declaredLanguages.filter(isSupportedLanguage))];
  if (languages.length === 0) {
    throw new BundleError("The bundle declares no known prayer languages.");
  }
  try {
    checkNativeManifest(manifest, "manifest.json");
  } catch (error) {
    throw new BundleError(`The bundle's manifest cannot be read by the native apps. ${String(error instanceof Error ? error.message : error)}`);
  }
  for (const language of languages) {
    if (!zip.has(`content/${language}.json`)) {
      throw new BundleError(`The bundle declares ${language} but ships no content for it.`);
    }
  }
  // Native loaders also decode undeclared overlays and the optional control-plane files.
  // Validate every such file before publication, but retain its original bytes below.
  for (const name of zip.names()) {
    if (name.startsWith("content/") && name.endsWith(".json")) {
      await nativeJson(zip, name, checkNativeContent);
    }
  }
  if (zip.has("options.json")) await nativeJson(zip, "options.json", checkNativeOptions);
  if (zip.has("audio.json")) await nativeJson(zip, "audio.json", checkNativeAudio);

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

  const manifestTags = Array.isArray(manifest.tags)
    ? manifest.tags
        .filter((t): t is string => typeof t === "string")
        .map((t) => t.trim().toLowerCase())
        .filter(Boolean)
        .slice(0, 8)
    : [];

  // Re-stamp the identity and the exact language set validated above. This prevents catalog
  // metadata from claiming a filtered subset while the downloadable manifest keeps unsupported,
  // unvalidated languages.
  const restamped = { ...manifest, id, kind: id, languages };
  const files: ZipFile[] = [];
  try {
    for (const name of zip.names()) {
      files.push({
        name,
        data:
          name === "manifest.json"
            ? new TextEncoder().encode(JSON.stringify(restamped, null, 2) + "\n")
            : await zip.contents(name),
      });
    }
  } catch {
    throw new BundleError("The bundle contains a corrupt ZIP entry.");
  }

  const restampedBytes = buildZip(files);
  if (restampedBytes.length > MAX_BUNDLE_BYTES) {
    throw new BundleError("The rebuilt bundle is larger than 8 MB.");
  }
  return { id, displayName, languages, tags: manifestTags, bytes: restampedBytes };
}

import assert from "node:assert/strict";
import test from "node:test";
import {
  assertBundleByteLength,
  BundleError,
  MAX_BUNDLE_BYTES,
  validateAndRestamp,
} from "../lib/bundles.ts";
import { buildZip, ZipReader } from "../lib/zip.ts";

const encoder = new TextEncoder();

function json(value: unknown): Uint8Array {
  return encoder.encode(`${JSON.stringify(value)}\n`);
}

function bundleWithLanguages(languages: unknown[]): Uint8Array {
  return buildZip([
    {
      name: "manifest.json",
      data: json({
        formatVersion: 2,
        id: "eveningPrayer",
        kind: "eveningPrayer",
        displayName: "Evening Prayer",
        languages,
        tags: [" Evening ", "community"],
      }),
    },
    { name: "devotion.json", data: json({ type: "steps", steps: [] }) },
    ...[...new Set(languages.filter((language): language is string => typeof language === "string"))]
      .map((language) => ({ name: `content/${language}.json`, data: json({ prayers: {} }) })),
  ]);
}

test("an oversized upload is rejected from its declared byte length before it is read", () => {
  assert.doesNotThrow(() => assertBundleByteLength(MAX_BUNDLE_BYTES));
  assert.throws(
    () => assertBundleByteLength(MAX_BUNDLE_BYTES + 1),
    (error: unknown) =>
      error instanceof BundleError && error.message === "The bundle is larger than 8 MB.",
  );
});

test("validation re-stamps identity without changing the validated language set", async () => {
  const result = await validateAndRestamp(bundleWithLanguages(["la", "en", "en"]), "pilgrim");
  assert.equal(result.id, "repo.pilgrim.eveningPrayer");
  assert.deepEqual(result.languages, ["la", "en"]);
  assert.deepEqual(result.tags, ["evening", "community"]);

  const manifest = (await ZipReader.open(result.bytes).json("manifest.json")) as {
    id: string;
    kind: string;
    languages: string[];
  };
  assert.equal(manifest.id, result.id);
  assert.equal(manifest.kind, result.id);
  assert.deepEqual(manifest.languages, result.languages);
});

test("a mixed supported and unsupported manifest is rejected instead of partially published", async () => {
  await assert.rejects(
    () => validateAndRestamp(bundleWithLanguages(["en", "es"]), "pilgrim"),
    (error: unknown) =>
      error instanceof BundleError && error.message === "Unsupported prayer language: es.",
  );
});

test("non-string manifest languages are rejected clearly", async () => {
  await assert.rejects(
    () => validateAndRestamp(bundleWithLanguages(["en", 42]), "pilgrim"),
    (error: unknown) =>
      error instanceof BundleError && error.message === "Unsupported prayer language: 42.",
  );
});

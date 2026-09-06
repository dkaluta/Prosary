import assert from "node:assert/strict";
import test from "node:test";
import {
  assertBundleByteLength,
  BundleError,
  MAX_BUNDLE_BYTES,
  validateAndRestamp,
} from "../lib/bundles.ts";
import { buildZip, ZipReader } from "../lib/zip.ts";
import { displayLanguageCodes, languageName, SUPPORTED_LANGUAGES } from "../lib/languages.ts";

const encoder = new TextEncoder();

test("Hebrew labels and chips collapse the old rite code without changing bundle metadata", () => {
  assert.equal(languageName("he"), "עברית");
  assert.equal(languageName("he-x-gamliel"), "עברית");
  const codes = ["en", "he-x-gamliel", "he", "arc"];
  assert.deepEqual(displayLanguageCodes(codes), ["en", "he", "arc"]);
  assert.deepEqual(codes, ["en", "he-x-gamliel", "he", "arc"]);
});

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
    () => validateAndRestamp(bundleWithLanguages(["en", "zz"]), "pilgrim"),
    (error: unknown) =>
      error instanceof BundleError && error.message === "Unsupported prayer language: zz.",
  );
});

test("all twelve native prayer languages can be published without narrowing the catalog", async () => {
  const languages = ["la", "en", "ar", "he", "he-x-gamliel", "arc", "el", "es", "ru", "tl", "fr", "it"];
  assert.deepEqual([...SUPPORTED_LANGUAGES].sort(), [...languages].sort());
  for (const language of languages) {
    const result = await validateAndRestamp(bundleWithLanguages([language]), "pilgrim");
    assert.deepEqual(result.languages, [language]);
    const manifest = await ZipReader.open(result.bytes).json("manifest.json") as { languages: string[] };
    assert.deepEqual(manifest.languages, [language]);
  }
});

test("Aramaic still requires its own declared content file", async () => {
  const zip = ZipReader.open(bundleWithLanguages(["arc"]));
  const files = await Promise.all(zip.names().filter((name) => name !== "content/arc.json")
    .map(async (name) => ({ name, data: await zip.contents(name) })));
  await assert.rejects(
    () => validateAndRestamp(buildZip(files), "pilgrim"),
    (error: unknown) => error instanceof BundleError && error.message === "The bundle declares arc but ships no content for it.",
  );
});

test("non-string manifest languages are rejected clearly", async () => {
  await assert.rejects(
    () => validateAndRestamp(bundleWithLanguages(["en", 42]), "pilgrim"),
    (error: unknown) =>
      error instanceof BundleError && error.message === "Unsupported prayer language: 42.",
  );
});

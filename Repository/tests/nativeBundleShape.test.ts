import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import test from "node:test";
import { BundleError, validateAndRestamp } from "../lib/bundles.ts";
import { buildZip, ZipReader, type ZipFile } from "../lib/zip.ts";

const encoder = new TextEncoder();
const json = (value: unknown) => encoder.encode(JSON.stringify(value));
const manifest = {
  id: "nativeShape", displayName: "Native shape", languages: ["en"], hasCatalog: false,
};
const content = { prayers: { body: "A prayer" }, mysteries: {} };
const step = { title: "A prayer", bodyKey: "body" };
const definition = { type: "steps", steps: [step] };
function fixture(overrides: Record<string, unknown> = {}): Uint8Array {
  return buildZip(Object.entries({
    "manifest.json": manifest, "devotion.json": definition, "content/en.json": content,
    ...overrides,
  }).map(([name, value]) => ({ name, data: json(value) })));
}

test("legacy native bundles need no explicit format or schema version", async () => {
  const result = await validateAndRestamp(fixture(), "pilgrim");
  const output = ZipReader.open(result.bytes);
  const savedManifest = await output.json("manifest.json") as Record<string, unknown>;
  assert.equal(savedManifest.id, "repo.pilgrim.nativeShape");
  assert.equal(savedManifest.schemaVersion, undefined);
  assert.equal(savedManifest.formatVersion, undefined);
});

test("all shipped canonical runtime definitions remain publishable with a community identity", async () => {
  const root = new URL("../../Shared/content/", import.meta.url);
  let checked = 0;
  for (const directory of await readdir(root, { withFileTypes: true })) {
    if (!directory.isDirectory()) continue;
    const base = new URL(`${directory.name}/`, root);
    let original: Record<string, unknown>;
    try {
      original = JSON.parse(await readFile(new URL("manifest.json", base), "utf8"));
    } catch { continue; }
    const files: ZipFile[] = [];
    // This checks every real control-plane shape, including the large Rosary whose artwork
    // exceeds the repository's separate 8 MB publishing limit. Text bytes remain untouched.
    for (const name of ["devotion.json", "options.json", "audio.json"]) {
      try { files.push({ name, data: await readFile(new URL(name, base)) }); }
      catch (error) { if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error; }
    }
    if (!files.some((file) => file.name === "devotion.json")) continue;
    const { builtinKind: _builtinKind, ...communityManifest } = original;
    files.push({ name: "manifest.json", data: json({ ...communityManifest, id: "nativeExample" }) });
    for (const name of await readdir(new URL("content/", base))) {
      if (name.endsWith(".json")) files.push({ name: `content/${name}`, data: await readFile(new URL(`content/${name}`, base)) });
    }
    const result = await validateAndRestamp(buildZip(files), "pilgrim");
    const output = ZipReader.open(result.bytes);
    for (const file of files.filter((file) => file.name !== "manifest.json")) {
      assert.deepEqual(await output.contents(file.name), new Uint8Array(file.data), `${directory.name}/${file.name}`);
    }
    checked++;
  }
  assert.equal(checked, 10, "exercise every shipped devotion's native JSON, not a synthetic subset");
});

test("a complete native rosary pack retains artwork, options and every non-manifest byte", async () => {
  const original = ZipReader.open(await readFile(new URL("../../Shared/dist/franciscanCrown.prosaryprayer", import.meta.url)));
  const files = await Promise.all(original.names().map(async (name) => {
    if (name !== "manifest.json") return { name, data: await original.contents(name) };
    const { builtinKind: _builtinKind, ...source } = await original.json(name) as Record<string, unknown>;
    return { name, data: json({ ...source, id: "communityCrown" }) };
  }));
  const result = await validateAndRestamp(buildZip(files), "pilgrim");
  const output = ZipReader.open(result.bytes);
  assert.deepEqual(output.names(), files.map((file) => file.name));
  assert.ok(output.names().some((name) => name.startsWith("images/")));
  assert.ok(output.has("options.json"));
  for (const file of files.filter((file) => file.name !== "manifest.json")) {
    assert.deepEqual(await output.contents(file.name), file.data, file.name);
  }
});

test("variants with paired reading aids, Hebrew provenance, overlays and audio are retained", async () => {
  const files = fixture({
    "devotion.json": { type: "steps", variants: [{ id: "full", name: "Full", defaultForLanguages: ["he-x-gamliel"], steps: [step] }] },
    "content/he.json": { prayers: { body: "סימן" }, mysteries: {}, transliterations: { body: "Matching reading aid" }, $prayerTraditionByKey: { body: "vicariate" } },
    "audio.json": { tracks: [{ id: "recording", language: "en", variantId: "full", file: "audio/en.opus", chapters: [{ start: 0, title: "Opening", stepIndex: 0 }] }] },
    "notes.json": { "$comment": "Unknown author metadata stays untouched" },
  });
  const input = ZipReader.open(files);
  const result = await validateAndRestamp(files, "pilgrim");
  const output = ZipReader.open(result.bytes);
  for (const name of input.names().filter((name) => name !== "manifest.json")) {
    assert.deepEqual(await output.contents(name), await input.contents(name), name);
  }
});

const invalidFiles: [string, string, unknown][] = [
  ["null manifest", "manifest.json", null],
  ["array manifest", "manifest.json", []],
  ["wrong manifest scalar", "manifest.json", { ...manifest, hasCatalog: "false" }],
  ["missing required manifest field", "manifest.json", { ...manifest, hasCatalog: undefined }],
  ["null devotion", "devotion.json", null],
  ["array devotion", "devotion.json", []],
  ["unknown devotion type", "devotion.json", { type: "nativeCannotDecodeThis", steps: [] }],
  ["future hours format", "devotion.json", { type: "hours", hours: [] }],
  ["null step", "devotion.json", { type: "steps", steps: [null] }],
  ["wrong condition type", "devotion.json", { type: "steps", steps: [{ ...step, if: [] }] }],
  ["fractional repeat", "devotion.json", { type: "steps", steps: [{ ...step, repeat: 1.5 }] }],
  ["out-of-range native integer", "devotion.json", { type: "steps", steps: [{ ...step, repeat: 2147483648 }] }],
  ["wrong scripture flags", "devotion.json", { type: "steps", steps: [{ ...step, isScriptureByLanguage: { en: "yes" } }] }],
  ["unknown special step", "devotion.json", { type: "steps", steps: [{ kind: "proper" }] }],
  ["missing variant id", "devotion.json", { type: "steps", variants: [{ name: "Full", steps: [] }] }],
  ["missing day steps", "devotion.json", { type: "days", days: [{ name: "First" }] }],
  ["wrong localized day period map", "devotion.json", { type: "days", days: [{ name: "First", steps: [step], periodByLanguage: "Week 1" }] }],
  ["non-string localized day period", "devotion.json", { type: "days", days: [{ name: "First", steps: [step], periodByLanguage: { fr: 17 } }] }],
  ["unknown native day progression", "devotion.json", { type: "days", dayProgression: "random", days: [] }],
  ["incomplete decades", "devotion.json", { type: "rosary", decades: { count: 5 } }],
  ["null content", "content/en.json", null],
  ["array content", "content/en.json", []],
  ["missing required content map", "content/en.json", { prayers: {} }],
  ["non-string prayer", "content/en.json", { ...content, prayers: { body: 17 } }],
  ["wrong mystery shape", "content/en.json", { ...content, mysteries: { first: "text" } }],
  ["non-string mystery field", "content/en.json", { ...content, mysteries: { first: { description: false } } }],
  ["null reading aids", "content/en.json", { ...content, transliterations: null }],
  ["wrong provenance map", "content/en.json", { ...content, $prayerTraditionByKey: { body: true } }],
  ["malformed undeclared overlay", "content/he-x-gamliel.json", { prayers: { body: false }, mysteries: {} }],
  ["null options", "options.json", null],
  ["wrong options array", "options.json", { options: {} }],
  ["missing option name", "options.json", { options: [{ key: "extra", kind: "toggle", default: true }] }],
  ["unknown option kind", "options.json", { options: [{ key: "extra", name: "Extra", kind: "slider", default: true }] }],
  ["number option default", "options.json", { options: [{ key: "extra", name: "Extra", kind: "toggle", default: 1 }] }],
  ["null audio", "audio.json", null],
  ["wrong track collection", "audio.json", { tracks: {} }],
  ["missing audio chapter start", "audio.json", { tracks: [{ id: "one", language: "en", file: "audio/en.opus", chapters: [{ title: "Opening" }] }] }],
];
for (const [name, path, value] of invalidFiles) {
  test(`native installation mismatch is rejected: ${name}`, async () => {
    await assert.rejects(() => validateAndRestamp(fixture({ [path]: value }), "pilgrim"),
      (error: unknown) => error instanceof BundleError && error.message.includes("native apps"));
  });
}

test("invalid optional JSON is rejected before publication", async () => {
  const input = ZipReader.open(fixture());
  const files = await Promise.all(input.names().map(async (name) => ({ name, data: await input.contents(name) })));
  files.push({ name: "audio.json", data: encoder.encode("{broken") });
  await assert.rejects(() => validateAndRestamp(buildZip(files), "pilgrim"),
    (error: unknown) => error instanceof BundleError && error.message.includes("audio.json is not valid JSON"));
});

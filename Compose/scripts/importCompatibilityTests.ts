// Exercise the production importer and writer together. Rejection is intentional when the
// editor cannot retain a native feature; accepted content must survive a second export.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { buildBundle, buildBundleFiles } from "../src/format/pack";
import { newProject, newUid } from "../src/format/project";
import { openBundle } from "../src/format/unpack";
import { buildZip, ZipReader } from "../src/format/zip";

type Json = Record<string, any>;
type Fixture = Record<string, any>;
const encoder = new TextEncoder();

function fixture(): Fixture {
  return {
    "manifest.json": { schemaVersion: 1, id: "importTest", kind: "importTest", displayName: "Import test", languages: ["en"], hasCatalog: false },
    "devotion.json": { type: "steps", steps: [{ titleKey: "title", bodyKey: "body", imageKey: "cross_placeholder" }] },
    "content/en.json": { prayers: { title: "An authored title", body: "An authored body." }, mysteries: {} },
  };
}

function bundle(files: Fixture): Uint8Array {
  return buildZip(Object.entries(files).map(([name, value]) => ({
    name, data: value instanceof Uint8Array ? value : encoder.encode(JSON.stringify(value)),
  })));
}

async function rejects(files: Fixture, expected: RegExp): Promise<void> {
  await assert.rejects(() => openBundle(bundle(files)), expected);
}

async function roundTrip(files: Fixture) {
  const project = await openBundle(bundle(files));
  const repacked = ZipReader.open(buildBundle(project));
  return { project, repacked };
}

export async function testImportCompatibility(): Promise<void> {
  let cases = 0;
  // Every native field here used to disappear during a successful import.
  for (const [key, value, message] of [
    ["subtitle", "A caption", /subtitles/], ["subtitleKey", "caption", /subtitles/],
    ["acclamationKey", "response", /acclamations/],
    ["isScriptureByLanguage", { en: true }, /Scripture formatting/],
    ["counterIndex", 3, /counters/], ["counterTotal", 7, /counters/],
    ["if", "withResponse", /option-gated/], ["kind", "seasonalMarianAntiphon", /special prayer/],
    ["futureFeature", true, /extra prayer step metadata/],
  ] as const) {
    const files = fixture();
    files["devotion.json"].steps[0][key] = value;
    await rejects(files, message);
    cases++;
  }
  for (const key of ["opening", "closing", "period"]) {
    const files = fixture();
    const steps = files["devotion.json"].steps;
    files["devotion.json"] = { type: "days", days: [{ name: "First day", steps }] };
    if (key === "period") files["devotion.json"].days[0].period = "First week";
    else files["devotion.json"][key] = steps;
    await rejects(files, key === "period" ? /day grouping/ : /shared daily/);
    cases++;
  }
  {
    const files = fixture();
    files["options.json"] = { options: [] };
    await rejects(files, /configurable prayer options/);
    cases++;
  }
  {
    const files = fixture();
    files["devotion.json"] = JSON.parse(readFileSync("../Shared/content/viaLucis/devotion.json", "utf8"));
    await rejects(files, /acclamations|subtitles/);
    cases++;
  }
  // A literal title is copied into all advertised translations before generated keys replace
  // the source keys. Previously the exported translated title was empty.
  {
    const files = fixture();
    files["devotion.json"].steps[0] = { title: "Literal title", bodyKey: "body" };
    delete files["content/en.json"].prayers.title;
    const { project, repacked } = await roundTrip(files);
    assert.equal(project.steps[0].titleByLanguage.en, "Literal title");
    const content = await repacked.json("content/en.json") as Json;
    const devotion = await repacked.json("devotion.json") as Json;
    assert.equal(content.prayers[devotion.steps[0].titleKey], "Literal title");
    assert.equal(content.prayers[devotion.steps[0].bodyKey], "An authored body.");
    cases++;
  }
  // Both a main prayer and an optional common prayer may be overridden locally. Preserve
  // the actual text, paired reading aid and independent Hebrew title/body provenance.
  for (const key of ["paterNoster", "oratioFatimae"]) {
    const files = fixture();
    files["manifest.json"].languages = ["he"];
    delete files["content/en.json"];
    files["content/he.json"] = {
      prayers: { title: "Title fixture", [key]: "Specific body fixture." }, mysteries: {},
      transliterations: { [key]: "Matching reading aid fixture." },
      $prayerTraditionByKey: { [key]: "vicariate" },
    };
    files["devotion.json"].steps[0].bodyKey = key;
    const { project, repacked } = await roundTrip(files);
    assert.equal(project.steps[0].kind, "custom");
    assert.equal(project.steps[0].hebrewBodyTradition, "vicariate");
    assert.equal(project.steps[0].hebrewTitleTradition, undefined);
    const content = await repacked.json("content/he.json") as Json;
    const devotion = await repacked.json("devotion.json") as Json;
    const step = devotion.steps[0];
    assert.equal(content.prayers[step.bodyKey], "Specific body fixture.");
    assert.equal(content.transliterations[step.bodyKey], "Matching reading aid fixture.");
    assert.equal(content.$prayerTraditionByKey[step.bodyKey], "vicariate");
    assert.equal(content.$prayerTraditionByKey[step.titleKey], undefined);
    assert.equal(step.imageKey, "cross_placeholder");
    // Its next reopen must remain byte-stable, with no return to a common-prayer shortcut.
    assert.deepEqual(buildBundleFiles(await openBundle(buildBundle(project))), buildBundleFiles(project));
    cases++;
  }
  {
    const files = fixture();
    files["devotion.json"].steps[0] = { title: "Fatima prayer", bodyKey: "oratioFatimae", imageKey: "cross_placeholder" };
    files["content/en.json"] = { prayers: {}, mysteries: {} };
    const { project, repacked } = await roundTrip(files);
    assert.equal(project.steps[0].kind, "common");
    assert.equal((await repacked.json("devotion.json") as Json).steps[0].imageKey, "cross_placeholder");
    cases++;
  }
  for (const common of [false, true]) {
    const files = fixture();
    files["manifest.json"].languages.push("he");
    files["content/he.json"] = { prayers: {}, mysteries: {} };
    if (common) {
      files["devotion.json"].steps[0] = { title: "Our Father", bodyKey: "paterNoster" };
      files["content/en.json"].prayers = { paterNoster: "Local override." };
    }
    await rejects(files, /partial translations or sparse common-prayer overrides/);
    cases++;
  }
  for (const [change, message] of [
    [(files: Fixture) => { files["manifest.json"].languages.push("zz"); }, /unsupported language/],
    [(files: Fixture) => { files["content/he.json"] = { prayers: { body: "Overlay." }, mysteries: {} }; }, /additional language content/],
    [(files: Fixture) => { files["content/en.json"].$sources = ["Attribution must survive."]; }, /extra en content metadata/],
    [(files: Fixture) => { files["content/en.json"].prayers.unused = "An additional override."; }, /unreferenced prayer content/],
    [(files: Fixture) => { files["content/en.json"].transliterations = { title: "A title aid." }; }, /reading aid without an editable matching body/],
    [(files: Fixture) => { files["content/en.json"].$prayerTraditionByKey = { body: "vicariate" }; }, /prayer-tradition metadata/],
    [(files: Fixture) => { files["content/en.json"].mysteries = { joyful: [] }; }, /mystery content/],
    [(files: Fixture) => { files["manifest.json"].reminderBody = "A special reminder."; }, /custom reminder text/],
    [(files: Fixture) => { files["devotion.json"].steps[0].repeat = 1.5; }, /invalid prayer repeat/],
    [(files: Fixture) => { files["devotion.json"].variants = []; }, /overlapping/],
    [(files: Fixture) => { files["devotion.json"].steps[0].title = "Ambiguous title"; }, /unambiguous title/],
    [(files: Fixture) => { files["content/en.json"].prayers.body = " Body with deliberate spacing. "; }, /space-padded/],
    [(files: Fixture) => { files["devotion.json"].steps[0].imageKey = "art"; files["images/art.png"] = new Uint8Array([1]); }, /other than JPEG/],
  ] as const) {
    const files = fixture();
    change(files);
    await rejects(files, message);
    cases++;
  }
  // Existing editor recordings still reopen exactly, including the first prayer after a
  // repeated step; unsupported markers must not be rounded onto another prayer.
  const project = newProject();
  project.id = "recordingTest";
  project.languages = ["en"];
  project.steps = [1, 2].map((n) => ({
    uid: newUid(), kind: "custom" as const, title: "", titleByLanguage: { en: `Prayer ${n}` },
    bodyByLanguage: { en: `Body ${n}.` }, isScripture: false, repeat: n === 1 ? 3 : undefined,
  }));
  project.audio = [{ uid: newUid(), language: "en", fileName: "en.opus", bytes: new Uint8Array([1, 2]),
    chapters: [{ start: 0, stepUid: project.steps[0].uid }, { start: 7.5, stepUid: project.steps[1].uid }] }];
  assert.deepEqual(buildBundleFiles(await openBundle(buildBundle(project))), buildBundleFiles(project));
  cases++;
  const recordingFixture = (): Fixture => Object.fromEntries(buildBundleFiles(project).map((file) => [file.name,
    file.name.endsWith(".json") ? JSON.parse(new TextDecoder().decode(file.data)) : file.data,
  ]));
  for (const [change, message] of [
    [(files: Fixture) => { files["audio.json"].tracks[0].chapters[1].stepIndex = 1; }, /inside a repeated prayer/],
    [(files: Fixture) => { files["audio.json"].tracks[0].chapters[1].stepIndex = 99; }, /outside the prayer sequence/],
    [(files: Fixture) => { delete files["audio.json"].tracks[0].chapters[1].stepIndex; }, /exact prayer-step reference/],
    [(files: Fixture) => { files["audio.json"].tracks[0].chapters[1].title = "Authored chapter label"; }, /custom recording chapter labels/],
    [(files: Fixture) => { files["audio.json"].tracks[0].id = "narrator-a"; }, /custom recording identities/],
    [(files: Fixture) => { files["audio.json"].tracks[0].language = "he"; }, /recording in a language outside/],
    [(files: Fixture) => { delete files["audio/en.opus"]; }, /missing recording file/],
    [(files: Fixture) => { files["audio.json"].tracks[0].duration = 20; }, /extra recording metadata/],
  ] as const) {
    const files = recordingFixture();
    change(files);
    await rejects(files, message);
    cases++;
  }
  console.log(`✓ ${cases} Compose import compatibility cases preserve editable content and reject unsupported native features`);
}

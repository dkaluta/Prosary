// End-to-end check, run under Node (`vite build --ssr` bundles it): author a Project through
// the same modules the browser uses, pack it, reopen it, repack it, and demand a byte-stable
// round trip. The emitted .prosaryprayer is then validated by the canonical
// Shared/tools/validate-devotion.py from the shell (see package.json's e2e script) — proving
// the webapp and the CLI packer are two writers of one format.

import { mkdirSync, writeFileSync } from "node:fs";
import { buildBundle, buildBundleFiles } from "../src/format/pack";
import type { EditorStep } from "../src/format/project";
import { newProject, newUid } from "../src/format/project";
import { openBundle } from "../src/format/unpack";
import { validateProject } from "../src/format/validate";

function assert(condition: boolean, message: string): void {
  if (!condition) {
    console.error(`✗ ${message}`);
    process.exit(1);
  }
}

function fail(message: string, ...detail: unknown[]): never {
  console.error("e2e FAILED:", message, ...detail);
  process.exit(1);
}

const project = newProject();
project.name = "Example Devotion";
project.id = "exampleDevotion";
project.languages = ["la", "en"];

const cross: EditorStep = {
  uid: newUid(),
  kind: "common",
  commonKey: "signumCrucis",
  title: "Sign of the Cross",
  titleByLanguage: {},
  bodyByLanguage: {},
  isScripture: false,
};
const custom: EditorStep = {
  uid: newUid(),
  kind: "custom",
  title: "",
  titleByLanguage: { la: "Oratio", en: "Prayer" },
  bodyByLanguage: { la: "Kyrie eleison.", en: "Lord, have mercy." },
  // v0.7 reading aid: pin the transliterations emission end to end.
  transliterationByLanguage: { la: "קיריה אלייסון." },
  isScripture: false,
  // Repeated mid-sequence on purpose: every chapter AFTER this step must carry a
  // repeat-expanded (built) stepIndex, not its authored index.
  repeat: 2,
};
const gloria: EditorStep = {
  uid: newUid(),
  kind: "common",
  commonKey: "gloriaPatri",
  title: "Glory Be",
  titleByLanguage: {},
  bodyByLanguage: {},
  isScripture: false,
  repeat: 3,
};
project.steps = [cross, custom, gloria];

const encoder = new TextEncoder();
const opus = new Uint8Array(47);
opus.set(encoder.encode("OggS"), 0);
opus.set(encoder.encode("OpusHead"), 28);
project.audio = [
  {
    uid: newUid(),
    language: "en",
    fileName: "en.opus",
    bytes: opus,
    chapters: [
      { start: 0, stepUid: cross.uid },
      { start: 12.5, stepUid: custom.uid },
      { start: 20, stepUid: gloria.uid },
    ],
  },
];

const issues = validateProject(project);
if (issues.length > 0) fail("expected a clean project", issues);

const bundle = buildBundle(project);
mkdirSync("dist-e2e", { recursive: true });
writeFileSync("dist-e2e/exampleDevotion.prosaryprayer", bundle);

// The transliteration must land in la's content file, keyed like its body — and only there.
{
  const laFile = buildBundleFiles(project).find((f) => f.name === "content/la.json");
  const la = JSON.parse(new TextDecoder().decode(laFile!.data));
  if (la.transliterations?.step02Body !== "קיריה אלייסון.") {
    fail("la transliteration missing or mis-keyed", la.transliterations);
  }
  const enFile = buildBundleFiles(project).find((f) => f.name === "content/en.json");
  const en = JSON.parse(new TextDecoder().decode(enFile!.data));
  if (en.transliterations !== undefined) fail("en should carry no transliterations", en);
}

// Chapters must hint BUILT indices: cross=0, custom=1 (its 2 repetitions span built 1–2),
// gloria=3 — an authored-index regression would emit [0, 1, 2].
{
  const audioFile = buildBundleFiles(project).find((f) => f.name === "audio.json");
  if (!audioFile) fail("audio.json missing from the built bundle");
  const packed = JSON.parse(new TextDecoder().decode(audioFile!.data)) as {
    tracks: { chapters: { stepIndex?: number }[] }[];
  };
  const stepIndices = packed.tracks[0].chapters.map((c) => c.stepIndex);
  if (JSON.stringify(stepIndices) !== JSON.stringify([0, 1, 3])) {
    fail("chapter stepIndex hints must be built-sequence indices", stepIndices);
  }
}

const reopened = await openBundle(bundle);
const reopenedIssues = validateProject(reopened);
if (reopenedIssues.length > 0) fail("reopened project has issues", reopenedIssues);

const original = buildBundleFiles(project);
const repacked = buildBundleFiles(reopened);
if (original.length !== repacked.length) {
  fail(
    "file count changed across the round trip",
    original.map((f) => f.name),
    repacked.map((f) => f.name),
  );
}
const decoder = new TextDecoder();
for (const file of original) {
  const twin = repacked.find((f) => f.name === file.name);
  if (!twin) fail(`missing after round trip: ${file.name}`);
  const same =
    file.data.length === twin.data.length && file.data.every((byte, i) => byte === twin.data[i]);
  if (!same) {
    fail(`round-trip mismatch in ${file.name}`, decoder.decode(file.data), decoder.decode(twin.data));
  }
}

console.log("e2e OK —", original.map((f) => f.name).join(", "));

// A days-type project round-trips: the declarations survive, and content keys stay numbered
// across the whole devotion so a step's key does not shift when a day is edited.
{
  const project = newProject();
  project.name = "A Novena";
  project.id = "novena";
  project.devotionType = "days";
  project.dayProgression = "series";
  project.suggestedStart = "11-29";
  project.suggestedReminderTime = "07:00";
  project.suggestedNext = "divineMercyChaplet";
  project.days = [1, 2].map((n) => ({
    uid: `day${n}`,
    name: `Day ${n}`,
    nameByLanguage: {},
    steps: [
      {
        uid: `d${n}s1`,
        kind: "custom" as const,
        title: `Day ${n} prayer`,
        titleByLanguage: { en: `Day ${n} prayer`, la: `Oratio ${n}` },
        bodyByLanguage: { en: `Text ${n}`, la: `Textus ${n}` },
        isScripture: false,
      },
    ],
  }));

  const files = buildBundleFiles(project);
  const devotion = JSON.parse(
    new TextDecoder().decode(files.find((f) => f.name === "devotion.json")!.data),
  );
  assert(devotion.type === "days", "days project packs a days devotion");
  assert(devotion.dayProgression === "series", "progression survives");
  assert(devotion.suggestedStart === "11-29", "start survives");
  assert(devotion.suggestedNext === "divineMercyChaplet", "next survives");
  assert(devotion.days.length === 2, "both days packed");
  // Second day's step is the second authored step overall, so it takes step02's keys.
  assert(
    devotion.days[1].steps[0].bodyKey === "step02Body",
    `keys number across days, got ${devotion.days[1].steps[0].bodyKey}`,
  );
  const en = JSON.parse(
    new TextDecoder().decode(files.find((f) => f.name === "content/en.json")!.data),
  );
  assert(en.prayers.step02Body === "Text 2", "the second day's text is emitted");
  console.log("✓ days-type project packs with its declarations");
}

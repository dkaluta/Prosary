// End-to-end check, run under Node (`vite build --ssr` bundles it): author a Project through
// the same modules the browser uses, pack it, reopen it, repack it, and demand a byte-stable
// round trip. The emitted .prosaryprayer is then validated by the canonical
// Shared/tools/validate-devotion.py from the shell (see package.json's e2e script) — proving
// the webapp and the CLI packer are two writers of one format.

import { mkdirSync, writeFileSync } from "node:fs";
import { buildBundle, buildBundleFiles } from "../src/format/pack";
import type { EditorPrayer, EditorStep } from "../src/format/project";
import { deserializeProject, newProject, newUid } from "../src/format/project";
import { openBundle } from "../src/format/unpack";
import { validateProject } from "../src/format/validate";

function fail(message: string, ...detail: unknown[]): never {
  console.error("e2e FAILED:", message, ...detail);
  process.exit(1);
}

const project = newProject();
project.name = "Example Devotion";
project.id = "exampleDevotion";
project.languages = ["la", "en"];

// One prayer prayed at two points of the order (shared bodyKey, like the Trisagion's
// acclamation) plus an unfinished draft that no step prays — it must neither block the
// download nor ship in the bundle.
const kyrie: EditorPrayer = {
  uid: newUid(),
  titleByLanguage: { la: "Oratio", en: "Prayer" },
  bodyByLanguage: { la: "Kyrie eleison.", en: "Lord, have mercy." },
  isScripture: false,
};
const draft: EditorPrayer = { uid: newUid(), titleByLanguage: {}, bodyByLanguage: {}, isScripture: false };
project.prayers = [kyrie, draft];

const cross: EditorStep = { uid: newUid(), kind: "common", commonKey: "signumCrucis" };
const kyrieStep1: EditorStep = { uid: newUid(), kind: "own", prayerUid: kyrie.uid };
const gloria: EditorStep = { uid: newUid(), kind: "common", commonKey: "gloriaPatri", repeat: 3 };
const kyrieStep2: EditorStep = { uid: newUid(), kind: "own", prayerUid: kyrie.uid };
project.steps = [cross, kyrieStep1, gloria, kyrieStep2];

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
      { start: 12.5, stepUid: kyrieStep1.uid },
    ],
  },
];

const issues = validateProject(project);
if (issues.length > 0) fail("expected a clean project", issues);

const files = buildBundleFiles(project);
const decoder = new TextDecoder();
const devotion = JSON.parse(decoder.decode(files.find((f) => f.name === "devotion.json")!.data));
if (devotion.steps[1].bodyKey !== "prayer01Body" || devotion.steps[3].bodyKey !== "prayer01Body") {
  fail("steps praying the same prayer must share its bodyKey", devotion.steps);
}
const content = JSON.parse(decoder.decode(files.find((f) => f.name === "content/en.json")!.data));
if (Object.keys(content.prayers).length !== 2) {
  fail("only the used prayer's keys should ship", content.prayers);
}

const bundle = buildBundle(project);
mkdirSync("dist-e2e", { recursive: true });
writeFileSync("dist-e2e/exampleDevotion.prosaryprayer", bundle);

const reopened = await openBundle(bundle);
if (reopened.prayers.length !== 1) {
  fail("reopening must collapse shared-bodyKey steps into one library prayer", reopened.prayers);
}
const reopenedIssues = validateProject(reopened);
if (reopenedIssues.length > 0) fail("reopened project has issues", reopenedIssues);

const repacked = buildBundleFiles(reopened);
if (files.length !== repacked.length) {
  fail(
    "file count changed across the round trip",
    files.map((f) => f.name),
    repacked.map((f) => f.name),
  );
}
for (const file of files) {
  const twin = repacked.find((f) => f.name === file.name);
  if (!twin) fail(`missing after round trip: ${file.name}`);
  const same =
    file.data.length === twin.data.length && file.data.every((byte, i) => byte === twin.data[i]);
  if (!same) {
    fail(`round-trip mismatch in ${file.name}`, decoder.decode(file.data), decoder.decode(twin.data));
  }
}

// Version-1 project files (texts inline on each step) migrate into the prayer library.
const v1 = JSON.stringify({
  prosaryCompose: 1,
  ...newProject(),
  images: [],
  audio: [],
  steps: [
    {
      uid: "s1",
      kind: "custom",
      title: "",
      titleByLanguage: { en: "Old Step" },
      bodyByLanguage: { en: "Old text." },
      isScripture: true,
    },
  ],
});
const migrated = deserializeProject(v1);
const migratedStep = migrated.steps[0];
const migratedPrayer = migrated.prayers[0];
if (
  migrated.prayers.length !== 1 ||
  migratedStep.kind !== "own" ||
  migratedStep.prayerUid !== migratedPrayer.uid ||
  migratedPrayer.bodyByLanguage.en !== "Old text." ||
  migratedPrayer.isScripture !== true
) {
  fail("v1 project migration is broken", migrated);
}

console.log("e2e OK —", files.map((f) => f.name).join(", "));

// End-to-end check, run under Node (`vite build --ssr` bundles it): author a Project through
// the same modules the browser uses, pack it, reopen it, repack it, and demand a byte-stable
// round trip. The emitted .prosaryprayer is then validated by the canonical
// Shared/tools/validate-devotion.py from the shell (see package.json's e2e script) — proving
// the webapp and the CLI packer are two writers of one format.

import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { buildBundle, buildBundleFiles } from "../src/format/pack";
import type { EditorStep } from "../src/format/project";
import {
  attachUploadedArtwork,
  newProject,
  newUid,
  pruneUnusedImages,
  replaceAudioTrackMedia,
} from "../src/format/project";
import { deserializeProject, serializeProject } from "../src/format/projectFile";
import {
  changedAutosaveAssetKeys,
  joinAutosaveProject,
  splitAutosaveProject,
} from "../src/storage/autosave";
import { openBundle } from "../src/format/unpack";
import { validateProject } from "../src/format/validate";
import { ZIP_LIMITS, ZipReader, buildZip, storedZipByteLength } from "../src/format/zip";
import { OGG_OPUS_MIME, PORTABLE_FILE_MIME, supportsOggOpus } from "../src/ui/media";

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

function expectThrow(action: () => unknown, message: string): void {
  try {
    action();
    fail(message);
  } catch {
    // Expected.
  }
}

async function expectRejection(action: () => Promise<unknown>, message: string): Promise<void> {
  try {
    await action();
    fail(message);
  } catch {
    // Expected.
  }
}

function u16(bytes: Uint8Array, offset: number): number {
  return bytes[offset] | (bytes[offset + 1] << 8);
}

function u32(bytes: Uint8Array, offset: number): number {
  return (
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24)
  ) >>> 0;
}

function setU32(bytes: Uint8Array, offset: number, value: number): void {
  bytes[offset] = value & 0xff;
  bytes[offset + 1] = (value >>> 8) & 0xff;
  bytes[offset + 2] = (value >>> 16) & 0xff;
  bytes[offset + 3] = (value >>> 24) & 0xff;
}

function setU16(bytes: Uint8Array, offset: number, value: number): void {
  bytes[offset] = value & 0xff;
  bytes[offset + 1] = (value >>> 8) & 0xff;
}

/** Convert the writer's one-entry stored zip to a conforming bit-3 data-descriptor zip. */
function withDataDescriptor(zip: Uint8Array, signed: boolean): Uint8Array {
  const oldEocd = zip.length - 22;
  const oldCentral = u32(zip, oldEocd + 16);
  const crc = u32(zip, oldCentral + 16);
  const compressed = u32(zip, oldCentral + 20);
  const uncompressed = u32(zip, oldCentral + 24);
  const descriptorLength = signed ? 16 : 12;
  const result = new Uint8Array(zip.length + descriptorLength);
  result.set(zip.subarray(0, oldCentral), 0);
  let descriptor = oldCentral;
  if (signed) {
    setU32(result, descriptor, 0x08074b50);
    descriptor += 4;
  }
  setU32(result, descriptor, crc);
  setU32(result, descriptor + 4, compressed);
  setU32(result, descriptor + 8, uncompressed);
  result.set(zip.subarray(oldCentral), oldCentral + descriptorLength);

  setU16(result, 6, u16(result, 6) | 0x0008);
  setU32(result, 14, 0);
  setU32(result, 18, 0);
  setU32(result, 22, 0);
  const newCentral = oldCentral + descriptorLength;
  setU16(result, newCentral + 8, u16(result, newCentral + 8) | 0x0008);
  setU32(result, result.length - 22 + 16, newCentral);
  return result;
}

const project = newProject();
project.name = "Example Devotion";
project.id = "exampleDevotion";
project.languages = ["la", "en"];

assert(PORTABLE_FILE_MIME === "application/octet-stream", "portable downloads must keep custom extensions");
let probedAudioType = "";
assert(
  supportsOggOpus((mimeType) => {
    probedAudioType = mimeType;
    return "probably";
  }) && probedAudioType === OGG_OPUS_MIME,
  "Ogg Opus preview support probes the wrong media type",
);
assert(
  !supportsOggOpus(() => ""),
  "an empty canPlayType result was treated as playable",
);

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

// --- Alternate forms (steps-type variants): pack shape, reopen, byte-stable repack ---

const formsProject = newProject();
formsProject.name = "Example Forms";
formsProject.id = "exampleForms";
formsProject.languages = ["la", "en"];
const formStep = (body: string): EditorStep => ({
  uid: newUid(),
  kind: "custom",
  title: "",
  titleByLanguage: { la: "Oratio", en: "Prayer" },
  bodyByLanguage: { la: body, en: body },
  isScripture: false,
});
formsProject.variants = [
  {
    uid: newUid(),
    variantId: "byzantine",
    variantIdEdited: true,
    name: "Byzantine",
    nameByLanguage: { la: "Byzantina" },
    defaultForLanguages: [],
    steps: [formStep("Sanctus Deus."), formStep("Gloria Patri.")],
  },
  {
    uid: newUid(),
    variantId: "syriac",
    variantIdEdited: true,
    name: "Syriac",
    nameByLanguage: {},
    defaultForLanguages: ["he-x-gamliel", "arc"],
    steps: [formStep("Qadishat Aloho.")],
  },
];

const formsIssues = validateProject(formsProject);
if (formsIssues.length > 0) fail("expected a clean forms project", formsIssues);

// Tradition-named forms out of canonical order must be caught (first form is the default).
{
  const reordered = {
    ...formsProject,
    variants: [...formsProject.variants].reverse(),
  };
  const ordering = validateProject(reordered);
  if (!ordering.some((i) => i.message.includes("canonical order"))) {
    fail("out-of-order tradition forms were not flagged", ordering);
  }
}

const formsBundle = buildBundle(formsProject);
writeFileSync("dist-e2e/exampleForms.prosaryprayer", formsBundle);

{
  const devotionFile = buildBundleFiles(formsProject).find((f) => f.name === "devotion.json");
  const devotion = JSON.parse(new TextDecoder().decode(devotionFile!.data)) as {
    type: string;
    steps?: unknown;
    variants?: { id: string; defaultForLanguages?: string[]; steps: unknown[] }[];
  };
  if (devotion.type !== "steps" || devotion.steps !== undefined) {
    fail("a forms project must emit variants instead of top-level steps", devotion);
  }
  const ids = (devotion.variants ?? []).map((v) => v.id);
  if (JSON.stringify(ids) !== JSON.stringify(["byzantine", "syriac"])) {
    fail("variant ids wrong", ids);
  }
  if (JSON.stringify(devotion.variants?.[1].defaultForLanguages) !== JSON.stringify(["he-x-gamliel", "arc"])) {
    fail("defaultForLanguages not emitted", devotion.variants?.[1]);
  }
}

const reopenedForms = await openBundle(formsBundle);
if (reopenedForms.variants.length !== 2) fail("reopened forms lost a variant");
const formsReopenedIssues = validateProject(reopenedForms);
if (formsReopenedIssues.length > 0) fail("reopened forms project has issues", formsReopenedIssues);
{
  const originalFiles = buildBundleFiles(formsProject);
  const repackedFiles = buildBundleFiles(reopenedForms);
  if (originalFiles.length !== repackedFiles.length) fail("forms round trip changed file count");
  for (const file of originalFiles) {
    const twin = repackedFiles.find((f) => f.name === file.name);
    if (!twin) fail(`forms round trip missing ${file.name}`);
    const same =
      file.data.length === twin.data.length && file.data.every((byte, i) => byte === twin.data[i]);
    if (!same) {
      fail(`forms round-trip mismatch in ${file.name}`, decoder.decode(file.data), decoder.decode(twin.data));
    }
  }
}

console.log(
  "e2e OK —",
  original.map((f) => f.name).join(", "),
  "· forms:",
  buildBundleFiles(formsProject).map((f) => f.name).join(", "),
);

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

  // The wizard's own checks must agree with the canonical validator about what a days project
  // owes: every day named, and none of them empty.
  const clean = validateProject(project);
  assert(clean.length === 0, `days project should validate clean, got ${JSON.stringify(clean)}`);
  const emptyDay = validateProject({
    ...project,
    days: [...project.days, { uid: "day3", name: "", nameByLanguage: {}, steps: [] }],
  });
  assert(
    emptyDay.some((i) => i.message.includes("needs a name")) &&
      emptyDay.some((i) => i.message.includes("no prayers")),
    `an empty unnamed day should be flagged, got ${JSON.stringify(emptyDay)}`,
  );

  // Reopening must produce the same bundle, exactly as the steps type does.
  const reopenedDays = await openBundle(buildBundle(project));
  const repackedDays = buildBundleFiles(reopenedDays);
  for (const file of files) {
    const twin = repackedDays.find((f) => f.name === file.name);
    assert(twin !== undefined, `missing after the days round trip: ${file.name}`);
    assert(
      file.data.length === twin!.data.length && file.data.every((b, i) => b === twin!.data[i]),
      `days round-trip mismatch in ${file.name}: ${decoder.decode(file.data)} vs ${decoder.decode(twin!.data)}`,
    );
  }

  // Written out so CI can run the canonical Shared/tools/validate-devotion.py over it — no
  // shipped bundle uses days yet, so this is the only thing holding that path honest.
  writeFileSync("dist-e2e/novena.prosaryprayer", buildBundle(project));
  console.log("✓ days-type project packs, validates and round-trips");
}


// A project saved by an older Compose is missing every key added since — and the screens read
// those keys without checking. When multi-day authoring landed, autosaves written before it
// restored with `days: undefined` and the Prayers screen threw on `.find`, leaving a blank page
// that only the person holding that localStorage could see. deserializeProject now fills from
// newProject(), so the guard is simply: drop each key in turn and demand it comes back.
{
  const current = JSON.parse(serializeProject(newProject())) as Record<string, unknown>;
  const defaults = newProject() as unknown as Record<string, unknown>;

  for (const key of Object.keys(defaults)) {
    const aged = { ...current };
    delete aged[key];
    const restored = deserializeProject(JSON.stringify(aged)) as unknown as Record<string, unknown>;
    assert(
      restored[key] !== undefined,
      `a project saved without "${key}" restores with it undefined — the screen that reads it ` +
        `will throw and blank the page. deserializeProject must default every field.`,
    );
  }
  console.log(`✓ projects saved before any of ${Object.keys(defaults).length} fields still restore`);
}

// The O Antiphons pack is built in even though it is calendar-surfaced rather than listed like
// the other devotions. Compose must still reserve its id or an imported bundle could collide.
{
  const project = newProject();
  project.name = "Not the built-in O Antiphons";
  project.id = "oAntiphons";
  project.steps = [cross];
  assert(
    validateProject(project).some((issue) => issue.message.includes("already used")),
    "oAntiphons remains a reserved built-in id",
  );
  console.log("✓ oAntiphons remains reserved");
}

// Artwork is retained while ANY saved shape references it, even if that shape is currently
// inactive. Only the active shape's assets belong in the exported devotion bundle.
{
  const image = (uid: string, byte: number) => ({
    uid,
    label: `${uid}.jpg`,
    jpeg: new Uint8Array([byte]),
  });
  const step = (uid: string, imageUid: string): EditorStep => ({
    uid,
    kind: "custom",
    title: uid,
    titleByLanguage: { la: uid, en: uid },
    bodyByLanguage: { la: uid, en: uid },
    image: { kind: "upload", uid: imageUid },
    isScripture: false,
  });
  const project = newProject();
  project.name = "Retained Shapes";
  project.id = "retainedShapes";
  project.devotionType = "days";
  project.steps = [step("flat", "flat-image")];
  project.variants = [
    {
      uid: "form",
      variantId: "form",
      variantIdEdited: true,
      name: "Form",
      nameByLanguage: {},
      defaultForLanguages: [],
      steps: [step("variant", "variant-image")],
    },
  ];
  project.days = [
    {
      uid: "day",
      name: "Day",
      nameByLanguage: {},
      steps: [step("day-step", "day-image")],
    },
  ];
  project.images = [
    image("flat-image", 1),
    image("variant-image", 2),
    image("day-image", 3),
    image("orphan", 4),
  ];

  const pruned = pruneUnusedImages(project);
  assert(
    pruned.images.map(({ uid }) => uid).join(",") ===
      "flat-image,variant-image,day-image",
    "image pruning follows references in flat steps, forms, and days",
  );
  const packedImages = buildBundleFiles(pruned).filter((file) => file.name.startsWith("images/"));
  assert(packedImages.length === 1, "only the active shape's artwork is packed");
  assert(
    packedImages[0].name === "images/retainedShapes_art_01.jpg" &&
      packedImages[0].data[0] === 3,
    "active artwork numbering ignores retained inactive-shape images",
  );

  const blank = newProject();
  blank.steps = [{ ...step("blank-step", "unused"), image: undefined }];
  const firstAttachment = attachUploadedArtwork(
    blank,
    "blank-step",
    "new.jpg",
    new Uint8Array([7]),
  );
  const firstAttachmentUid = firstAttachment.steps[0].image?.kind === "upload"
    ? firstAttachment.steps[0].image.uid
    : "";
  assert(
    firstAttachment.images.some(({ uid }) => uid === firstAttachmentUid),
    "a first artwork upload atomically adds its bytes and step reference",
  );

  const firstBytes = new Uint8Array([8, 9]);
  const attached = attachUploadedArtwork(pruned, "day-step", "first.jpg", firstBytes);
  const attachedUid = attached.days[0].steps[0].image?.kind === "upload"
    ? attached.days[0].steps[0].image.uid
    : "";
  const replacementBytes = new Uint8Array([10, 11]);
  const replaced = attachUploadedArtwork(attached, "day-step", "replacement.jpg", replacementBytes);
  const replacedUid = replaced.days[0].steps[0].image?.kind === "upload"
    ? replaced.days[0].steps[0].image.uid
    : "";
  assert(attachedUid === "day-image", "an existing upload keeps its uid when first replaced");
  assert(replacedUid === attachedUid, "replacing artwork keeps the same uid");
  assert(
    replaced.images.find(({ uid }) => uid === replacedUid)?.jpeg === replacementBytes,
    "same-uid replacement swaps the binary object without creating a duplicate image",
  );

  const beforeAutosave = splitAutosaveProject(attached);
  const afterAutosave = splitAutosaveProject(replaced);
  assert(
    changedAutosaveAssetKeys(afterAutosave.assets, beforeAutosave.assets).includes(
      `image:${attachedUid}`,
    ),
    "autosave rewrites changed bytes even when the media uid is stable",
  );
  const joined = joinAutosaveProject(afterAutosave.record, afterAutosave.assets);
  assert(
    joined.images.find(({ uid }) => uid === attachedUid)?.jpeg === replacementBytes,
    "IndexedDB metadata and binary records join without base64",
  );
  assert(
    !JSON.stringify(afterAutosave.record).includes("data:") &&
      !JSON.stringify(afterAutosave.record).includes("jpeg"),
    "autosave metadata contains neither data URLs nor inline JPEG bytes",
  );

  const oldAudio = new Uint8Array([1]);
  const nextAudio = new Uint8Array([2]);
  attached.audio = [
    { uid: "stable-track", language: "en", fileName: "old.opus", bytes: oldAudio, chapters: [] },
  ];
  const audioReplaced = replaceAudioTrackMedia(attached, "stable-track", "new.opus", nextAudio);
  assert(
    audioReplaced.audio[0].uid === "stable-track" && audioReplaced.audio[0].bytes === nextAudio,
    "replacing a recording preserves its uid and swaps its binary object",
  );
  assert(
    changedAutosaveAssetKeys(
      splitAutosaveProject(audioReplaced).assets,
      splitAutosaveProject(attached).assets,
    ).includes("audio:stable-track"),
    "a same-uid recording replacement updates its IndexedDB asset",
  );
  console.log("✓ media pruning, active packing, native autosave, and same-uid replacement");
}

// Reader and writer hardening: malformed paths, duplicate names, bad offsets, declared-size
// tricks, and modified payloads must fail before the data is accepted. Stored entries also
// detach from the archive so a tiny retained asset cannot pin a huge source buffer.
{
  expectThrow(
    () => buildZip([{ name: "../outside", data: new Uint8Array() }]),
    "the zip writer accepted path traversal",
  );
  expectThrow(
    () =>
      buildZip([
        { name: "same", data: new Uint8Array([1]) },
        { name: "same", data: new Uint8Array([2]) },
      ]),
    "the zip writer accepted duplicate names",
  );
  expectThrow(
    () => buildZip([{ name: "directory/", data: new Uint8Array() }]),
    "the zip writer accepted a directory pseudo-file",
  );
  expectThrow(
    () =>
      buildZip(
        Array.from({ length: ZIP_LIMITS.entryCount + 1 }, (_, index) => ({
          name: `entry-${index}`,
          data: new Uint8Array(),
        })),
      ),
    "the zip writer accepted an entry count requiring a larger archive format",
  );

  const valid = buildZip([{ name: "safe.txt", data: new Uint8Array([1, 2, 3]) }]);
  assert(
    storedZipByteLength([{ name: "safe.txt", data: new Uint8Array([1, 2, 3]) }]) === valid.length,
    "the stored zip size preflight disagrees with the writer",
  );
  const content = await ZipReader.open(valid).contents("safe.txt");
  assert(content.buffer !== valid.buffer, "stored content detaches from the full archive buffer");

  for (const signed of [false, true]) {
    const descriptorZip = withDataDescriptor(valid, signed);
    const descriptorContent = await ZipReader.open(descriptorZip).contents("safe.txt");
    assert(
      descriptorContent.join(",") === "1,2,3",
      `${signed ? "signed" : "unsigned"} data descriptor remains readable`,
    );
    const badDescriptor = descriptorZip.slice();
    const descriptorOffset = 30 + u16(badDescriptor, 26) + u16(badDescriptor, 28) + 3;
    badDescriptor[descriptorOffset + (signed ? 4 : 0)] ^= 1;
    expectThrow(
      () => ZipReader.open(badDescriptor),
      `the zip reader accepted a bad ${signed ? "signed" : "unsigned"} data descriptor`,
    );
  }

  const changedPayload = valid.slice();
  const payloadOffset = 30 + u16(changedPayload, 26) + u16(changedPayload, 28);
  changedPayload[payloadOffset] ^= 0xff;
  await expectRejection(
    () => ZipReader.open(changedPayload).contents("safe.txt"),
    "the zip reader accepted a CRC mismatch",
  );

  const badOffset = valid.slice();
  const eocd = badOffset.length - 22;
  setU32(badOffset, eocd + 16, badOffset.length);
  expectThrow(() => ZipReader.open(badOffset), "the zip reader accepted an out-of-bounds index");

  const oversized = valid.slice();
  const centralOffset = u32(oversized, oversized.length - 22 + 16);
  setU32(oversized, centralOffset + 20, ZIP_LIMITS.entryBytes + 1);
  setU32(oversized, centralOffset + 24, ZIP_LIMITS.entryBytes + 1);
  expectThrow(() => ZipReader.open(oversized), "the zip reader accepted an oversized entry");

  const mismatchedName = valid.slice();
  mismatchedName[30] ^= 1;
  expectThrow(
    () => ZipReader.open(mismatchedName),
    "the zip reader accepted conflicting local and central names",
  );

  const overlapping = buildZip([
    { name: "first", data: new Uint8Array([1]) },
    { name: "second", data: new Uint8Array([2]) },
  ]);
  const overlapCentral = u32(overlapping, overlapping.length - 22 + 16);
  setU32(overlapping, 18, 2);
  setU32(overlapping, 22, 2);
  setU32(overlapping, overlapCentral + 20, 2);
  setU32(overlapping, overlapCentral + 24, 2);
  expectThrow(() => ZipReader.open(overlapping), "the zip reader accepted overlapping entries");

  const canonicalPackNames = readdirSync("../Shared/dist")
    .filter((name) => name.endsWith(".prosaryprayer"))
    .sort();
  assert(canonicalPackNames.length === 9, "expected all nine canonical devotion packs");
  for (const packName of canonicalPackNames) {
    const canonical = ZipReader.open(
      new Uint8Array(readFileSync(`../Shared/dist/${packName}`)),
    );
    assert(canonical.has("manifest.json"), `${packName} has no manifest`);
    for (const entryName of canonical.names()) await canonical.contents(entryName);
  }

  const nativeDecompressionStream = Object.getOwnPropertyDescriptor(
    globalThis,
    "DecompressionStream",
  );
  if (!nativeDecompressionStream) fail("the test runtime has no DecompressionStream to restore");
  try {
    Object.defineProperty(globalThis, "DecompressionStream", {
      value: undefined,
      configurable: true,
      writable: true,
    });
    const unsupported = ZipReader.open(
      new Uint8Array(readFileSync("../Shared/dist/angelus.prosaryprayer")),
    );
    try {
      await unsupported.contents("devotion.json");
      fail("compressed content opened without DecompressionStream");
    } catch (error) {
      assert(
        error instanceof Error && error.message.includes("cannot open compressed prayer bundles"),
        "unsupported compressed bundles do not explain the browser capability",
      );
    }
  } finally {
    Object.defineProperty(globalThis, "DecompressionStream", nativeDecompressionStream);
  }

  const withUnusedImage = buildZip([
    ...buildBundleFiles(project),
    { name: "images/unused.jpg", data: new Uint8Array([5, 6, 7]) },
  ]);
  const reopenedWithoutBloat = await openBundle(withUnusedImage);
  assert(reopenedWithoutBloat.images.length === 0, "unused archived artwork is not retained");
  console.log(
    `✓ zip CRC, descriptors, overlap, path, duplicate, size, bounds, retention, and all ${canonicalPackNames.length} canonical packs`,
  );
}

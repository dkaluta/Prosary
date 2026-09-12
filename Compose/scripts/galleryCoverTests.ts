import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import { attachUploadedArtwork, newProject, pruneUnusedImages } from "../src/format/project";
import { deserializeProject, serializeProject } from "../src/format/projectFile";
import { buildBundle, buildBundleFiles } from "../src/format/pack";
import { openBundle } from "../src/format/unpack";
import { buildZip, ZipReader } from "../src/format/zip";
import { validateProject } from "../src/format/validate";
import { changedAutosaveAssetKeys, joinAutosaveProject, splitAutosaveProject } from "../src/storage/autosave";
import { galleryImageFile, imageToGalleryJpeg, imageToSquareJpeg, MEDIA_LIMITS, prepareProjectArtwork } from "../src/ui/media";
import { validateAndRestamp } from "../../Repository/lib/bundles";
import { newImageFileId, UUID7_PATTERN } from "../src/format/imageIdentity";
import { inspectSrgbJpeg, isSdrSrgbJpeg, tagConvertedSrgbJpeg } from "../src/format/jpegColor";
import { SRGB_PROFILE, SRGB_PROFILE_SHA256 } from "../src/format/srgbProfile";
import { createHash } from "node:crypto";

export async function testGalleryCovers(): Promise<void> {
  // The existing fixture is an sRGB JPEG; canonicalize its profile/metadata only.
  const jpeg = tagConvertedSrgbJpeg(new Uint8Array(readFileSync("../Shared/Images/crucifix.jpg")));
  const project = newProject();
  project.id = "galleryCoverFixture";
  project.name = "Gallery cover fixture";
  project.languages = ["en"];
  project.steps = [{ uid: "prayer", kind: "common", commonKey: "signumCrucis",
    title: "Sign of the Cross", titleByLanguage: {}, bodyByLanguage: {}, isScripture: false }];
  project.galleryImage = { uid: "cover", label: "Portrait.jpg", jpeg };
  assert.equal(validateProject(project).length, 0);
  assert.equal(pruneUnusedImages(project).galleryImage, project.galleryImage);
  assert.equal(project.images.length, 0, "A Gallery-only image does not enter the step picker");

  const parts = splitAutosaveProject(project);
  assert.deepEqual([...parts.assets.keys()], ["gallery:cover"]);
  assert(!JSON.stringify(parts.record).includes("jpeg"), "Cover bytes stay outside autosave metadata");
  const restored = joinAutosaveProject(parts.record, parts.assets);
  assert.equal(restored.galleryImage?.jpeg, jpeg);
  assert.equal(changedAutosaveAssetKeys(splitAutosaveProject({ ...project, name: "Renamed" }).assets, parts.assets).length, 0);
  assert.throws(() => joinAutosaveProject(parts.record, new Map()), /missing one of its media files/);
  const replacement = { ...project, galleryImage: { ...project.galleryImage, jpeg: jpeg.slice() } };
  assert.deepEqual(changedAutosaveAssetKeys(splitAutosaveProject(replacement).assets, parts.assets), ["gallery:cover"]);
  assert.equal(splitAutosaveProject({ ...project, galleryImage: undefined }).assets.size, 0);

  const saved = deserializeProject(serializeProject(project));
  assert.deepEqual(saved.galleryImage, project.galleryImage);
  assert.deepEqual(saved.images, []);
  const old = { ...project, galleryImage: undefined };
  assert.equal(deserializeProject(serializeProject(old)).galleryImage, undefined);
  const oldParts = splitAutosaveProject(old);
  assert.equal(joinAutosaveProject(oldParts.record, oldParts.assets).galleryImage, undefined);
  assert.equal((await openBundle(buildBundle(old))).galleryImage, undefined);

  const bundle = buildBundle(saved);
  const zip = ZipReader.open(bundle);
  const manifest = await zip.json("manifest.json") as Record<string, any>;
  assert.equal(manifest.galleryImageKey, "default");
  assert.deepEqual(manifest.images, [manifest.galleryImageKey]);
  assert.deepEqual(await zip.contents(`images/${manifest.galleryImageKey}.jpg`), jpeg);
  const reopened = await openBundle(bundle);
  assert.deepEqual(reopened.galleryImage?.jpeg, jpeg);
  assert.equal(reopened.galleryImage?.label, "Gallery cover");
  assert.deepEqual(reopened.images, []);
  assert.deepEqual(buildBundle(reopened), bundle, "Gallery-only bundles are byte-stable on a second export");
  const published = await validateAndRestamp(bundle, "pilgrim");
  const publishedZip = ZipReader.open(published.bytes);
  const publishedManifest = await publishedZip.json("manifest.json") as Record<string, any>;
  assert.equal(publishedManifest.galleryImageKey, manifest.galleryImageKey);
  assert.deepEqual(await publishedZip.contents(`images/${publishedManifest.galleryImageKey}.jpg`), jpeg);
  assert.deepEqual((await openBundle(published.bytes)).galleryImage?.jpeg, jpeg);
  writeFileSync("dist-e2e/gallery-cover.prosaryprayer", bundle);

  // Gallery default is pack-scoped; step artwork must always have a separate
  // UUIDv7 key even when the same image serves both roles.
  const stepFileId = newImageFileId();
  const shared = { ...project, images: [{ ...project.galleryImage, fileId: stepFileId }],
    steps: [{ ...project.steps[0], image: { kind: "upload" as const, uid: "cover" } }] };
  for (const copy of [shared, deserializeProject(serializeProject(shared)),
    joinAutosaveProject(splitAutosaveProject(shared).record, splitAutosaveProject(shared).assets)]) {
    const sharedFiles = buildBundleFiles(copy);
    assert.equal(sharedFiles.filter((file) => file.name.startsWith("images/")).length, 2);
    const sharedZip = ZipReader.open(buildBundle(copy));
    const sharedManifest = await sharedZip.json("manifest.json") as Record<string, any>;
    assert.equal(sharedManifest.galleryImageKey, "default");
    assert.deepEqual(sharedManifest.images, [stepFileId, "default"]);
    assert(UUID7_PATTERN.test(stepFileId));
    const devotion = await sharedZip.json("devotion.json") as Record<string, any>;
    assert.equal(devotion.steps[0].imageKey, stepFileId);
    const sharedOpened = await openBundle(buildBundle(copy));
    assert.notEqual(sharedOpened.galleryImage?.uid, sharedOpened.images[0].uid);
    assert.equal(sharedOpened.images[0].fileId, stepFileId);
    assert.equal(sharedOpened.images[0].label, "Image 1");
    assert.deepEqual(sharedOpened.galleryImage?.jpeg, sharedOpened.images[0].jpeg);
    assert.deepEqual(buildBundle(sharedOpened), buildBundle(copy));
  }
  const changed = { ...shared, galleryImage: { ...project.galleryImage, jpeg: jpeg.slice() } };
  assert.equal(buildBundleFiles(changed).filter((file) => file.name.startsWith("images/")).length, 2);
  assert.deepEqual(buildBundleFiles({ ...shared, galleryImage: undefined })
    .filter((file) => file.name.startsWith("images/")).map((file) => file.data), [jpeg]);

  // Legacy editor UUIDv4 identities remain the step reference; their new file
  // identities survive title edits, saves, autosaves, and portable round trips.
  const oldUid = "9c687ec1-aeaf-4b1a-b74c-b0919f96ad22";
  const migrated = pruneUnusedImages({ ...shared,
    images: [{ uid: oldUid, label: "Old artwork", jpeg }],
    steps: [{ ...shared.steps[0], image: { kind: "upload", uid: oldUid } }] });
  const migratedId = migrated.images[0].fileId!;
  assert(UUID7_PATTERN.test(migratedId));
  assert.equal(migrated.images[0].uid, oldUid);
  assert.deepEqual(migrated.steps[0].image, { kind: "upload", uid: oldUid });
  assert.equal(pruneUnusedImages(migrated), migrated);
  const renamed = deserializeProject(serializeProject({ ...migrated, name: "Renamed" }));
  assert.equal(renamed.images[0].fileId, migratedId);
  const migratedParts = splitAutosaveProject(renamed);
  assert.equal(joinAutosaveProject(migratedParts.record, migratedParts.assets).images[0].fileId, migratedId);
  assert.equal((await openBundle(buildBundle(renamed))).images[0].fileId, migratedId);

  const fork = { ...renamed, id: "anotherDevotion" };
  const identical = attachUploadedArtwork(fork, fork.steps[0].uid, "Same artwork.jpg", jpeg.slice());
  assert.equal(identical.images[0].fileId, migratedId, "Identical bytes retain their portable filename");
  const differentJpeg = tagConvertedSrgbJpeg(new Uint8Array(readFileSync("../Shared/Images/gallery_angelus.jpg")));
  const replaced = attachUploadedArtwork(fork, fork.steps[0].uid, "Different artwork.jpg", differentJpeg);
  assert.equal(replaced.images[0].uid, oldUid, "Replacement updates the same editor/autosave image");
  assert.notEqual(replaced.images[0].fileId, migratedId, "A changed fork cannot shadow the original pack's global image key");
  assert(UUID7_PATTERN.test(replaced.images[0].fileId!));
  assert.equal(renamed.images[0].fileId, migratedId);
  for (const copy of [replaced, deserializeProject(serializeProject(replaced)), await openBundle(buildBundle(replaced))]) {
    assert.equal(copy.images[0].fileId, replaced.images[0].fileId);
    const packed = ZipReader.open(buildBundle(copy));
    assert.deepEqual(await packed.contents(`images/${replaced.images[0].fileId}.jpg`), differentJpeg);
    assert(!packed.has(`images/${migratedId}.jpg`));
  }

  const files = buildBundleFiles(project);
  const malformed = (patch: Record<string, unknown>, removeImage = false) => buildZip(files
    .filter((file) => !removeImage || !file.name.startsWith("images/"))
    .map((file) => file.name === "manifest.json" ? {
      ...file, data: new TextEncoder().encode(JSON.stringify({ ...manifest, ...patch })),
    } : file));
  for (const key of [null, 42, "", "../cover", "images/cover.jpg", "https://example.com/cover.jpg", "cover name", "missing"]) {
    await assert.rejects(() => openBundle(malformed({ galleryImageKey: key })), /Gallery cover/);
  }
  await assert.rejects(() => openBundle(malformed({ images: [] })), /declared images/);
  await assert.rejects(() => openBundle(malformed({}, true)), /cover image is missing/);
  await assert.rejects(() => openBundle(buildZip(files.map((file) => file.name.startsWith("images/")
    ? { ...file, data: new Uint8Array() } : file))), /cover image is empty/);
  assert(validateProject({ ...project, galleryImage: { ...project.galleryImage, jpeg: new Uint8Array() } })
    .some((issue) => issue.screen === "basics" && issue.message.includes("Gallery cover")));

  await testCoverConversion();
  testImageIdentitiesAndColor(jpeg);
  console.log("✓ Gallery-only/shared cover packing, project/autosave round trips, removal, invalid imports, and uncropped conversion");
}

async function testCoverConversion(): Promise<void> {
  const jpeg = new File([], "portrait.jpg");
  const png = new File([], "portrait", { type: "image/png" });
  assert.equal(galleryImageFile([jpeg]), jpeg);
  assert.equal(galleryImageFile([png]), png);
  for (const files of [[], [jpeg, png]]) assert.throws(() => galleryImageFile(files), /one image at a time/);
  assert.throws(() => galleryImageFile([new File([], "notes.txt", { type: "text/plain" })]), /image file/);
  // Capture the browser canvas contract: the entire decoded image must be drawn,
  // in both orientations, without enlarging small artwork or changing step crops.
  const originalBitmap = Object.getOwnPropertyDescriptor(globalThis, "createImageBitmap");
  const originalDocument = Object.getOwnPropertyDescriptor(globalThis, "document");
  try {
    for (const [width, height, expectedWidth, expectedHeight] of [[4000, 2000, 2048, 1024],
      [1000, 2500, 819, 2048], [50, 100, 50, 100]]) {
      let closed = false;
      let draw: unknown[] = [];
      let decodeCount = 0;
      const bitmap = { width, height, close: () => { closed = true; } };
      const canvas = { width: 0, height: 0,
        getContext: (type: string, options: unknown) => {
          assert.equal(type, "2d");
          assert.deepEqual(options, { alpha: false, colorSpace: "srgb", colorType: "unorm8", toneMapping: { mode: "standard" } });
          return { getContextAttributes: () => options, fillStyle: "", fillRect() {}, drawImage(...args: unknown[]) { draw = args; } };
        },
        toBlob: (callback: (blob: Blob) => void) => callback(new Blob([new Uint8Array(readFileSync("../Shared/Images/crucifix.jpg"))], { type: "image/jpeg" })) };
      Object.defineProperty(globalThis, "createImageBitmap", { value: async (_file: File, options: unknown) => {
        assert.deepEqual(options, { colorSpaceConversion: "default" });
        decodeCount++;
        return bitmap;
      }, configurable: true });
      Object.defineProperty(globalThis, "document", { value: { createElement: () => canvas }, configurable: true });
      await imageToGalleryJpeg(new File([], "portrait.png"));
      assert.deepEqual([canvas.width, canvas.height], [expectedWidth, expectedHeight]);
      assert.deepEqual(draw, [bitmap, 0, 0, width, height, 0, 0, expectedWidth, expectedHeight]);
      assert(closed, "The decoded cover releases its image allocation");
      if (width === 4000) {
        await imageToSquareJpeg(new File([], "step.png"));
        assert.deepEqual(draw, [bitmap, 1000, 0, 2000, 2000, 0, 0, 1024, 1024]);
        const original = { uid: "old", fileId: newImageFileId(), label: "old", jpeg: new Uint8Array(readFileSync("../Shared/Images/crucifix.jpg")) };
        const legacy = { ...newProject(), images: [original], galleryImage: original };
        const count = decodeCount;
        const normalized = await prepareProjectArtwork(legacy);
        assert.equal(decodeCount, count + 1, "A shared legacy byte buffer is converted only once");
        assert.deepEqual(draw, [bitmap, 0, 0, width, height, 0, 0, expectedWidth, expectedHeight]);
        assert.equal(normalized.images[0].jpeg, normalized.galleryImage!.jpeg);
        assert.notEqual(normalized.images[0].jpeg, original.jpeg);
        assert.equal(normalized.images[0].uid, original.uid);
        assert.notEqual(normalized.images[0].fileId, original.fileId, "Legacy normalization changes bytes and must renew the global image key");
        assert(isSdrSrgbJpeg(normalized.images[0].jpeg));
        assert.equal((await prepareProjectArtwork(normalized)).images[0], normalized.images[0]);
        assert.equal(decodeCount, count + 1, "Canonical images survive reopening without another lossy encode");
      }
    }
    await assert.rejects(() => imageToGalleryJpeg({ size: MEDIA_LIMITS.imageSourceBytes + 1 } as File), /larger than/);
  } finally {
    if (originalBitmap) Object.defineProperty(globalThis, "createImageBitmap", originalBitmap);
    else Reflect.deleteProperty(globalThis, "createImageBitmap");
    if (originalDocument) Object.defineProperty(globalThis, "document", originalDocument);
    else Reflect.deleteProperty(globalThis, "document");
  }
}

function testImageIdentitiesAndColor(jpeg: Uint8Array): void {
  const before = Date.now();
  const ids = Array.from({ length: 1000 }, () => newImageFileId());
  const after = Date.now();
  assert.equal(new Set(ids).size, ids.length);
  for (const id of ids) {
    assert(UUID7_PATTERN.test(id));
    const milliseconds = Number.parseInt(id.replaceAll("-", "").slice(0, 12), 16);
    assert(milliseconds >= before && milliseconds <= after);
  }
  assert.equal(createHash("sha256").update(SRGB_PROFILE).digest("hex"), SRGB_PROFILE_SHA256);
  assert(isSdrSrgbJpeg(jpeg));
  const info = inspectSrgbJpeg(jpeg);
  assert.equal(info.precision, 8);
  assert.equal(info.components, 3);
  assert(info.exactProfile);
  assert.equal(info.unwantedMetadata, false);
  assert.equal(info.trailingBytes, 0);
  assert.deepEqual(tagConvertedSrgbJpeg(jpeg), jpeg, "Canonical profile tagging is idempotent");
  const gainMap = new Uint8Array(jpeg.length * 2);
  gainMap.set(jpeg); gainMap.set(jpeg, jpeg.length);
  assert.equal(isSdrSrgbJpeg(gainMap), false);
  assert.deepEqual(tagConvertedSrgbJpeg(gainMap), jpeg, "Appended gain maps cannot remain in normalized output");
  const hdr = new TextEncoder().encode("HDRGainMap metadata");
  const withMetadata = new Uint8Array(jpeg.length + hdr.length + 4);
  withMetadata.set([255, 216, 255, 225, 0, hdr.length + 2]);
  withMetadata.set(hdr, 6); withMetadata.set(jpeg.subarray(2), hdr.length + 6);
  assert.equal(isSdrSrgbJpeg(withMetadata), false);
  assert.deepEqual(tagConvertedSrgbJpeg(withMetadata), jpeg);
  const twelveBit = jpeg.slice();
  for (let i = 2; i < twelveBit.length - 10; i++) {
    if (twelveBit[i] === 255 && [0xc0, 0xc1, 0xc2].includes(twelveBit[i + 1])) {
      twelveBit[i + 4] = 12;
      break;
    }
  }
  assert.equal(isSdrSrgbJpeg(twelveBit), false);
  assert.throws(() => tagConvertedSrgbJpeg(twelveBit), /8-bit RGB/);
}

import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { deflateRawSync } from "node:zlib";
import test from "node:test";
import { buildZip, ZipReader } from "../lib/zip.ts";

const encoder = new TextEncoder();

function crc32(data: Uint8Array): number {
  let crc = 0xffffffff;
  for (const byte of data) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) {
      crc = crc & 1 ? 0xedb88320 ^ (crc >>> 1) : crc >>> 1;
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function writeU16(target: Uint8Array, offset: number, value: number): void {
  target[offset] = value & 0xff;
  target[offset + 1] = (value >>> 8) & 0xff;
}

function writeU32(target: Uint8Array, offset: number, value: number): void {
  target[offset] = value & 0xff;
  target[offset + 1] = (value >>> 8) & 0xff;
  target[offset + 2] = (value >>> 16) & 0xff;
  target[offset + 3] = (value >>> 24) & 0xff;
}

function u16(source: Uint8Array, offset: number): number {
  return source[offset] | (source[offset + 1] << 8);
}

function u32(source: Uint8Array, offset: number): number {
  return (
    source[offset] |
    (source[offset + 1] << 8) |
    (source[offset + 2] << 16) |
    (source[offset + 3] << 24)
  ) >>> 0;
}

function signatureOffsets(bytes: Uint8Array, signature: number): number[] {
  const offsets: number[] = [];
  for (let offset = 0; offset <= bytes.length - 4; offset++) {
    if (u32(bytes, offset) === signature) offsets.push(offset);
  }
  return offsets;
}

/** A one-file archive shaped like command-line ZIP output that writes a data descriptor. */
function deflatedZip(
  name: string,
  data: Uint8Array,
  options: { declaredSize?: number; declaredCrc?: number } = {},
): Uint8Array {
  const nameBytes = encoder.encode(name);
  const compressed = new Uint8Array(deflateRawSync(data));
  const declaredSize = options.declaredSize ?? data.length;
  const declaredCrc = options.declaredCrc ?? crc32(data);
  const localBytes = 30 + nameBytes.length + compressed.length + 16;
  const centralBytes = 46 + nameBytes.length;
  const output = new Uint8Array(localBytes + centralBytes + 22);
  let cursor = 0;

  writeU32(output, cursor, 0x04034b50);
  writeU16(output, cursor + 4, 20);
  writeU16(output, cursor + 6, 0x0808);
  writeU16(output, cursor + 8, 8);
  writeU16(output, cursor + 26, nameBytes.length);
  output.set(nameBytes, cursor + 30);
  output.set(compressed, cursor + 30 + nameBytes.length);
  cursor += 30 + nameBytes.length + compressed.length;

  writeU32(output, cursor, 0x08074b50);
  writeU32(output, cursor + 4, declaredCrc);
  writeU32(output, cursor + 8, compressed.length);
  writeU32(output, cursor + 12, declaredSize);
  cursor += 16;
  const centralOffset = cursor;

  writeU32(output, cursor, 0x02014b50);
  writeU16(output, cursor + 4, 20);
  writeU16(output, cursor + 6, 20);
  writeU16(output, cursor + 8, 0x0808);
  writeU16(output, cursor + 10, 8);
  writeU32(output, cursor + 16, declaredCrc);
  writeU32(output, cursor + 20, compressed.length);
  writeU32(output, cursor + 24, declaredSize);
  writeU16(output, cursor + 28, nameBytes.length);
  output.set(nameBytes, cursor + 46);
  cursor += centralBytes;

  writeU32(output, cursor, 0x06054b50);
  writeU16(output, cursor + 8, 1);
  writeU16(output, cursor + 10, 1);
  writeU32(output, cursor + 12, centralBytes);
  writeU32(output, cursor + 16, centralOffset);
  return output;
}

test("stored archives round-trip and verify CRC", async () => {
  const archive = buildZip([
    { name: "manifest.json", data: encoder.encode('{"id":"example"}') },
    { name: "content/en.json", data: encoder.encode('{"prayers":{}}') },
  ]);
  const reader = ZipReader.open(archive);
  assert.deepEqual(reader.names(), ["manifest.json", "content/en.json"]);
  assert.equal(new TextDecoder().decode(await reader.contents("manifest.json")), '{"id":"example"}');

  const corrupt = archive.slice();
  const manifestOffset = 30 + u16(corrupt, 26) + u16(corrupt, 28);
  corrupt[manifestOffset] ^= 0xff;
  await assert.rejects(() => ZipReader.open(corrupt).contents("manifest.json"), /CRC/);
});

test("Info-ZIP-style raw DEFLATE with a data descriptor remains readable", async () => {
  const body = encoder.encode("Kyrie eleison. ".repeat(256));
  const reader = ZipReader.open(deflatedZip("content/la.json", body));
  assert.deepEqual(await reader.contents("content/la.json"), body);
});

test("command-line DEFLATE bundles from the canonical distribution remain readable", async () => {
  const distribution = new URL("../../Shared/dist/", import.meta.url);
  const filenames = (await readdir(distribution)).filter((name) => name.endsWith(".prosaryprayer"));
  assert.ok(filenames.length > 0);
  for (const filename of filenames) {
    const archive = new Uint8Array(await readFile(new URL(filename, distribution)));
    const reader = ZipReader.open(archive);
    const manifest = (await reader.json("manifest.json")) as { id?: unknown };
    assert.equal(typeof manifest.id, "string", `${filename} has a manifest id`);
    await reader.json("devotion.json");
  }
});

test("declared entry and aggregate output limits stop decompression bombs", async () => {
  const archive = buildZip([
    { name: "one.txt", data: encoder.encode("1234") },
    { name: "two.txt", data: encoder.encode("5678") },
  ]);
  assert.throws(
    () => ZipReader.open(archive, { maxEntryUncompressedBytes: 3 }),
    /uncompressed-size limit/,
  );
  assert.throws(
    () => ZipReader.open(archive, { maxTotalUncompressedBytes: 7 }),
    /aggregate uncompressed-size limit/,
  );

  const understated = deflatedZip("large.txt", encoder.encode("x".repeat(4096)), {
    declaredSize: 8,
  });
  await assert.rejects(
    () => ZipReader.open(understated, { maxEntryUncompressedBytes: 8 }).contents("large.txt"),
    /exceeds its declared or allowed size/,
  );
});

test("malformed bounds, duplicate names, and local-header mismatches are rejected", () => {
  const ordinary = buildZip([
    { name: "one.txt", data: encoder.encode("one") },
    { name: "two.txt", data: encoder.encode("two") },
  ]);

  const outOfBounds = ordinary.slice();
  const eocd = signatureOffsets(outOfBounds, 0x06054b50).at(-1)!;
  writeU32(outOfBounds, eocd + 16, outOfBounds.length + 1);
  assert.throws(() => ZipReader.open(outOfBounds), /outside the zip archive/);

  const duplicate = ordinary.slice();
  const centralHeaders = signatureOffsets(duplicate, 0x02014b50);
  const firstNameLength = u16(duplicate, centralHeaders[0] + 28);
  const firstName = duplicate.slice(
    centralHeaders[0] + 46,
    centralHeaders[0] + 46 + firstNameLength,
  );
  duplicate.set(firstName, centralHeaders[1] + 46);
  assert.throws(() => ZipReader.open(duplicate), /duplicate entry one\.txt/);

  const mismatched = ordinary.slice();
  mismatched[30] ^= 1;
  assert.throws(() => ZipReader.open(mismatched), /local and central headers disagree/);
});

test("overlapping local records and dishonest data descriptors are rejected", () => {
  const overlapping = buildZip([
    { name: "one.txt", data: encoder.encode("one") },
    { name: "two.txt", data: encoder.encode("two") },
  ]);
  const centralHeaders = signatureOffsets(overlapping, 0x02014b50);
  const firstLocalOffset = u32(overlapping, centralHeaders[0] + 42);
  const secondLocalOffset = u32(overlapping, centralHeaders[1] + 42);
  const firstDataOffset = firstLocalOffset + 30 + u16(overlapping, firstLocalOffset + 26);
  const overlappingSize = secondLocalOffset - firstDataOffset + 1;
  writeU32(overlapping, firstLocalOffset + 18, overlappingSize);
  writeU32(overlapping, firstLocalOffset + 22, overlappingSize);
  writeU32(overlapping, centralHeaders[0] + 20, overlappingSize);
  writeU32(overlapping, centralHeaders[0] + 24, overlappingSize);
  assert.throws(() => ZipReader.open(overlapping), /overlap/);

  const dishonest = deflatedZip("content/en.json", encoder.encode("{}"));
  const descriptor = signatureOffsets(dishonest, 0x08074b50)[0];
  writeU32(dishonest, descriptor + 8, 99);
  assert.throws(() => ZipReader.open(dishonest), /data descriptor disagrees/);
});

test("the writer rejects duplicate and unsafe names", () => {
  const body = encoder.encode("x");
  assert.throws(
    () => buildZip([{ name: "same.txt", data: body }, { name: "same.txt", data: body }]),
    /duplicate entry/,
  );
  assert.throws(() => buildZip([{ name: "../outside.txt", data: body }]), /unsafe path/);
  assert.throws(() => buildZip([{ name: "/absolute.txt", data: body }]), /unsafe path/);
});

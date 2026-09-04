// Minimal, dependency-free zip support for .prosaryprayer bundles, mirroring the apps'
// deliberately small readers (iOS MinimalZipReader): no encryption or zip64. The writer emits
// stored (uncompressed) entries — bundle payloads are JSON,
// JPEG, and Opus, the latter two already compressed — and the reader additionally inflates
// method-8 entries and verifies optional data descriptors from other conforming writers via
// the browser-native DecompressionStream.

let crcTable: Uint32Array | undefined;

function updateCrc32(crc: number, data: Uint8Array): number {
  if (!crcTable) {
    crcTable = new Uint32Array(256);
    for (let i = 0; i < 256; i++) {
      let c = i;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      crcTable[i] = c >>> 0;
    }
  }
  for (let i = 0; i < data.length; i++) {
    crc = crcTable[(crc ^ data[i]) & 0xff] ^ (crc >>> 8);
  }
  return crc;
}

function crc32(data: Uint8Array): number {
  return (updateCrc32(0xffffffff, data) ^ 0xffffffff) >>> 0;
}

class ByteWriter {
  private chunks: Uint8Array[] = [];
  length = 0;

  bytes(data: Uint8Array): void {
    this.chunks.push(data);
    this.length += data.length;
  }

  u16(value: number): void {
    this.bytes(new Uint8Array([value & 0xff, (value >> 8) & 0xff]));
  }

  u32(value: number): void {
    this.bytes(new Uint8Array([value & 0xff, (value >> 8) & 0xff, (value >> 16) & 0xff, (value >> 24) & 0xff]));
  }

  concat(): Uint8Array {
    const out = new Uint8Array(this.length);
    let offset = 0;
    for (const chunk of this.chunks) {
      out.set(chunk, offset);
      offset += chunk.length;
    }
    return out;
  }
}

export interface ZipFile {
  name: string;
  data: Uint8Array;
}

export const ZIP_LIMITS = {
  entryCount: 4_096,
  centralDirectoryBytes: 16 * 1024 * 1024,
  entryBytes: 256 * 1024 * 1024,
  expandedBytes: 512 * 1024 * 1024,
  jsonBytes: 8 * 1024 * 1024,
  imageBytes: 64 * 1024 * 1024,
  audioBytes: 256 * 1024 * 1024,
} as const;

function validateEntryName(name: string): void {
  if (!name || name.includes("\0") || name.startsWith("/") || name.includes("\\")) {
    throw new Error("A zip entry has an invalid name.");
  }
  const path = name.endsWith("/") ? name.slice(0, -1) : name;
  if (!path || path.split("/").some((part) => !part || part === "." || part === "..")) {
    throw new Error("A zip entry has an unsafe path.");
  }
}

/** Builds a stored (uncompressed) zip — the same shape the iOS tests' storedZip emits. */
export function buildZip(files: ZipFile[]): Uint8Array {
  if (files.length > ZIP_LIMITS.entryCount) {
    throw new Error("This bundle contains too many files.");
  }
  const encoder = new TextEncoder();
  const out = new ByteWriter();
  const central = new ByteWriter();
  const offsets: number[] = [];
  const seenNames = new Set<string>();
  let totalBytes = 0;
  // The local and central headers repeat each entry's metadata. Calculate the expensive CRC
  // once up front instead of scanning large JPEG/Opus payloads a second time.
  const prepared = files.map(({ name, data }) => {
    validateEntryName(name);
    if (name.endsWith("/")) throw new Error("Zip writer accepts files, not directory entries.");
    if (seenNames.has(name)) throw new Error(`Duplicate zip entry: ${name}`);
    seenNames.add(name);
    if (data.length > ZIP_LIMITS.entryBytes) {
      throw new Error(`Zip entry is too large: ${name}`);
    }
    totalBytes += data.length;
    if (totalBytes > ZIP_LIMITS.expandedBytes) {
      throw new Error("The expanded contents of this bundle are too large.");
    }
    const nameBytes = encoder.encode(name);
    if (nameBytes.length > 0xffff) throw new Error("A zip entry name is too long.");
    return { data, nameBytes, crc: crc32(data) };
  });

  for (const { data, nameBytes, crc } of prepared) {
    offsets.push(out.length);
    out.u32(0x04034b50);
    out.u16(20); // version needed
    out.u16(0x0800); // flags: UTF-8 names
    out.u16(0); // method: stored
    out.u16(0);
    out.u16(0); // time/date
    out.u32(crc);
    out.u32(data.length);
    out.u32(data.length);
    out.u16(nameBytes.length);
    out.u16(0); // extra length
    out.bytes(nameBytes);
    out.bytes(data);
  }

  prepared.forEach(({ data, nameBytes, crc }, i) => {
    central.u32(0x02014b50);
    central.u16(20);
    central.u16(20);
    central.u16(0x0800);
    central.u16(0);
    central.u16(0);
    central.u16(0);
    central.u32(crc);
    central.u32(data.length);
    central.u32(data.length);
    central.u16(nameBytes.length);
    central.u16(0);
    central.u16(0);
    central.u16(0);
    central.u16(0);
    central.u32(0);
    central.u32(offsets[i]);
    central.bytes(nameBytes);
  });

  const centralOffset = out.length;
  const centralBytes = central.concat();
  if (centralBytes.length > ZIP_LIMITS.centralDirectoryBytes) {
    throw new Error("This bundle's file index is too large.");
  }
  out.bytes(centralBytes);
  out.u32(0x06054b50);
  out.u16(0);
  out.u16(0);
  out.u16(prepared.length);
  out.u16(prepared.length);
  out.u32(centralBytes.length);
  out.u32(centralOffset);
  out.u16(0);
  return out.concat();
}

interface Entry {
  crc: number;
  method: number;
  compressedSize: number;
  uncompressedSize: number;
  localHeaderOffset: number;
}

function requireRange(total: number, offset: number, length: number, message: string): void {
  if (!Number.isSafeInteger(offset) || !Number.isSafeInteger(length) || offset < 0 || length < 0 || offset > total - length) {
    throw new Error(message);
  }
}

function u16(bytes: Uint8Array, offset: number): number {
  requireRange(bytes.length, offset, 2, "Truncated zip archive.");
  return bytes[offset] | (bytes[offset + 1] << 8);
}

function u32(bytes: Uint8Array, offset: number): number {
  requireRange(bytes.length, offset, 4, "Truncated zip archive.");
  return (
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24)
  ) >>> 0;
}

function sameBytes(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) return false;
  for (let index = 0; index < left.length; index++) {
    if (left[index] !== right[index]) return false;
  }
  return true;
}

async function inflateRaw(
  data: Uint8Array,
  expectedSize: number,
): Promise<{ bytes: Uint8Array; crc: number }> {
  const output = new Uint8Array(expectedSize);
  const stream = new Blob([data as BlobPart])
    .stream()
    .pipeThrough(new DecompressionStream("deflate-raw"));
  const reader = stream.getReader();
  let offset = 0;
  let crc = 0xffffffff;
  let finished = false;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      if (value.length > output.length - offset) {
        throw new Error("A compressed zip entry expands beyond its declared size.");
      }
      output.set(value, offset);
      offset += value.length;
      crc = updateCrc32(crc, value);
    }
    finished = true;
  } catch (error) {
    if (error instanceof Error && error.message.includes("declared size")) throw error;
    throw new Error("Could not decompress a zip entry.", { cause: error });
  } finally {
    if (!finished) await reader.cancel().catch(() => undefined);
  }
  if (offset !== expectedSize) throw new Error("A zip entry did not match its declared size.");
  return { bytes: output, crc: (crc ^ 0xffffffff) >>> 0 };
}

export class ZipReader {
  private constructor(
    private bytes: Uint8Array,
    private entries: Map<string, Entry>,
  ) {}

  static open(bytes: Uint8Array): ZipReader {
    if (bytes.length > ZIP_LIMITS.expandedBytes + ZIP_LIMITS.centralDirectoryBytes) {
      throw new Error("This bundle file is too large.");
    }
    // End-of-central-directory: scan backwards past any zip comment.
    let eocd = -1;
    for (let i = bytes.length - 22; i >= Math.max(0, bytes.length - 22 - 0xffff); i--) {
      if (u32(bytes, i) === 0x06054b50 && i + 22 + u16(bytes, i + 20) === bytes.length) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) throw new Error("Not a zip archive.");

    const disk = u16(bytes, eocd + 4);
    const centralDisk = u16(bytes, eocd + 6);
    const diskCount = u16(bytes, eocd + 8);
    const count = u16(bytes, eocd + 10);
    const centralSize = u32(bytes, eocd + 12);
    const centralOffset = u32(bytes, eocd + 16);
    if (disk !== 0 || centralDisk !== 0 || diskCount !== count) {
      throw new Error("Multi-disk zip archives are not supported.");
    }
    if (count === 0xffff || centralSize === 0xffffffff || centralOffset === 0xffffffff) {
      throw new Error("Zip64 archives are not supported.");
    }
    if (count > ZIP_LIMITS.entryCount) throw new Error("This bundle contains too many files.");
    if (centralSize > ZIP_LIMITS.centralDirectoryBytes) {
      throw new Error("This bundle's file index is too large.");
    }
    requireRange(bytes.length, centralOffset, centralSize, "Corrupt zip central directory.");
    const centralEnd = centralOffset + centralSize;
    if (centralEnd !== eocd) {
      throw new Error("Corrupt zip central directory.");
    }

    let offset = centralOffset;
    let totalUncompressed = 0;
    const decoder = new TextDecoder("utf-8", { fatal: true });
    const entries = new Map<string, Entry>();
    const seenNames = new Set<string>();
    const occupiedRanges: { start: number; end: number }[] = [];
    for (let i = 0; i < count; i++) {
      requireRange(eocd, offset, 46, "Corrupt zip central directory.");
      if (u32(bytes, offset) !== 0x02014b50) throw new Error("Corrupt zip central directory.");
      const flags = u16(bytes, offset + 8);
      const method = u16(bytes, offset + 10);
      const crc = u32(bytes, offset + 16);
      const compressedSize = u32(bytes, offset + 20);
      const uncompressedSize = u32(bytes, offset + 24);
      const nameLength = u16(bytes, offset + 28);
      const extraLength = u16(bytes, offset + 30);
      const commentLength = u16(bytes, offset + 32);
      const diskStart = u16(bytes, offset + 34);
      const localHeaderOffset = u32(bytes, offset + 42);
      if ([compressedSize, uncompressedSize, localHeaderOffset].includes(0xffffffff)) {
        throw new Error("Zip64 archives are not supported.");
      }
      if (diskStart !== 0) throw new Error("Multi-disk zip archives are not supported.");
      if (method !== 0 && method !== 8) throw new Error(`Unsupported compression method ${method}.`);
      if ((flags & 0x0001) !== 0) throw new Error("Encrypted zip entries are not supported.");
      const allowedFlags = 0x0800 | 0x0008 | (method === 8 ? 0x0006 : 0);
      if ((flags & ~allowedFlags) !== 0) throw new Error("Unsupported zip entry flags.");
      if (method === 0 && compressedSize !== uncompressedSize) {
        throw new Error("A stored zip entry has inconsistent sizes.");
      }
      if (compressedSize > ZIP_LIMITS.entryBytes || uncompressedSize > ZIP_LIMITS.entryBytes) {
        throw new Error("A file in this bundle is too large.");
      }
      totalUncompressed += uncompressedSize;
      if (totalUncompressed > ZIP_LIMITS.expandedBytes) {
        throw new Error("The expanded contents of this bundle are too large.");
      }

      const recordLength = 46 + nameLength + extraLength + commentLength;
      requireRange(eocd, offset, recordLength, "Corrupt zip central directory.");
      const centralNameBytes = bytes.subarray(offset + 46, offset + 46 + nameLength);
      let name: string;
      try {
        name = decoder.decode(centralNameBytes);
      } catch {
        throw new Error("A zip entry has an invalid UTF-8 name.");
      }
      validateEntryName(name);
      if (seenNames.has(name)) throw new Error(`Duplicate zip entry: ${name}`);
      seenNames.add(name);

      requireRange(centralOffset, localHeaderOffset, 30, "Corrupt zip local header.");
      if (u32(bytes, localHeaderOffset) !== 0x04034b50) throw new Error("Corrupt zip local header.");
      const localFlags = u16(bytes, localHeaderOffset + 6);
      const localMethod = u16(bytes, localHeaderOffset + 8);
      const localCrc = u32(bytes, localHeaderOffset + 14);
      const localCompressedSize = u32(bytes, localHeaderOffset + 18);
      const localUncompressedSize = u32(bytes, localHeaderOffset + 22);
      const localNameLength = u16(bytes, localHeaderOffset + 26);
      const localExtraLength = u16(bytes, localHeaderOffset + 28);
      const localNameStart = localHeaderOffset + 30;
      requireRange(centralOffset, localNameStart, localNameLength + localExtraLength, "Corrupt zip local header.");
      const localNameBytes = bytes.subarray(localNameStart, localNameStart + localNameLength);
      if (localFlags !== flags || localMethod !== method || !sameBytes(localNameBytes, centralNameBytes)) {
        throw new Error("Zip local and central headers disagree.");
      }
      const usesDescriptor = (flags & 0x0008) !== 0;
      const localValuesAreEmpty =
        localCrc === 0 && localCompressedSize === 0 && localUncompressedSize === 0;
      const localValuesMatch =
        localCrc === crc &&
        localCompressedSize === compressedSize &&
        localUncompressedSize === uncompressedSize;
      if (usesDescriptor ? !localValuesAreEmpty && !localValuesMatch : !localValuesMatch) {
        throw new Error("Zip local and central headers disagree.");
      }
      const payloadStart = localNameStart + localNameLength + localExtraLength;
      requireRange(centralOffset, payloadStart, compressedSize, "A zip entry extends beyond its data area.");
      let entryEnd = payloadStart + compressedSize;
      if (usesDescriptor) {
        let descriptorStart = entryEnd;
        requireRange(centralOffset, descriptorStart, 12, "A zip data descriptor is truncated.");
        if (u32(bytes, descriptorStart) === 0x08074b50) {
          descriptorStart += 4;
          requireRange(centralOffset, descriptorStart, 12, "A zip data descriptor is truncated.");
        }
        if (
          u32(bytes, descriptorStart) !== crc ||
          u32(bytes, descriptorStart + 4) !== compressedSize ||
          u32(bytes, descriptorStart + 8) !== uncompressedSize
        ) {
          throw new Error("A zip data descriptor disagrees with its central header.");
        }
        entryEnd = descriptorStart + 12;
      }
      occupiedRanges.push({ start: localHeaderOffset, end: entryEnd });
      if (!name.endsWith("/")) {
        entries.set(name, { crc, method, compressedSize, uncompressedSize, localHeaderOffset });
      } else if (compressedSize !== 0 || uncompressedSize !== 0) {
        throw new Error("A zip directory entry contains a payload.");
      }
      offset += recordLength;
    }
    if (offset !== centralEnd) throw new Error("Corrupt zip central directory.");
    occupiedRanges.sort((left, right) => left.start - right.start);
    for (let i = 1; i < occupiedRanges.length; i++) {
      if (occupiedRanges[i].start < occupiedRanges[i - 1].end) {
        throw new Error("Zip entries overlap.");
      }
    }
    return new ZipReader(bytes, entries);
  }

  names(): string[] {
    return [...this.entries.keys()];
  }

  has(name: string): boolean {
    return this.entries.has(name);
  }

  async contents(name: string, maxBytes = ZIP_LIMITS.entryBytes): Promise<Uint8Array> {
    const entry = this.entries.get(name);
    if (!entry) throw new Error(`No such entry: ${name}`);
    if (entry.uncompressedSize > maxBytes) throw new Error(`Zip entry is too large: ${name}`);
    const { bytes } = this;
    const header = entry.localHeaderOffset;
    const nameLength = u16(bytes, header + 26);
    const extraLength = u16(bytes, header + 28);
    const start = header + 30 + nameLength + extraLength;
    const raw = bytes.subarray(start, start + entry.compressedSize);
    const inflated = entry.method === 0 ? undefined : await inflateRaw(raw, entry.uncompressedSize);
    const content = inflated?.bytes ?? raw;
    const actualCrc = inflated?.crc ?? crc32(raw);
    if (content.length !== entry.uncompressedSize || actualCrc !== entry.crc) {
      throw new Error(`Zip entry failed its integrity check: ${name}`);
    }
    // A stored entry is a view into the entire archive. Detach it so retaining one image/audio
    // payload does not also pin every unrelated zip byte in memory after openBundle returns.
    return entry.method === 0 ? content.slice() : content;
  }

  async json(name: string): Promise<unknown> {
    return JSON.parse(
      new TextDecoder().decode(await this.contents(name, ZIP_LIMITS.jsonBytes)),
    );
  }
}

// Minimal, dependency-free zip support for .prosaryprayer bundles — a copy of
// Compose/src/format/zip.ts (keep them in sync), isomorphic across browser and Node 20+:
// Blob/Response/DecompressionStream are global in both. The server uses the reader to
// validate submissions and the writer to re-stamp manifest ids (see lib/bundles.ts).

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

/** Builds a stored (uncompressed) zip — the same shape the iOS tests' storedZip emits. */
export function buildZip(files: ZipFile[]): Uint8Array {
  if (files.length > ZIP64_U16 - 1) {
    throw new Error("ZIP64 archives are unsupported.");
  }
  const encoder = new TextEncoder();
  const out = new ByteWriter();
  const central = new ByteWriter();
  const offsets: number[] = [];
  const seenNames = new Set<string>();
  // Local and central headers repeat this metadata. Preparing it once avoids scanning large
  // JPEG/Opus payloads twice merely to emit the same CRC.
  const prepared = files.map(({ name, data }) => {
    validateEntryName(name);
    if (name.endsWith("/")) throw new Error("buildZip accepts files, not directory entries.");
    if (seenNames.has(name)) throw new Error(`ZIP archive contains duplicate entry ${name}.`);
    seenNames.add(name);
    const nameBytes = encoder.encode(name);
    if (nameBytes.length > ZIP64_U16 - 1 || data.length >= ZIP64_U32) {
      throw new Error("ZIP64 entries are unsupported.");
    }
    return { data, nameBytes, crc: crc32(data) };
  });

  for (const { data, nameBytes, crc } of prepared) {
    if (out.length >= ZIP64_U32) throw new Error("ZIP64 archives are unsupported.");
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
  if (centralOffset >= ZIP64_U32 || centralBytes.length >= ZIP64_U32) {
    throw new Error("ZIP64 archives are unsupported.");
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

const EOCD_SIGNATURE = 0x06054b50;
const CENTRAL_HEADER_SIGNATURE = 0x02014b50;
const LOCAL_HEADER_SIGNATURE = 0x04034b50;
const EOCD_BYTES = 22;
const CENTRAL_HEADER_BYTES = 46;
const LOCAL_HEADER_BYTES = 30;
const MAX_ZIP_COMMENT_BYTES = 0xffff;
const ZIP64_U16 = 0xffff;
const ZIP64_U32 = 0xffffffff;
const STORED = 0;
const DEFLATED = 8;
const DATA_DESCRIPTOR_FLAG = 0x0008;
const DEFLATE_OPTION_FLAGS = 0x0006;
const UTF8_FLAG = 0x0800;
const ALLOWED_FLAGS = DATA_DESCRIPTOR_FLAG | DEFLATE_OPTION_FLAGS | UTF8_FLAG;

export type ZipReaderLimits = {
  maxEntries: number;
  maxCentralDirectoryBytes: number;
  maxEntryUncompressedBytes: number;
  maxTotalUncompressedBytes: number;
};

export const DEFAULT_ZIP_READER_LIMITS: ZipReaderLimits = {
  maxEntries: 4096,
  maxCentralDirectoryBytes: 16 * 1024 * 1024,
  maxEntryUncompressedBytes: 256 * 1024 * 1024,
  maxTotalUncompressedBytes: 512 * 1024 * 1024,
};

interface Entry {
  method: number;
  crc: number;
  compressedSize: number;
  uncompressedSize: number;
  dataOffset: number;
}

interface LocalRange {
  start: number;
  end: number;
  name: string;
}

function requireRange(offset: number, length: number, end: number, label: string): void {
  if (
    !Number.isSafeInteger(offset) ||
    !Number.isSafeInteger(length) ||
    offset < 0 ||
    length < 0 ||
    offset > end - length
  ) {
    throw new Error(`${label} points outside the zip archive.`);
  }
}

function u16(bytes: Uint8Array, offset: number): number {
  requireRange(offset, 2, bytes.length, "ZIP field");
  return bytes[offset] | (bytes[offset + 1] << 8);
}

function u32(bytes: Uint8Array, offset: number): number {
  requireRange(offset, 4, bytes.length, "ZIP field");
  return (bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24)) >>> 0;
}

function sameBytes(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) return false;
  for (let i = 0; i < left.length; i++) {
    if (left[i] !== right[i]) return false;
  }
  return true;
}

function validateEntryName(name: string): void {
  const segments = name.split("/");
  const isDirectory = name.endsWith("/");
  if (
    !name ||
    name.startsWith("/") ||
    name.includes("\\") ||
    name.includes("\0") ||
    segments.some((segment, index) => {
      const trailingDirectorySegment = isDirectory && index === segments.length - 1;
      return segment === "." || segment === ".." || (!segment && !trailingDirectorySegment);
    })
  ) {
    throw new Error("ZIP entry has an unsafe path.");
  }
}

async function inflateRaw(
  data: Uint8Array,
  expectedSize: number,
  maxOutputBytes: number,
): Promise<{ bytes: Uint8Array; crc: number }> {
  const stream = new Blob([data as BlobPart])
    .stream()
    .pipeThrough(new DecompressionStream("deflate-raw"));
  const reader = stream.getReader();
  const output = new Uint8Array(expectedSize);
  let offset = 0;
  let crc = 0xffffffff;

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (offset + value.byteLength > expectedSize || offset + value.byteLength > maxOutputBytes) {
        await reader.cancel().catch(() => {});
        throw new Error("Deflated ZIP entry exceeds its declared or allowed size.");
      }
      output.set(value, offset);
      offset += value.byteLength;
      crc = updateCrc32(crc, value);
    }
  } catch (error) {
    await reader.cancel().catch(() => {});
    throw error;
  }

  if (offset !== expectedSize) {
    throw new Error("Deflated ZIP entry ended before its declared size.");
  }
  return { bytes: output, crc: (crc ^ 0xffffffff) >>> 0 };
}

export class ZipReader {
  private bytes: Uint8Array;
  private entries: Map<string, Entry>;
  private limits: ZipReaderLimits;

  private constructor(
    bytes: Uint8Array,
    entries: Map<string, Entry>,
    limits: ZipReaderLimits,
  ) {
    this.bytes = bytes;
    this.entries = entries;
    this.limits = limits;
  }

  static open(bytes: Uint8Array, overrides: Partial<ZipReaderLimits> = {}): ZipReader {
    const limits = { ...DEFAULT_ZIP_READER_LIMITS, ...overrides };
    if (
      Object.values(limits).some(
        (limit) => !Number.isSafeInteger(limit) || limit < 0,
      )
    ) {
      throw new Error("ZIP reader limits must be non-negative safe integers.");
    }
    if (bytes.length < EOCD_BYTES) throw new Error("Not a zip archive.");

    // An EOCD signature inside the comment is not an end record. The candidate's comment must
    // consume the exact remaining bytes.
    let eocd = -1;
    const firstCandidate = Math.max(0, bytes.length - EOCD_BYTES - MAX_ZIP_COMMENT_BYTES);
    for (let offset = bytes.length - EOCD_BYTES; offset >= firstCandidate; offset--) {
      if (
        u32(bytes, offset) === EOCD_SIGNATURE &&
        offset + EOCD_BYTES + u16(bytes, offset + 20) === bytes.length
      ) {
        eocd = offset;
        break;
      }
    }
    if (eocd < 0) throw new Error("ZIP end record is missing or malformed.");

    const diskNumber = u16(bytes, eocd + 4);
    const centralDisk = u16(bytes, eocd + 6);
    const entriesOnDisk = u16(bytes, eocd + 8);
    const entryCount = u16(bytes, eocd + 10);
    const centralSize = u32(bytes, eocd + 12);
    const centralOffset = u32(bytes, eocd + 16);
    if (
      diskNumber !== 0 ||
      centralDisk !== 0 ||
      entriesOnDisk !== entryCount ||
      entryCount === ZIP64_U16 ||
      centralSize === ZIP64_U32 ||
      centralOffset === ZIP64_U32
    ) {
      throw new Error("Multi-disk and ZIP64 archives are unsupported.");
    }
    if (entryCount > limits.maxEntries) throw new Error("ZIP archive contains too many entries.");
    if (centralSize > limits.maxCentralDirectoryBytes) {
      throw new Error("ZIP central directory is too large.");
    }
    requireRange(centralOffset, centralSize, eocd, "ZIP central directory");

    const centralEnd = centralOffset + centralSize;
    const decoder = new TextDecoder("utf-8", { fatal: true });
    const seenNames = new Set<string>();
    const entries = new Map<string, Entry>();
    const localRanges: LocalRange[] = [];
    let totalUncompressedSize = 0;
    let cursor = centralOffset;

    for (let i = 0; i < entryCount; i++) {
      requireRange(cursor, CENTRAL_HEADER_BYTES, centralEnd, "ZIP central-directory entry");
      if (u32(bytes, cursor) !== CENTRAL_HEADER_SIGNATURE) {
        throw new Error("Corrupt ZIP central directory.");
      }

      const flags = u16(bytes, cursor + 8);
      const method = u16(bytes, cursor + 10);
      const crc = u32(bytes, cursor + 16);
      const compressedSize = u32(bytes, cursor + 20);
      const uncompressedSize = u32(bytes, cursor + 24);
      const nameLength = u16(bytes, cursor + 28);
      const extraLength = u16(bytes, cursor + 30);
      const commentLength = u16(bytes, cursor + 32);
      const startDisk = u16(bytes, cursor + 34);
      const localHeaderOffset = u32(bytes, cursor + 42);
      if (
        startDisk !== 0 ||
        compressedSize === ZIP64_U32 ||
        uncompressedSize === ZIP64_U32 ||
        localHeaderOffset === ZIP64_U32
      ) {
        throw new Error("Multi-disk and ZIP64 entries are unsupported.");
      }
      if (method !== STORED && method !== DEFLATED) {
        throw new Error(`Unsupported ZIP compression method ${method}.`);
      }
      if ((flags & ~ALLOWED_FLAGS) !== 0 || (method === STORED && (flags & DEFLATE_OPTION_FLAGS) !== 0)) {
        throw new Error("Encrypted or unsupported ZIP entry flags.");
      }
      if (uncompressedSize > limits.maxEntryUncompressedBytes) {
        throw new Error("ZIP entry exceeds the uncompressed-size limit.");
      }
      totalUncompressedSize += uncompressedSize;
      if (totalUncompressedSize > limits.maxTotalUncompressedBytes) {
        throw new Error("ZIP archive exceeds the aggregate uncompressed-size limit.");
      }

      const recordLength = CENTRAL_HEADER_BYTES + nameLength + extraLength + commentLength;
      requireRange(cursor, recordLength, centralEnd, "ZIP central-directory entry");
      const centralNameBytes = bytes.subarray(
        cursor + CENTRAL_HEADER_BYTES,
        cursor + CENTRAL_HEADER_BYTES + nameLength,
      );
      let name: string;
      try {
        name = decoder.decode(centralNameBytes);
      } catch {
        throw new Error("ZIP entry name is not valid UTF-8.");
      }
      validateEntryName(name);
      if (seenNames.has(name)) throw new Error(`ZIP archive contains duplicate entry ${name}.`);
      seenNames.add(name);

      requireRange(localHeaderOffset, LOCAL_HEADER_BYTES, centralOffset, "ZIP local header");
      if (u32(bytes, localHeaderOffset) !== LOCAL_HEADER_SIGNATURE) {
        throw new Error("Corrupt ZIP local header.");
      }
      const localFlags = u16(bytes, localHeaderOffset + 6);
      const localMethod = u16(bytes, localHeaderOffset + 8);
      const localCrc = u32(bytes, localHeaderOffset + 14);
      const localCompressedSize = u32(bytes, localHeaderOffset + 18);
      const localUncompressedSize = u32(bytes, localHeaderOffset + 22);
      const localNameLength = u16(bytes, localHeaderOffset + 26);
      const localExtraLength = u16(bytes, localHeaderOffset + 28);
      const localVariableLength = localNameLength + localExtraLength;
      requireRange(
        localHeaderOffset + LOCAL_HEADER_BYTES,
        localVariableLength,
        centralOffset,
        "ZIP local name and extra data",
      );
      const localNameBytes = bytes.subarray(
        localHeaderOffset + LOCAL_HEADER_BYTES,
        localHeaderOffset + LOCAL_HEADER_BYTES + localNameLength,
      );
      if (
        localFlags !== flags ||
        localMethod !== method ||
        !sameBytes(localNameBytes, centralNameBytes)
      ) {
        throw new Error("ZIP local and central headers disagree.");
      }

      const usesDataDescriptor = (flags & DATA_DESCRIPTOR_FLAG) !== 0;
      const localSizesAreZero =
        localCrc === 0 && localCompressedSize === 0 && localUncompressedSize === 0;
      const localMetadataMatches =
        localCrc === crc &&
        localCompressedSize === compressedSize &&
        localUncompressedSize === uncompressedSize;
      if (
        (!usesDataDescriptor && !localMetadataMatches) ||
        (usesDataDescriptor && !localSizesAreZero && !localMetadataMatches)
      ) {
        throw new Error("ZIP local and central sizes or CRC disagree.");
      }
      if (method === STORED && compressedSize !== uncompressedSize) {
        throw new Error("Stored ZIP entry has inconsistent sizes.");
      }

      const dataOffset = localHeaderOffset + LOCAL_HEADER_BYTES + localVariableLength;
      requireRange(dataOffset, compressedSize, centralOffset, "ZIP entry payload");
      let localEnd = dataOffset + compressedSize;
      if (usesDataDescriptor) {
        let descriptorOffset = localEnd;
        requireRange(descriptorOffset, 12, centralOffset, "ZIP data descriptor");
        if (u32(bytes, descriptorOffset) === 0x08074b50) {
          descriptorOffset += 4;
          requireRange(descriptorOffset, 12, centralOffset, "ZIP data descriptor");
        }
        if (
          u32(bytes, descriptorOffset) !== crc ||
          u32(bytes, descriptorOffset + 4) !== compressedSize ||
          u32(bytes, descriptorOffset + 8) !== uncompressedSize
        ) {
          throw new Error("ZIP data descriptor disagrees with its central header.");
        }
        localEnd = descriptorOffset + 12;
      }
      localRanges.push({ start: localHeaderOffset, end: localEnd, name });
      if (!name.endsWith("/")) {
        entries.set(name, { method, crc, compressedSize, uncompressedSize, dataOffset });
      } else if (compressedSize !== 0 || uncompressedSize !== 0) {
        throw new Error("ZIP directory entry contains a payload.");
      }
      cursor += recordLength;
    }
    if (cursor !== centralEnd) throw new Error("ZIP central-directory size does not match its entries.");

    localRanges.sort((left, right) => left.start - right.start);
    for (let i = 1; i < localRanges.length; i++) {
      const previous = localRanges[i - 1];
      const current = localRanges[i];
      if (previous.end > current.start) {
        throw new Error(`ZIP entries ${previous.name} and ${current.name} overlap.`);
      }
    }

    return new ZipReader(bytes, entries, limits);
  }

  names(): string[] {
    return [...this.entries.keys()];
  }

  has(name: string): boolean {
    return this.entries.has(name);
  }

  async contents(name: string): Promise<Uint8Array> {
    const entry = this.entries.get(name);
    if (!entry) throw new Error(`No such entry: ${name}`);
    const raw = this.bytes.subarray(entry.dataOffset, entry.dataOffset + entry.compressedSize);
    let contents: Uint8Array;
    let actualCrc: number;
    if (entry.method === STORED) {
      contents = raw;
      actualCrc = crc32(contents);
    } else {
      const inflated = await inflateRaw(
        raw,
        entry.uncompressedSize,
        this.limits.maxEntryUncompressedBytes,
      );
      contents = inflated.bytes;
      actualCrc = inflated.crc;
    }
    if (contents.length !== entry.uncompressedSize) {
      throw new Error("ZIP entry length does not match its central-directory size.");
    }
    if (actualCrc !== entry.crc) throw new Error("ZIP entry failed its CRC check.");
    return contents;
  }

  async json(name: string): Promise<unknown> {
    return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(await this.contents(name)));
  }
}

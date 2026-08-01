// Minimal, dependency-free zip support for .prosaryprayer bundles — a copy of
// Compose/src/format/zip.ts (keep them in sync), isomorphic across browser and Node 20+:
// Blob/Response/DecompressionStream are global in both. The server uses the reader to
// validate submissions and the writer to re-stamp manifest ids (see lib/bundles.ts).

let crcTable: Uint32Array | undefined;

function crc32(data: Uint8Array): number {
  if (!crcTable) {
    crcTable = new Uint32Array(256);
    for (let i = 0; i < 256; i++) {
      let c = i;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      crcTable[i] = c >>> 0;
    }
  }
  let crc = 0xffffffff;
  for (let i = 0; i < data.length; i++) {
    crc = crcTable[(crc ^ data[i]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
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
  const encoder = new TextEncoder();
  const out = new ByteWriter();
  const central = new ByteWriter();
  const offsets: number[] = [];

  for (const { name, data } of files) {
    offsets.push(out.length);
    const nameBytes = encoder.encode(name);
    const crc = crc32(data);
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

  files.forEach(({ name, data }, i) => {
    const nameBytes = encoder.encode(name);
    const crc = crc32(data);
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
  out.bytes(centralBytes);
  out.u32(0x06054b50);
  out.u16(0);
  out.u16(0);
  out.u16(files.length);
  out.u16(files.length);
  out.u32(centralBytes.length);
  out.u32(centralOffset);
  out.u16(0);
  return out.concat();
}

interface Entry {
  method: number;
  compressedSize: number;
  localHeaderOffset: number;
}

async function inflateRaw(data: Uint8Array): Promise<Uint8Array> {
  const stream = new Blob([data as BlobPart]).stream().pipeThrough(new DecompressionStream("deflate-raw"));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

export class ZipReader {
  private constructor(
    private bytes: Uint8Array,
    private entries: Map<string, Entry>,
  ) {}

  static open(bytes: Uint8Array): ZipReader {
    const u16 = (o: number) => bytes[o] | (bytes[o + 1] << 8);
    const u32 = (o: number) => (bytes[o] | (bytes[o + 1] << 8) | (bytes[o + 2] << 16) | (bytes[o + 3] << 24)) >>> 0;

    // End-of-central-directory: scan backwards past any zip comment.
    let eocd = -1;
    for (let i = bytes.length - 22; i >= Math.max(0, bytes.length - 22 - 0xffff); i--) {
      if (u32(i) === 0x06054b50) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) throw new Error("Not a zip archive.");

    const count = u16(eocd + 10);
    let offset = u32(eocd + 16);
    const decoder = new TextDecoder();
    const entries = new Map<string, Entry>();
    for (let i = 0; i < count; i++) {
      if (u32(offset) !== 0x02014b50) throw new Error("Corrupt zip central directory.");
      const method = u16(offset + 10);
      const compressedSize = u32(offset + 20);
      const nameLength = u16(offset + 28);
      const extraLength = u16(offset + 30);
      const commentLength = u16(offset + 32);
      const localHeaderOffset = u32(offset + 42);
      const name = decoder.decode(bytes.subarray(offset + 46, offset + 46 + nameLength));
      if (!name.endsWith("/")) {
        entries.set(name, { method, compressedSize, localHeaderOffset });
      }
      offset += 46 + nameLength + extraLength + commentLength;
    }
    return new ZipReader(bytes, entries);
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
    const { bytes } = this;
    const u16 = (o: number) => bytes[o] | (bytes[o + 1] << 8);
    const header = entry.localHeaderOffset;
    const nameLength = u16(header + 26);
    const extraLength = u16(header + 28);
    const start = header + 30 + nameLength + extraLength;
    const raw = bytes.subarray(start, start + entry.compressedSize);
    if (entry.method === 0) return raw;
    if (entry.method === 8) return inflateRaw(raw);
    throw new Error(`Unsupported compression method ${entry.method}.`);
  }

  async json(name: string): Promise<unknown> {
    return JSON.parse(new TextDecoder().decode(await this.contents(name)));
  }
}

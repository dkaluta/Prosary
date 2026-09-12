import { SRGB_PROFILE } from "./srgbProfile";

interface Part { marker: number; bytes: Uint8Array }
const text = new TextDecoder("ascii");
const startsWith = (bytes: Uint8Array, prefix: string) => text.decode(bytes.subarray(0, prefix.length)) === prefix;

/** Read one complete JPEG, including progressive scans; appended gain-map images are separate. */
function parts(bytes: Uint8Array): Part[] {
  if (bytes[0] !== 0xff || bytes[1] !== 0xd8) throw new Error("The image is not a JPEG.");
  const result: Part[] = [];
  let offset = 2;
  while (offset < bytes.length) {
    const start = offset;
    if (bytes[offset++] !== 0xff) throw new Error("The JPEG has an invalid marker.");
    while (bytes[offset] === 0xff) offset++;
    const marker = bytes[offset++];
    if (marker === 0xd9) { result.push({ marker, bytes: bytes.subarray(start, offset) }); return result; }
    if (!marker || marker === 0xd8 || marker >= 0xd0 && marker <= 0xd7) throw new Error("The JPEG has an unexpected marker.");
    const length = (bytes[offset] << 8) | bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length) throw new Error("The JPEG is incomplete.");
    offset += length;
    if (marker === 0xda) {
      while (offset < bytes.length) {
        if (bytes[offset] !== 0xff) { offset++; continue; }
        let next = offset + 1;
        while (bytes[next] === 0xff) next++;
        if (bytes[next] === 0 || bytes[next] >= 0xd0 && bytes[next] <= 0xd7) { offset = next + 1; continue; }
        break;
      }
    }
    result.push({ marker, bytes: bytes.subarray(start, offset) });
  }
  throw new Error("The JPEG has no end marker.");
}

function frame(parts: Part[]) {
  const frames = parts.filter(({ marker }) => [0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].includes(marker));
  if (frames.length !== 1) throw new Error("The JPEG must contain one RGB image.");
  const data = frames[0].bytes;
  return { precision: data[4], height: (data[5] << 8) | data[6], width: (data[7] << 8) | data[8], components: data[9] };
}

/** Attach only after a real sRGB conversion. Tagging arbitrary input does not convert its colors. */
export function tagConvertedSrgbJpeg(bytes: Uint8Array): Uint8Array {
  const segments = parts(bytes);
  const info = frame(segments);
  if (info.precision !== 8 || info.components !== 3 || !info.width || !info.height) {
    throw new Error("The browser did not produce an 8-bit RGB JPEG.");
  }
  const header = new Uint8Array(18 + SRGB_PROFILE.length);
  header.set([0xff, 0xe2, (header.length - 2) >> 8, (header.length - 2) & 255]);
  header.set(new TextEncoder().encode("ICC_PROFILE\0"), 4);
  header.set([1, 1], 16);
  header.set(SRGB_PROFILE, 18);
  const retained = segments.filter(({ marker, bytes: segment }) =>
    !(marker >= 0xe0 && marker <= 0xef || marker === 0xfe) ||
    marker === 0xe0 && startsWith(segment.subarray(4), "JFIF\0"));
  const result = new Uint8Array(2 + header.length + retained.reduce((sum, part) => sum + part.bytes.length, 0));
  result.set([0xff, 0xd8]);
  result.set(header, 2);
  let offset = 2 + header.length;
  for (const part of retained) { result.set(part.bytes, offset); offset += part.bytes.length; }
  return result;
}

export function inspectSrgbJpeg(bytes: Uint8Array) {
  const segments = parts(bytes);
  const info = frame(segments);
  const profiles = segments.filter(({ marker }) => marker === 0xe2);
  const exactProfile = profiles.length === 1 && profiles[0].bytes.length === SRGB_PROFILE.length + 18 &&
    startsWith(profiles[0].bytes.subarray(4), "ICC_PROFILE\0") &&
    profiles[0].bytes[16] === 1 && profiles[0].bytes[17] === 1 &&
    SRGB_PROFILE.every((byte, i) => byte === profiles[0].bytes[i + 18]);
  const unwantedMetadata = segments.some(({ marker, bytes: segment }) =>
    marker === 0xfe || marker >= 0xe0 && marker <= 0xef && marker !== 0xe2 &&
    !(marker === 0xe0 && startsWith(segment.subarray(4), "JFIF\0")));
  const length = 2 + segments.reduce((sum, part) => sum + part.bytes.length, 0);
  return { ...info, exactProfile, unwantedMetadata, trailingBytes: bytes.length - length };
}

const checked = new WeakMap<Uint8Array, boolean>();
export function isSdrSrgbJpeg(bytes: Uint8Array): boolean {
  if (checked.has(bytes)) return checked.get(bytes)!;
  let valid = false;
  try {
    const info = inspectSrgbJpeg(bytes);
    valid = info.precision === 8 && info.components === 3 && info.width > 0 && info.height > 0 &&
      info.exactProfile && !info.unwantedMetadata && info.trailingBytes === 0;
  } catch { /* A legacy image must be decoded and normalized before new export. */ }
  checked.set(bytes, valid);
  return valid;
}

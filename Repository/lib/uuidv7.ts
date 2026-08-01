import { randomBytes } from "node:crypto";

// Same-millisecond calls take a 12-bit counter in rand_a (RFC 9562 §6.2 Method 1,
// randomly seeded per tick, borrowing into the timestamp on overflow) so ids from one
// process sort in generation order; across processes, ordering is millisecond-grade.
let lastMs = 0;
let seq = 0;

/** RFC 9562 UUIDv7 (Node has no built-in v7 generator): a 48-bit Unix-millisecond
 * timestamp, a monotonic sequence, then random bits — ids and blob keys sort
 * chronologically. */
export function uuidv7(): string {
  const bytes = randomBytes(16);
  let ms = Date.now();
  if (ms <= lastMs) {
    ms = lastMs;
    seq += 1;
    if (seq > 0xfff) {
      seq = 0;
      ms += 1;
    }
  } else {
    seq = ((bytes[6] & 0x07) << 8) | bytes[7]; // random 11-bit seed leaves headroom
  }
  lastMs = ms;

  bytes[0] = (ms / 2 ** 40) & 0xff;
  bytes[1] = (ms / 2 ** 32) & 0xff;
  bytes[2] = (ms / 2 ** 24) & 0xff;
  bytes[3] = (ms / 2 ** 16) & 0xff;
  bytes[4] = (ms / 2 ** 8) & 0xff;
  bytes[5] = ms & 0xff;
  bytes[6] = 0x70 | ((seq >> 8) & 0x0f); // version 7 + counter high bits
  bytes[7] = seq & 0xff;
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
  const hex = bytes.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

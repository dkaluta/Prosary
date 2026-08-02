// All Postgres access, via postgres.js tagged templates (interpolations
// auto-parameterize — freebee's conventions). Schema lives in migrations/.

import { randomBytes } from "node:crypto";
import type { Sql } from "postgres";
import { createSqlClient } from "./db-connection.ts";
import { uuidv7 } from "./uuidv7.ts";

let _sql: Sql | null = null;

function sql(): Sql {
  _sql ??= createSqlClient();
  return _sql;
}

// --- Users ---

export type User = {
  id: string;
  username: string;
  email: string;
  created_at: string;
};

const USERNAME_SHAPE = /^[a-z][a-z0-9-]{2,29}$/;

/** Lowercase letters/digits/dashes, 3–30 chars, starts with a letter — it becomes the
 * `repo.<username>.*` namespace, so it must stay URL- and id-safe. */
export function normalizeUsername(raw: string): string | null {
  const username = raw.trim().toLowerCase();
  return USERNAME_SHAPE.test(username) ? username : null;
}

export async function findUserById(id: string): Promise<User | null> {
  const rows = await sql()<User[]>`SELECT * FROM users WHERE id = ${id}`;
  return rows[0] ?? null;
}

export async function findUserByUsername(username: string): Promise<User | null> {
  const rows = await sql()<User[]>`SELECT * FROM users WHERE username = ${username}`;
  return rows[0] ?? null;
}

export async function findUserByEmail(email: string): Promise<User | null> {
  const rows = await sql()<User[]>`SELECT * FROM users WHERE email = ${email}`;
  return rows[0] ?? null;
}

export async function createUser(user: { id: string; username: string; email: string }): Promise<void> {
  await sql()`INSERT INTO users (id, username, email) VALUES (${user.id}, ${user.username}, ${user.email})`;
}

/** Every blob URL the user's bundles occupy — fetched before deletion so the files can be
 * removed from storage alongside the rows. */
export async function bundleFileUrlsForUser(userId: string): Promise<string[]> {
  const rows = await sql()<{ file_url: string }[]>`SELECT file_url FROM bundles WHERE user_id = ${userId}`;
  return rows.map((r) => r.file_url);
}

/** Removes the account and, via ON DELETE CASCADE, its passkeys, pending recovery tokens,
 * and bundle rows. */
export async function deleteUser(userId: string): Promise<void> {
  await sql()`DELETE FROM users WHERE id = ${userId}`;
}

// --- Passkeys ---

export type Passkey = {
  credential_id: string;
  user_id: string;
  public_key: string;
  counter: string; // BIGINT arrives as string
  transports: string | null;
  name: string | null;
  created_at: string;
};

export async function getPasskeysForUser(userId: string): Promise<Passkey[]> {
  return sql()<Passkey[]>`SELECT * FROM passkeys WHERE user_id = ${userId} ORDER BY created_at`;
}

export async function findPasskey(credentialId: string): Promise<Passkey | null> {
  const rows = await sql()<Passkey[]>`SELECT * FROM passkeys WHERE credential_id = ${credentialId}`;
  return rows[0] ?? null;
}

export async function insertPasskey(passkey: {
  credentialId: string;
  userId: string;
  publicKey: string;
  counter: number;
  transports: string | null;
}): Promise<void> {
  await sql()`
    INSERT INTO passkeys (credential_id, user_id, public_key, counter, transports)
    VALUES (${passkey.credentialId}, ${passkey.userId}, ${passkey.publicKey}, ${passkey.counter}, ${passkey.transports})`;
}

export async function updatePasskeyCounter(credentialId: string, counter: number): Promise<void> {
  await sql()`UPDATE passkeys SET counter = ${counter} WHERE credential_id = ${credentialId}`;
}

export async function renamePasskey(credentialId: string, userId: string, name: string): Promise<boolean> {
  const rows = await sql()`
    UPDATE passkeys SET name = ${name.slice(0, 60)}
    WHERE credential_id = ${credentialId} AND user_id = ${userId} RETURNING credential_id`;
  return rows.length > 0;
}

/** Owner-scoped; the route refuses to delete the last one so accounts can't lock themselves
 * out short of the email recovery flow. */
export async function deletePasskey(credentialId: string, userId: string): Promise<boolean> {
  const rows = await sql()`
    DELETE FROM passkeys WHERE credential_id = ${credentialId} AND user_id = ${userId} RETURNING credential_id`;
  return rows.length > 0;
}

// --- WebAuthn challenges (consumed exactly once) ---

export type ChallengeKind = "signup" | "login" | "add" | "recovery";

export type PendingChallenge = {
  challenge: string;
  kind: ChallengeKind;
  user_id: string | null;
  username: string | null;
  email: string | null;
};

const CHALLENGE_TTL_MINUTES = 10;

export async function saveChallenge(pending: {
  challenge: string;
  kind: ChallengeKind;
  userId?: string;
  username?: string;
  email?: string;
}): Promise<void> {
  await sql()`
    INSERT INTO webauthn_challenges (challenge, kind, user_id, username, email, expires_at)
    VALUES (${pending.challenge}, ${pending.kind}, ${pending.userId ?? null},
            ${pending.username ?? null}, ${pending.email ?? null},
            NOW() + make_interval(mins => ${CHALLENGE_TTL_MINUTES}))`;
}

export async function takeChallenge(challenge: string, kind: ChallengeKind): Promise<PendingChallenge | null> {
  const rows = await sql()<PendingChallenge[]>`
    DELETE FROM webauthn_challenges
    WHERE challenge = ${challenge} AND kind = ${kind} AND expires_at > NOW()
    RETURNING challenge, kind, user_id, username, email`;
  return rows[0] ?? null;
}

export async function pruneExpiredChallenges(): Promise<void> {
  await sql()`DELETE FROM webauthn_challenges WHERE expires_at <= NOW()`;
}

// --- Recovery tokens (email link -> new passkey) ---

const RECOVERY_TTL_MINUTES = 30;

export function newRecoveryToken(): string {
  return randomBytes(32).toString("base64url");
}

export async function saveRecoveryToken(tokenHash: string, userId: string): Promise<void> {
  await sql()`
    INSERT INTO recovery_tokens (token_hash, user_id, expires_at)
    VALUES (${tokenHash}, ${userId}, NOW() + make_interval(mins => ${RECOVERY_TTL_MINUTES}))`;
}

export async function findLiveRecoveryToken(tokenHash: string): Promise<{ user_id: string } | null> {
  const rows = await sql()<{ user_id: string }[]>`
    SELECT user_id FROM recovery_tokens
    WHERE token_hash = ${tokenHash} AND used_at IS NULL AND expires_at > NOW()`;
  return rows[0] ?? null;
}

export async function consumeRecoveryToken(tokenHash: string): Promise<void> {
  await sql()`UPDATE recovery_tokens SET used_at = NOW() WHERE token_hash = ${tokenHash}`;
}

// --- Bundles ---

export type BundleRow = {
  id: string;
  user_id: string;
  name: string;
  description: string;
  languages: string[];
  tags: string[];
  file_url: string;
  file_size: number;
  downloads: string; // BIGINT arrives as string
  created_at: string;
  updated_at: string;
  author: string; // joined username
};

export async function listBundles(filter: { q?: string; language?: string }): Promise<BundleRow[]> {
  const s = sql();
  const q = filter.q?.trim();
  const language = filter.language?.trim();
  return s<BundleRow[]>`
    SELECT b.*, u.username AS author
    FROM bundles b JOIN users u ON u.id = b.user_id
    WHERE TRUE
      ${q ? s`AND (b.name ILIKE ${"%" + q + "%"} OR b.description ILIKE ${"%" + q + "%"} OR b.id ILIKE ${"%" + q + "%"})` : s``}
      ${language ? s`AND ${language} = ANY(b.languages)` : s``}
    ORDER BY b.created_at DESC`;
}

export async function getBundle(id: string): Promise<BundleRow | null> {
  const rows = await sql()<BundleRow[]>`
    SELECT b.*, u.username AS author
    FROM bundles b JOIN users u ON u.id = b.user_id
    WHERE b.id = ${id}`;
  return rows[0] ?? null;
}

export async function upsertBundle(bundle: {
  id: string;
  userId: string;
  name: string;
  description: string;
  languages: string[];
  tags: string[];
  fileUrl: string;
  fileSize: number;
}): Promise<void> {
  await sql()`
    INSERT INTO bundles (id, user_id, name, description, languages, tags, file_url, file_size)
    VALUES (${bundle.id}, ${bundle.userId}, ${bundle.name}, ${bundle.description},
            ${bundle.languages}, ${bundle.tags}, ${bundle.fileUrl}, ${bundle.fileSize})
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      description = EXCLUDED.description,
      languages = EXCLUDED.languages,
      tags = EXCLUDED.tags,
      file_url = EXCLUDED.file_url,
      file_size = EXCLUDED.file_size,
      updated_at = NOW()
    WHERE bundles.user_id = EXCLUDED.user_id`;
}

export async function listBundlesByUsername(username: string): Promise<BundleRow[]> {
  return sql()<BundleRow[]>`
    SELECT b.*, u.username AS author
    FROM bundles b JOIN users u ON u.id = b.user_id
    WHERE u.username = ${username}
    ORDER BY b.created_at DESC`;
}

/** Owner-scoped metadata edit — the bundle file itself is untouched (a content change is a
 * resubmission through the ordinary upload path). */
export async function updateBundleMeta(
  id: string, userId: string, description: string, tags: string[],
): Promise<boolean> {
  const rows = await sql()`
    UPDATE bundles SET description = ${description}, tags = ${tags}, updated_at = NOW()
    WHERE id = ${id} AND user_id = ${userId} RETURNING id`;
  return rows.length > 0;
}

export async function deleteBundle(id: string, userId: string): Promise<boolean> {
  const rows = await sql()`DELETE FROM bundles WHERE id = ${id} AND user_id = ${userId} RETURNING id`;
  return rows.length > 0;
}

export async function countDownload(id: string): Promise<void> {
  await sql()`UPDATE bundles SET downloads = downloads + 1 WHERE id = ${id}`;
}

// --- Rate limiting (freebee's fixed-window pattern: one row per key, window resets lazily) ---

export async function withinRateLimit(key: string, limit: number, windowSeconds: number): Promise<boolean> {
  const rows = await sql()<{ count: number }[]>`
    INSERT INTO rate_limits (key, window_start, count) VALUES (${key}, NOW(), 1)
    ON CONFLICT (key) DO UPDATE SET
      count = CASE WHEN rate_limits.window_start < NOW() - make_interval(secs => ${windowSeconds})
                   THEN 1 ELSE rate_limits.count + 1 END,
      window_start = CASE WHEN rate_limits.window_start < NOW() - make_interval(secs => ${windowSeconds})
                          THEN NOW() ELSE rate_limits.window_start END
    RETURNING count`;
  return Number(rows[0].count) <= limit;
}

export function newId(): string {
  return uuidv7();
}

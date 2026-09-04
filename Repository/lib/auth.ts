// Stateless HMAC-signed cookie sessions — freebee's lib/auth.ts pattern, adapted.

import { cookies } from "next/headers";
import { createHmac, timingSafeEqual } from "node:crypto";
import { cache } from "react";
import { findUserById, type User } from "./db.ts";

const COOKIE_NAME = "prosary_session";
const SESSION_TTL_SECONDS = 60 * 60 * 24 * 30; // 30 days
const VERSION = "v1";

export type SessionUser = User;

function getSecret(): Buffer {
  const raw = process.env.SESSION_SECRET;
  if (raw && raw.length >= 32) return Buffer.from(raw, "utf-8");
  if (process.env.NODE_ENV === "production") {
    throw new Error(
      "SESSION_SECRET must be set in production (32+ chars). Generate one with `openssl rand -base64 48`."
    );
  }
  // Dev-only deterministic fallback so cookies survive HMR; the throw above
  // keeps it out of production.
  return Buffer.from("prosary-dev-secret-not-for-production-aaaaaaaaaaaaaa", "utf-8");
}

function sign(payload: string): string {
  return createHmac("sha256", getSecret()).update(payload).digest("base64url");
}

function pack(userId: string, issuedAt: number): string {
  const payload = `${VERSION}.${userId}.${issuedAt}`;
  return `${payload}.${sign(payload)}`;
}

function unpack(value: string): { userId: string; issuedAt: number } | null {
  const parts = value.split(".");
  if (parts.length !== 4) return null;
  const [version, userId, issuedAtStr, signature] = parts;
  if (version !== VERSION) return null;
  const expected = sign(`${version}.${userId}.${issuedAtStr}`);
  const a = Buffer.from(signature);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  const issuedAt = Number(issuedAtStr);
  if (!Number.isFinite(issuedAt)) return null;
  return { userId, issuedAt };
}

export const getCurrentUser = cache(async (): Promise<SessionUser | null> => {
  const store = await cookies();
  const cookie = store.get(COOKIE_NAME)?.value;
  if (!cookie) return null;
  const unpacked = unpack(cookie);
  if (!unpacked) return null;
  const ageSeconds = Math.floor(Date.now() / 1000) - unpacked.issuedAt;
  if (ageSeconds < 0 || ageSeconds > SESSION_TTL_SECONDS) return null;
  return findUserById(unpacked.userId);
});

export async function setSession(userId: string): Promise<void> {
  const store = await cookies();
  store.set(COOKIE_NAME, pack(userId, Math.floor(Date.now() / 1000)), {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: SESSION_TTL_SECONDS,
  });
}

export async function clearSession(): Promise<void> {
  const store = await cookies();
  store.delete(COOKIE_NAME);
}

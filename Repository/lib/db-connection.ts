import postgres, { type Sql } from "postgres";

// Single source of truth for opening Postgres connections.
//
// Reads the connection string from POSTGRES_URL (Vercel Postgres / Neon
// auto-injects this), or DATABASE_URL as a fallback. Always forces SSL —
// every managed Postgres provider we'd use requires it, and postgres.js
// doesn't auto-honor `sslmode=require` from the URL string.

type CreateOpts = Pick<postgres.Options<Record<string, never>>, "max">;

// postgres.js returns Date objects for TIMESTAMPTZ by default. The rest of
// this app treats those columns as ISO strings (the SQLite contract we
// inherited).
//
// Postgres emits TIMESTAMPTZ as `2026-05-08 10:00:00.123+00` — space
// separator, short tz. V8 parses that, but Safari's stricter Date.parse
// rejects it as "Invalid Date." We canonicalize to ISO 8601 here so any
// client `new Date(value)` (server- or browser-side) just works.
const TIMESTAMP_AS_ISO_STRING = {
  date: {
    to: 1184,
    from: [1082, 1083, 1114, 1184],
    serialize: (x: Date | string) =>
      typeof x === "string" ? x : x.toISOString(),
    parse: (x: string) => {
      const d = new Date(x);
      return Number.isNaN(d.getTime()) ? x : d.toISOString();
    },
  },
};

export function createSqlClient(opts: CreateOpts = {}): Sql {
  const url =
    process.env.POSTGRES_URL ||
    process.env.DATABASE_URL ||
    process.env.POSTGRES_URL_NON_POOLING;
  if (!url) {
    throw new Error(
      "POSTGRES_URL is not set. Connect a Neon (or other Postgres) integration to the Vercel project, or set POSTGRES_URL in .env.local for dev."
    );
  }
  return postgres(url, {
    ssl: "require",
    types: TIMESTAMP_AS_ISO_STRING,
    ...opts,
  });
}

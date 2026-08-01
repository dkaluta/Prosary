import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import { put } from "@vercel/blob";
import { createSqlClient } from "@/lib/db-connection";
import { resolveTracedDir, runMigrations } from "@/lib/migrate";

// Migrations + founding data, run where the sensitive connection string lives
// (the Neon integration's env vars can't be pulled locally) — freebee's
// admin-seed pattern. Idempotent:
//   curl -X POST -H "x-admin-secret: $ADMIN_SECRET" https://prayers.prosary.app/api/admin/seed
//
// The seeded account has no passkey by design: its owner claims it through the
// recovery flow (email -> new passkey), which doubles as that flow's first
// real-world exercise.

const USERNAME = "dkaluta";
const EMAIL = "mail@dkaluta.com";
const BUNDLE_ID = "repo.dkaluta.kyrie";

export async function POST(request: Request) {
  const secret = process.env.ADMIN_SECRET;
  if (!secret || request.headers.get("x-admin-secret") !== secret) {
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }

  const migrations = await runMigrations({ log: (m) => console.log(`[seed] ${m}`) });

  const sql = createSqlClient({ max: 1 });
  try {
    const existing = await sql<{ id: string }[]>`SELECT id FROM users WHERE username = ${USERNAME}`;
    const userId = existing[0]?.id ?? randomUUID();
    if (existing.length === 0) {
      await sql`INSERT INTO users (id, username, email) VALUES (${userId}, ${USERNAME}, ${EMAIL})`;
    }

    const bytes = await readFile(join(resolveTracedDir("seed"), "repo.dkaluta.kyrie.prosaryprayer"));
    const blob = await put(`bundles/${BUNDLE_ID}.prosaryprayer`, bytes, {
      access: "public",
      contentType: "application/zip",
      addRandomSuffix: false,
      allowOverwrite: true,
    });

    await sql`
      INSERT INTO bundles (id, user_id, name, description, languages, tags, file_url, file_size)
      VALUES (${BUNDLE_ID}, ${userId}, ${"Kyrie"},
              ${"A one-minute devotion: the Sign of the Cross, the threefold Kyrie, and the Glory Be."},
              ${["la", "en"]}, ${["short"]}, ${blob.url}, ${bytes.length})
      ON CONFLICT (id) DO UPDATE SET file_url = EXCLUDED.file_url, file_size = EXCLUDED.file_size, updated_at = NOW()`;

    return Response.json({ ok: true, migrations, seeded: BUNDLE_ID, blobUrl: blob.url });
  } finally {
    await sql.end({ timeout: 5 });
  }
}

// Seeds the repository: the founding user plus the Kyrie bundle. Idempotent.
// Needs POSTGRES_URL and BLOB_READ_WRITE_TOKEN (locally: `vercel env pull`).
//
// The seeded account has no passkey — per the recovery design, its owner claims
// it by requesting a recovery link on /account (email → new passkey).

import { randomUUID } from "node:crypto";
import { put } from "@vercel/blob";
import { createSqlClient } from "../lib/db-connection.ts";
import { runMigrations } from "../lib/migrate.ts";

const USERNAME = "dkaluta";
const EMAIL = "mail@dkaluta.com";
const BUNDLE_ID = "repo.dkaluta.kyrie";

await runMigrations({ log: (m) => console.log(m) });

const sql = createSqlClient({ max: 1 });
try {
  const existingUsers = await sql<{ id: string }[]>`SELECT id FROM users WHERE username = ${USERNAME}`;
  const userId = existingUsers[0]?.id ?? randomUUID();
  if (existingUsers.length === 0) {
    await sql`INSERT INTO users (id, username, email) VALUES (${userId}, ${USERNAME}, ${EMAIL})`;
    console.log(`created user ${USERNAME}`);
  }

  const { SEED_BUNDLES } = await import("../lib/embedded-assets.generated.ts");
  const bytes = Buffer.from(SEED_BUNDLES.find((b) => b.name === `${BUNDLE_ID}.prosaryprayer`)!.base64, "base64");
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
  console.log(`seeded ${BUNDLE_ID} -> ${blob.url}`);
} finally {
  await sql.end({ timeout: 5 });
}
process.exit(0);

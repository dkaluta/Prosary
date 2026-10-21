// Read-only by default. --apply removes the exact retired public blobs and rows,
// then installs the database guard so an older deployment cannot republish them.
import { readFile } from "node:fs/promises";
import { del } from "@vercel/blob";
import { createSqlClient } from "../lib/db-connection.ts";
import { RETIRED_BUNDLE_IDS } from "../lib/retired-bundles.ts";

const apply = process.argv.includes("--apply");
const sql = createSqlClient({ max: 1 });
try {
  const rows = await sql<{ id: string; author: string; file_url: string }[]>`
    SELECT b.id, u.username AS author, b.file_url
    FROM bundles b JOIN users u ON u.id = b.user_id
    WHERE b.id = ANY(${[...RETIRED_BUNDLE_IDS]})`;
  console.log(JSON.stringify({ apply, targets: rows.map(({ id, author }) => ({ id, author })) }));
  for (const row of rows) {
    // Confirm this connection points at the public repository before removing anything.
    const response = await fetch(`https://prayers.prosary.app/api/download/${encodeURIComponent(row.id)}`, {
      redirect: "manual", cache: "no-store",
    });
    if (response.status !== 302 || response.headers.get("location") !== row.file_url) {
      throw new Error("repository_target_mismatch");
    }
  }
  if (apply) {
    if (rows.length && !process.env.BLOB_READ_WRITE_TOKEN) throw new Error("blob_credentials_missing");
    for (const row of rows) await del(row.file_url);
    await sql.unsafe(await readFile(new URL("../migrations/0003_retire_duplicate_loreto.sql", import.meta.url), "utf8"));
    const remaining = await sql`SELECT id FROM bundles WHERE id = ANY(${[...RETIRED_BUNDLE_IDS]})`;
    if (remaining.length) throw new Error("retirement_incomplete");
    console.log(JSON.stringify({ removed: rows.length, remaining: remaining.length, databaseGuard: true }));
  }
} catch (error) {
  // Provider error messages can contain connection details; report only safe identifiers.
  console.error(JSON.stringify({ error: error instanceof Error && [
    "repository_target_mismatch", "blob_credentials_missing", "retirement_incomplete",
  ].includes(error.message) ? error.message : "retirement_failed" }));
  process.exitCode = 1;
} finally {
  await sql.end({ timeout: 5 });
}

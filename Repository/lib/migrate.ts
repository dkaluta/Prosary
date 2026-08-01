// Versioned SQL migration runner. Applies migrations/*.sql (embedded at build time by
// scripts/embed-assets.ts — outputFileTracingIncludes does not ship loose files under this
// monorepo's Root Directory setup) in lexical order, recording each in _migrations inside a
// transaction. Idempotent — safe to run on every deploy.

import { createSqlClient } from "./db-connection.ts";
import { MIGRATIONS } from "./embedded-assets.generated.ts";

export type MigrationResult = {
  applied: string[];
  skipped: string[];
};

export async function runMigrations(opts?: {
  log?: (msg: string) => void;
}): Promise<MigrationResult> {
  const log = opts?.log ?? (() => {});
  // max:1 — migrations are short and serial; no need to keep a pool around.
  const sql = createSqlClient({ max: 1 });

  try {
    await sql.unsafe(`
      CREATE TABLE IF NOT EXISTS _migrations (
        id          TEXT PRIMARY KEY,
        applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    const appliedRows = await sql<{ id: string }[]>`SELECT id FROM _migrations`;
    const appliedSet = new Set(appliedRows.map((r) => r.id));

    const applied: string[] = [];
    const skipped: string[] = [];

    for (const migration of [...MIGRATIONS].sort((a, b) => a.id.localeCompare(b.id))) {
      if (appliedSet.has(migration.id)) {
        skipped.push(migration.id);
        continue;
      }
      log(`applying ${migration.id}`);
      // Each migration runs in its own transaction so a failure halts the run
      // cleanly without partially-applied state.
      await sql.begin(async (tx) => {
        await tx.unsafe(migration.sql);
        await tx`INSERT INTO _migrations (id) VALUES (${migration.id})`;
      });
      applied.push(migration.id);
    }

    return { applied, skipped };
  } finally {
    await sql.end({ timeout: 5 });
  }
}

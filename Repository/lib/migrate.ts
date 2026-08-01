// Versioned SQL migration runner. Reads migrations/*.sql in lexical order,
// applies any not yet recorded in the _migrations table inside a transaction.
//
// Usage:
//   import { runMigrations } from "@/lib/migrate";
//   await runMigrations();
//
// Idempotent — safe to run on every deploy.

import { existsSync } from "node:fs";
import { readdir, readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { createSqlClient } from "./db-connection.ts";

/**
 * Resolves a directory shipped with the function via outputFileTracingIncludes.
 * In this monorepo (Vercel Root Directory `Repository`) the function's cwd is
 * `/var/task/Repository` while traced files land under `/var/task/…` — so both
 * the cwd and its parent are candidates; locally cwd alone matches. The
 * turbopackIgnore hint keeps the bundler from tracing every possible path.
 */
export function resolveTracedDir(name: string): string {
  const cwd = /*turbopackIgnore: true*/ process.cwd();
  const candidates = [join(cwd, name), join(dirname(cwd), name)];
  for (const candidate of candidates) {
    if (existsSync(candidate)) return candidate;
  }
  throw new Error(`Traced directory '${name}' not found in: ${candidates.join(", ")}`);
}

export type MigrationResult = {
  applied: string[];
  skipped: string[];
};

export async function runMigrations(opts?: {
  migrationsDir?: string;
  log?: (msg: string) => void;
}): Promise<MigrationResult> {
  const dir = opts?.migrationsDir ?? resolveTracedDir("migrations");
  const log = opts?.log ?? (() => {});
  // max:1 — migrations are short and serial; no need to keep a pool around.
  const sql = createSqlClient({ max: 1 });

  try {
    // Bootstrap the bookkeeping table so the very first run has somewhere
    // to record what it applied.
    await sql.unsafe(`
      CREATE TABLE IF NOT EXISTS _migrations (
        id          TEXT PRIMARY KEY,
        applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    const entries = (await readdir(dir))
      .filter((f) => f.endsWith(".sql"))
      .sort();

    const appliedRows = await sql<{ id: string }[]>`SELECT id FROM _migrations`;
    const appliedSet = new Set(appliedRows.map((r) => r.id));

    const applied: string[] = [];
    const skipped: string[] = [];

    for (const file of entries) {
      if (appliedSet.has(file)) {
        skipped.push(file);
        continue;
      }
      const body = await readFile(join(dir, file), "utf-8");
      log(`applying ${file}`);
      // Each migration runs in its own transaction so a failure halts the
      // run cleanly without partially-applied state.
      await sql.begin(async (tx) => {
        await tx.unsafe(body);
        await tx`INSERT INTO _migrations (id) VALUES (${file})`;
      });
      applied.push(file);
    }

    return { applied, skipped };
  } finally {
    await sql.end({ timeout: 5 });
  }
}

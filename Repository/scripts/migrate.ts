// Apply pending Postgres migrations. Wired to `npm run db:migrate`.

import { runMigrations } from "../lib/migrate.ts";

const r = await runMigrations({ log: (m) => console.log(m) });
if (r.applied.length === 0) {
  console.log(`No new migrations. ${r.skipped.length} already applied.`);
} else {
  console.log(
    `Applied ${r.applied.length} migration(s): ${r.applied.join(", ")}`
  );
}
process.exit(0);

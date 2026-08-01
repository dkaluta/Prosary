import { runMigrations } from "@/lib/migrate";

// Applies pending migrations in production (freebee's runbook pattern):
//   curl -X POST -H "x-admin-secret: $ADMIN_SECRET" https://prayers.prosary.app/api/admin/migrate
export async function POST(request: Request) {
  const secret = process.env.ADMIN_SECRET;
  if (!secret || request.headers.get("x-admin-secret") !== secret) {
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }
  const result = await runMigrations({ log: (m) => console.log(`[migrate] ${m}`) });
  return Response.json(result);
}

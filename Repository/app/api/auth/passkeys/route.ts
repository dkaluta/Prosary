import { getCurrentUser } from "@/lib/auth";
import { getPasskeysForUser } from "@/lib/db";

export async function GET() {
  const user = await getCurrentUser();
  if (!user) return Response.json({ error: "unauthorized" }, { status: 401 });
  const passkeys = await getPasskeysForUser(user.id);
  return Response.json({
    passkeys: passkeys.map((p) => ({
      credentialId: p.credential_id,
      name: p.name,
      createdAt: p.created_at,
    })),
  });
}

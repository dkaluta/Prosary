import { getCurrentUser } from "@/lib/auth";
import { deletePasskey, getPasskeysForUser, renamePasskey } from "@/lib/db";

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const user = await getCurrentUser();
  if (!user) return Response.json({ error: "unauthorized" }, { status: 401 });
  const { id } = await params;
  const body = await request.json().catch(() => null);
  const name = String(body?.name ?? "").trim();
  if (!name) return Response.json({ error: "missing_name" }, { status: 400 });
  const renamed = await renamePasskey(decodeURIComponent(id), user.id, name);
  if (!renamed) return Response.json({ error: "not_found" }, { status: 404 });
  return Response.json({ ok: true });
}

export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const user = await getCurrentUser();
  if (!user) return Response.json({ error: "unauthorized" }, { status: 401 });
  const { id } = await params;
  // Never delete the last passkey — the account would be reachable only through email
  // recovery, which is a fallback, not a sign-in method.
  const existing = await getPasskeysForUser(user.id);
  if (existing.length <= 1) return Response.json({ error: "last_passkey" }, { status: 409 });
  const deleted = await deletePasskey(decodeURIComponent(id), user.id);
  if (!deleted) return Response.json({ error: "not_found" }, { status: 404 });
  return Response.json({ ok: true });
}

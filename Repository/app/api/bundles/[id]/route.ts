import { del } from "@vercel/blob";
import { getCurrentUser } from "@/lib/auth";
import { deleteBundle, getBundle } from "@/lib/db";

export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const user = await getCurrentUser();
  if (!user) return Response.json({ error: "unauthorized" }, { status: 401 });

  const { id } = await params;
  const bundle = await getBundle(id);
  if (!bundle) return Response.json({ error: "not_found" }, { status: 404 });
  const deleted = await deleteBundle(id, user.id);
  if (!deleted) return Response.json({ error: "forbidden" }, { status: 403 });
  await del(bundle.file_url).catch(() => {});
  return Response.json({ ok: true });
}

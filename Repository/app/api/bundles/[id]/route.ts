import { del } from "@vercel/blob";
import { getCurrentUser } from "@/lib/auth";
import { deleteBundle, getBundle, updateBundleMeta } from "@/lib/db";

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

/** Owner-only metadata edit (description/tags) — the file itself is untouched; content
 * changes are resubmissions through POST /api/bundles. */
export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const user = await getCurrentUser();
  if (!user) return Response.json({ error: "unauthorized" }, { status: 401 });

  const { id } = await params;
  const body = await request.json().catch(() => null);
  const description = String(body?.description ?? "").trim().slice(0, 500);
  const tags = Array.isArray(body?.tags)
    ? body.tags.map((t: unknown) => String(t).trim().toLowerCase()).filter(Boolean).slice(0, 8)
    : [];
  const updated = await updateBundleMeta(id, user.id, description, tags);
  if (!updated) return Response.json({ error: "not_found" }, { status: 404 });
  return Response.json({ ok: true });
}

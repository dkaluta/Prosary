import { put } from "@vercel/blob";
import { getCurrentUser } from "@/lib/auth";
import { BundleError, validateAndRestamp } from "@/lib/bundles";
import { getBundle, listBundles, upsertBundle } from "@/lib/db";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const bundles = await listBundles({
    q: url.searchParams.get("q") ?? undefined,
    language: url.searchParams.get("lang") ?? undefined,
  });
  return Response.json({
    bundles: bundles.map((b) => ({
      id: b.id,
      name: b.name,
      author: b.author,
      languages: b.languages,
      tags: b.tags,
      description: b.description,
      downloads: Number(b.downloads),
      file: `/api/download/${b.id}`,
      createdAt: b.created_at,
    })),
  });
}

export async function POST(request: Request) {
  const user = await getCurrentUser();
  if (!user) return Response.json({ error: "unauthorized" }, { status: 401 });

  const form = await request.formData().catch(() => null);
  const file = form?.get("file");
  if (!form || !(file instanceof File)) {
    return Response.json({ error: "missing_file" }, { status: 400 });
  }
  const description = String(form.get("description") ?? "").trim().slice(0, 500);
  const tags = String(form.get("tags") ?? "")
    .split(",")
    .map((t) => t.trim().toLowerCase())
    .filter(Boolean)
    .slice(0, 8);

  let validated;
  try {
    validated = await validateAndRestamp(new Uint8Array(await file.arrayBuffer()), user.username);
  } catch (err) {
    if (err instanceof BundleError) {
      return Response.json({ error: "invalid_bundle", detail: err.message }, { status: 400 });
    }
    throw err;
  }

  // The id encodes the owner's username, but resubmission overwrite is still
  // guarded against the row's actual owner.
  const existing = await getBundle(validated.id);
  if (existing && existing.user_id !== user.id) {
    return Response.json({ error: "id_taken" }, { status: 409 });
  }

  const blob = await put(`bundles/${validated.id}.prosaryprayer`, Buffer.from(validated.bytes), {
    access: "public",
    contentType: "application/zip",
    addRandomSuffix: false,
    allowOverwrite: true,
  });
  await upsertBundle({
    id: validated.id,
    userId: user.id,
    name: validated.displayName,
    description,
    languages: validated.languages,
    tags,
    fileUrl: blob.url,
    fileSize: validated.bytes.length,
  });
  return Response.json({ ok: true, id: validated.id });
}

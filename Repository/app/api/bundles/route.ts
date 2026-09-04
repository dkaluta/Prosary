import { del, put } from "@vercel/blob";
import { getCurrentUser } from "@/lib/auth";
import { assertBundleByteLength, BundleError, validateAndRestamp } from "@/lib/bundles";
import { getBundle, listBundles, upsertBundle } from "@/lib/db";
import { uuidv7 } from "@/lib/uuidv7";

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
  const formTags = String(form.get("tags") ?? "")
    .split(",")
    .map((t) => t.trim().toLowerCase())
    .filter(Boolean)
    .slice(0, 8);

  let validated;
  try {
    assertBundleByteLength(file.size);
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

  // Blob keys live under a UUIDv7 directory with the id as filename: the URL stays
  // unguessable and a deleted-then-re-registered username can never resurrect a
  // predecessor's file, while direct downloads still save under a meaningful name.
  const blob = await put(`bundles/${uuidv7()}/${validated.id}.prosaryprayer`, Buffer.from(validated.bytes), {
    access: "public",
    contentType: "application/zip",
    addRandomSuffix: false,
  });
  await upsertBundle({
    id: validated.id,
    userId: user.id,
    name: validated.displayName,
    description,
    languages: validated.languages,
    // The form wins when filled; otherwise the manifest's own tags (Compose writes them).
    tags: formTags.length > 0 ? formTags : validated.tags,
    fileUrl: blob.url,
    fileSize: validated.bytes.length,
  });
  // Each resubmission lands on a fresh key, so retire the old file once the row points away.
  if (existing && existing.file_url !== blob.url) {
    await del(existing.file_url).catch(() => {});
  }
  return Response.json({ ok: true, id: validated.id });
}

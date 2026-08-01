import { countDownload, getBundle } from "@/lib/db";

// Same-origin download URL for every catalog surface (site, index.json, the
// future in-app browser) — counts, then redirects to the blob.
export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const bundle = await getBundle(id);
  if (!bundle) return Response.json({ error: "not_found" }, { status: 404 });
  await countDownload(id);
  return Response.redirect(bundle.file_url, 302);
}

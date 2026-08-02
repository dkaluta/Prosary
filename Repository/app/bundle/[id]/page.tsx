import Link from "next/link";
import { notFound } from "next/navigation";
import { getBundle } from "@/lib/db";

export const dynamic = "force-dynamic";

export default async function BundlePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let bundle = null;
  try {
    bundle = await getBundle(decodeURIComponent(id));
  } catch {
    // DB offline — treated as not found.
  }
  if (!bundle) notFound();

  return (
    <main>
      <article className="card">
        <h2>{bundle.name}</h2>
        <p className="meta">
          by <Link href={`/u/${bundle.author}`}>{bundle.author}</Link> ·{" "}
          <span className="id">{bundle.id}</span>
        </p>
        {bundle.description && <p>{bundle.description}</p>}
        {bundle.tags.length > 0 && (
          <p className="meta">
            {bundle.tags.map((tag) => (
              <span className="tag" key={tag}>{tag}</span>
            ))}
          </p>
        )}
        <p className="meta">
          {Number(bundle.downloads)} download{Number(bundle.downloads) === 1 ? "" : "s"} ·{" "}
          {(bundle.file_size / 1024).toFixed(0)} KB · updated{" "}
          {new Date(bundle.updated_at).toISOString().slice(0, 10)}
        </p>
        <p>
          <a className="primary button" href={`/api/download/${bundle.id}`}>Download</a>
        </p>
        <p className="hint">
          Or install it in the Prosary app: Browse tab → search for “{bundle.name}”.
        </p>
      </article>
    </main>
  );
}

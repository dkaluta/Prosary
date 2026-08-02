import Link from "next/link";
import { notFound } from "next/navigation";
import { listBundlesByUsername, normalizeUsername, type BundleRow } from "@/lib/db";

export const dynamic = "force-dynamic";

export default async function ProfilePage({ params }: { params: Promise<{ username: string }> }) {
  const { username: raw } = await params;
  const username = normalizeUsername(decodeURIComponent(raw));
  if (!username) notFound();
  let bundles: BundleRow[];
  try {
    bundles = await listBundlesByUsername(username);
  } catch {
    bundles = [];
  }

  return (
    <main>
      <div className="card">
        <h2>{username}</h2>
        <p className="hint">
          {bundles.length} published devotion{bundles.length === 1 ? "" : "s"}
        </p>
      </div>
      {bundles.map((bundle) => (
        <article className="card" key={bundle.id}>
          <h3><Link href={`/bundle/${bundle.id}`}>{bundle.name}</Link></h3>
          {bundle.description && <p className="hint">{bundle.description}</p>}
          <p className="meta">
            <span className="id">{bundle.id}</span> · {Number(bundle.downloads)} download
            {Number(bundle.downloads) === 1 ? "" : "s"}
          </p>
        </article>
      ))}
    </main>
  );
}

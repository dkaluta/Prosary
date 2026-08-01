import { listBundles } from "@/lib/db";
import { LANGUAGE_NAMES } from "@/lib/languages";

export const dynamic = "force-dynamic";

export default async function Home({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; lang?: string }>;
}) {
  const { q, lang } = await searchParams;
  let bundles: Awaited<ReturnType<typeof listBundles>> = [];
  let offline = false;
  try {
    bundles = await listBundles({ q, language: lang });
  } catch {
    offline = true;
  }

  return (
    <main>
      <p className="tagline">
        Devotions shared by the Prosary community — download a bundle, then import it in the
        app: <strong>Favorites → Import Devotion Bundle</strong>. Repository devotions show a
        “Repository” tag in the app.
      </p>

      <form className="filters" method="get" action="/">
        <input type="search" name="q" placeholder="Search devotions…" defaultValue={q ?? ""} aria-label="Search devotions" />
        <select name="lang" defaultValue={lang ?? ""} aria-label="Filter by language">
          <option value="">Any language</option>
          {Object.entries(LANGUAGE_NAMES).map(([code, name]) => (
            <option key={code} value={code}>
              {name}
            </option>
          ))}
        </select>
        <button className="primary" type="submit">
          Filter
        </button>
      </form>

      {offline ? (
        <p className="error">The catalog is unavailable right now — try again shortly.</p>
      ) : bundles.length === 0 ? (
        <p className="hint">Nothing here matches — clear the filters, or be the first to share a devotion.</p>
      ) : (
        bundles.map((bundle) => (
          <article className="card" key={bundle.id}>
            <h2>{bundle.name}</h2>
            <p className="meta">
              by {bundle.author} · {bundle.languages.map((l) => LANGUAGE_NAMES[l] ?? l).join(", ")} ·{" "}
              <span className="id">{bundle.id}</span> · {Number(bundle.downloads)} download
              {Number(bundle.downloads) === 1 ? "" : "s"}
            </p>
            {bundle.tags.length > 0 && (
              <p className="meta">
                {bundle.tags.map((tag) => (
                  <span className="tag" key={tag}>
                    {tag}
                  </span>
                ))}
              </p>
            )}
            {bundle.description && <p className="desc">{bundle.description}</p>}
            <a className="download" href={`/api/download/${bundle.id}`}>
              Download .prosaryprayer
            </a>
          </article>
        ))
      )}
    </main>
  );
}

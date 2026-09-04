import type { Metadata } from "next";
import Link from "next/link";
import { BundleCard } from "@/components/BundleCard";
import { PageHeader } from "@/components/PageHeader";
import { StatusMessage } from "@/components/StatusMessage";
import { listBundles } from "@/lib/db";
import { LANGUAGE_NAMES } from "@/lib/languages";
import { publicPageMetadata } from "@/lib/metadata";

export const dynamic = "force-dynamic";
export const metadata: Metadata = publicPageMetadata({ title: "Browse", path: "/" });

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
    <main id="main-content" tabIndex={-1}>
      <PageHeader eyebrow="Community library" title="Find a devotion to make your own">
        <p>
          Download a community bundle and import it from{" "}
          <strong>Favorites → Import Devotion Bundle</strong>, or find it directly in the
          Prosary app&apos;s Browse tab.
        </p>
      </PageHeader>

      <form className="filters card" method="get" action="/" role="search">
        <label className="field">
          <span>Search</span>
          <input
            type="search"
            name="q"
            dir="auto"
            placeholder="Name, description, or bundle ID"
            defaultValue={q ?? ""}
          />
        </label>
        <label className="field">
          <span>Language</span>
          <select name="lang" defaultValue={lang ?? ""}>
            <option value="">Any language</option>
            {Object.entries(LANGUAGE_NAMES).map(([code, name]) => (
              <option key={code} value={code} lang={code} dir="auto">
                {name}
              </option>
            ))}
          </select>
        </label>
        <button className="button button-primary filter-submit" type="submit">
          Filter
        </button>
        {(q || lang) && (
          <Link className="clear-filters" href="/">
            Clear filters
          </Link>
        )}
      </form>

      {offline ? (
        <StatusMessage tone="error">
          The catalog is unavailable right now — try again shortly.
        </StatusMessage>
      ) : bundles.length === 0 ? (
        <div className="empty-state">
          <h2>No matching devotions</h2>
          <p>Clear the filters, or be the first to share one with the community.</p>
          <Link className="button button-subtle" href="/submit">
            Submit a devotion
          </Link>
        </div>
      ) : (
        <section aria-labelledby="results-heading">
          <div className="section-heading">
            <h2 id="results-heading">
              {bundles.length} devotion{bundles.length === 1 ? "" : "s"}
            </h2>
            <p>Newest first</p>
          </div>
          <div className="card-list">
            {bundles.map((bundle) => (
              <BundleCard bundle={bundle} key={bundle.id} />
            ))}
          </div>
        </section>
      )}
    </main>
  );
}

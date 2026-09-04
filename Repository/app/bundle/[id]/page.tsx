import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { cache } from "react";
import { BundleLanguages, BundleTags, DownloadLink } from "@/components/BundleCard";
import { PageHeader } from "@/components/PageHeader";
import { StatusMessage } from "@/components/StatusMessage";
import { getBundle } from "@/lib/db";

export const dynamic = "force-dynamic";

type BundleParams = { params: Promise<{ id: string }> };

function decodeBundleId(raw: string): string | null {
  try {
    return decodeURIComponent(raw);
  } catch {
    return null;
  }
}

const loadBundle = cache(async (id: string) => {
  try {
    return { bundle: await getBundle(id), offline: false } as const;
  } catch {
    return { bundle: null, offline: true } as const;
  }
});

export async function generateMetadata({ params }: BundleParams): Promise<Metadata> {
  const { id: raw } = await params;
  const id = decodeBundleId(raw);
  if (!id) return { title: "Devotion not found" };
  const { bundle } = await loadBundle(id);
  return {
    title: bundle?.name ?? "Community devotion",
    description: bundle?.description || undefined,
  };
}

export default async function BundlePage({ params }: BundleParams) {
  const { id: raw } = await params;
  const id = decodeBundleId(raw);
  if (!id) notFound();

  const { bundle, offline } = await loadBundle(id);
  if (offline) {
    return (
      <main id="main-content">
        <PageHeader eyebrow="Community devotion" title="Devotion unavailable" />
        <StatusMessage tone="error">
          This devotion cannot be loaded right now — try again shortly.
        </StatusMessage>
      </main>
    );
  }
  if (!bundle) notFound();

  const downloads = Number(bundle.downloads);
  const updatedDate = new Date(bundle.updated_at).toISOString().slice(0, 10);
  const authorHref = `/u/${encodeURIComponent(bundle.author)}`;

  return (
    <main id="main-content">
      <PageHeader eyebrow="Community devotion" title={bundle.name}>
        <p>
          Shared by <Link href={authorHref}>@{bundle.author}</Link>. Download the portable
          bundle here, or find it from the Browse tab in Prosary.
        </p>
      </PageHeader>

      <section className="card" aria-labelledby="bundle-details-heading">
        <h2 id="bundle-details-heading">About this devotion</h2>
        {bundle.description ? (
          <p dir="auto">{bundle.description}</p>
        ) : (
          <p className="hint">No description was provided.</p>
        )}
        <BundleTags tags={bundle.tags} />
        <dl className="detail-list">
          <div>
            <dt>Languages</dt>
            <dd>
              <BundleLanguages codes={bundle.languages} />
            </dd>
          </div>
          <div>
            <dt>Downloads</dt>
            <dd>
              {downloads} download{downloads === 1 ? "" : "s"}
            </dd>
          </div>
          <div>
            <dt>Bundle size</dt>
            <dd>{(bundle.file_size / 1024).toFixed(0)} KB</dd>
          </div>
          <div>
            <dt>Last updated</dt>
            <dd>
              <time dateTime={updatedDate}>{updatedDate}</time>
            </dd>
          </div>
          <div>
            <dt>Bundle ID</dt>
            <dd>
              <code>{bundle.id}</code>
            </dd>
          </div>
        </dl>
        <div className="action-row">
          <DownloadLink id={bundle.id} name={bundle.name} />
        </div>
      </section>
    </main>
  );
}

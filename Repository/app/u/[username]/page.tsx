import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { BundleCard } from "@/components/BundleCard";
import { PageHeader } from "@/components/PageHeader";
import { StatusMessage } from "@/components/StatusMessage";
import { listBundlesByUsername, normalizeUsername, type BundleRow } from "@/lib/db";

export const dynamic = "force-dynamic";

type ProfileParams = { params: Promise<{ username: string }> };

function profileUsername(raw: string): string | null {
  try {
    return normalizeUsername(decodeURIComponent(raw));
  } catch {
    return null;
  }
}

export async function generateMetadata({ params }: ProfileParams): Promise<Metadata> {
  const { username: raw } = await params;
  const username = profileUsername(raw);
  return { title: username ? `Devotions by ${username}` : "Community profile" };
}

export default async function ProfilePage({ params }: ProfileParams) {
  const { username: raw } = await params;
  const username = profileUsername(raw);
  if (!username) notFound();

  let bundles: BundleRow[] = [];
  let offline = false;
  try {
    bundles = await listBundlesByUsername(username);
  } catch {
    offline = true;
  }

  return (
    <main id="main-content">
      <PageHeader eyebrow="Community author" title={`@${username}`}>
        <p>
          {offline
            ? "Devotions shared with the Prosary community."
            : `${bundles.length} published devotion${bundles.length === 1 ? "" : "s"}, ready for the native Prosary apps.`}
        </p>
      </PageHeader>
      {offline ? (
        <StatusMessage tone="error">
          This profile is unavailable right now — try again shortly.
        </StatusMessage>
      ) : bundles.length === 0 ? (
        <div className="empty-state">
          <h2>No published devotions</h2>
          <p>This author has not shared a devotion yet.</p>
          <Link className="button button-subtle" href="/">
            Browse the library
          </Link>
        </div>
      ) : (
        <section aria-labelledby="author-devotions-heading">
          <div className="section-heading">
            <h2 id="author-devotions-heading">Published devotions</h2>
            <p>Newest first</p>
          </div>
          <div className="card-list">
            {bundles.map((bundle) => (
              <BundleCard bundle={bundle} showAuthor={false} key={bundle.id} />
            ))}
          </div>
        </section>
      )}
    </main>
  );
}

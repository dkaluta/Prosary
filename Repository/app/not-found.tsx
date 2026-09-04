import type { Metadata } from "next";
import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";
import { privatePageMetadata } from "@/lib/metadata";

export const metadata: Metadata = privatePageMetadata({
  title: "Page not found",
  description: "This page is not in the Prosary community library.",
});

export default function NotFound() {
  return (
    <main id="main-content" tabIndex={-1}>
      <PageHeader eyebrow="Not found" title="This page is not in the library">
        <p>The devotion or profile may have moved, or the address may be incomplete.</p>
      </PageHeader>
      <Link className="button button-primary" href="/">
        Browse all devotions
      </Link>
    </main>
  );
}

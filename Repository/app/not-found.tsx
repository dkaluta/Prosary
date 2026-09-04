import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";

export default function NotFound() {
  return (
    <main id="main-content">
      <PageHeader eyebrow="Not found" title="This page is not in the library">
        <p>The devotion or profile may have moved, or the address may be incomplete.</p>
      </PageHeader>
      <Link className="button button-primary" href="/">
        Browse all devotions
      </Link>
    </main>
  );
}

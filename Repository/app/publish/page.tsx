import type { Metadata } from "next";
import { PageHeader } from "@/components/PageHeader";
import { PublishReceiver } from "@/components/PublishReceiver";
import { getCurrentUser } from "@/lib/auth";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Publish from Compose",
  robots: { index: false, follow: false },
};

export default async function PublishPage() {
  let username: string | null = null;
  try {
    username = (await getCurrentUser())?.username ?? null;
  } catch {
    // The receiver remains useful and reports upload errors if storage is unavailable.
  }

  return (
    <main id="main-content" tabIndex={-1}>
      <PageHeader eyebrow="Compose handoff" title="Publish your devotion">
        <p>
          Review the bundle from Prosary Compose, sign in if needed, and share it with the
          community.
        </p>
      </PageHeader>
      <PublishReceiver username={username} />
    </main>
  );
}

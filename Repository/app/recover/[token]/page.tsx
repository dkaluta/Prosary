import type { Metadata } from "next";
import { PageHeader } from "@/components/PageHeader";
import { RecoverPanel } from "@/components/RecoverPanel";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Recover your account",
  robots: { index: false, follow: false },
};

export default async function RecoverPage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  return (
    <main id="main-content" tabIndex={-1}>
      <PageHeader eyebrow="Account recovery" title="Return to your account">
        <p>Add a new passkey with the secure, single-use link sent to your recovery email.</p>
      </PageHeader>
      <RecoverPanel token={token} />
    </main>
  );
}

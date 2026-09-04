import type { Metadata } from "next";
import { PageHeader } from "@/components/PageHeader";
import { RecoverPanel } from "@/components/RecoverPanel";
import { privatePageMetadata } from "@/lib/metadata";

export const dynamic = "force-dynamic";

export const metadata: Metadata = privatePageMetadata({
  title: "Recover your account",
  description: "Add a new passkey with a secure, single-use Prosary recovery link.",
});

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

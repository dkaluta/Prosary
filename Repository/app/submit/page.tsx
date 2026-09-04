import type { Metadata } from "next";
import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";
import { StatusMessage } from "@/components/StatusMessage";
import { SubmitForm } from "@/components/SubmitForm";
import { getCurrentUser } from "@/lib/auth";
import { publicPageMetadata } from "@/lib/metadata";

export const dynamic = "force-dynamic";

export const metadata: Metadata = publicPageMetadata({
  title: "Submit a devotion",
  path: "/submit",
  description: "Share a portable .prosaryprayer devotion bundle with the Prosary community.",
});

export default async function SubmitPage() {
  let user: Awaited<ReturnType<typeof getCurrentUser>> = null;
  let offline = false;
  try {
    user = await getCurrentUser();
  } catch {
    offline = true;
  }

  return (
    <main id="main-content" tabIndex={-1}>
      <PageHeader eyebrow="Share with the community" title="Submit a devotion">
        <p>
          Upload a portable .prosaryprayer bundle. The repository validates it and keeps its
          contents ready for every native Prosary app.
        </p>
      </PageHeader>
      {offline ? (
        <StatusMessage tone="error">
          Submissions are unavailable right now — try again shortly.
        </StatusMessage>
      ) : user ? (
        <SubmitForm username={user.username} />
      ) : (
        <section className="card" aria-labelledby="signin-to-submit-heading">
          <h2 id="signin-to-submit-heading">Sign in to publish</h2>
          <p className="hint">
            <Link href="/account">Sign in or create an account</Link> first. Every bundle is
            published under your <code>repo.&lt;username&gt;.…</code> namespace.
          </p>
        </section>
      )}
    </main>
  );
}

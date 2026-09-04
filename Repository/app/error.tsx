"use client";

import { PageHeader } from "@/components/PageHeader";
import { StatusMessage } from "@/components/StatusMessage";

export default function ErrorPage({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <main id="main-content">
      <PageHeader eyebrow="Something went wrong" title="The library needs another moment">
        <p>Your account and devotions have not been changed.</p>
      </PageHeader>
      <StatusMessage tone="error">
        This page could not be loaded. Check your connection and try again.
      </StatusMessage>
      <button className="button button-primary" type="button" onClick={reset}>
        Try again
      </button>
    </main>
  );
}

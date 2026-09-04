"use client";

import Link from "next/link";
import { useState } from "react";
import { StatusMessage } from "@/components/StatusMessage";

export function RecoverPanel({ token }: { token: string }) {
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);

  const recover = async () => {
    setError(null);
    setBusy(true);
    try {
      const [optionsResponse, { startRegistration }] = await Promise.all([
        fetch("/api/auth/recover/options", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ token }),
        }),
        import("@simplewebauthn/browser"),
      ]);
      if (!optionsResponse.ok) {
        setError("This recovery link is invalid or has expired — request a fresh one.");
        return;
      }
      const registration = await startRegistration({
        optionsJSON: await optionsResponse.json(),
      });
      const verify = await fetch("/api/auth/recover/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token, response: registration }),
      });
      if (!verify.ok) {
        setError("The new passkey could not be verified.");
        return;
      }
      setDone(true);
    } catch {
      setError("Passkey creation was cancelled or failed.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <section className="card" aria-labelledby="recovery-heading" aria-busy={busy}>
      <h2 id="recovery-heading">Create a new passkey</h2>
      {done ? (
        <StatusMessage tone="success">
          A new passkey is saved and you are signed in. <Link href="/account">Open your account</Link>.
        </StatusMessage>
      ) : (
        <>
          <p className="hint">
            Confirm this recovery request to add a fresh passkey for this device. The link can
            be used only once.
          </p>
          <button
            className="button button-primary"
            type="button"
            disabled={busy}
            onClick={recover}
          >
            {busy ? "Creating passkey…" : "Create a new passkey"}
          </button>
          {error ? <StatusMessage tone="error">{error}</StatusMessage> : null}
        </>
      )}
    </section>
  );
}

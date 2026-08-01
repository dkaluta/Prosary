"use client";

import { startRegistration } from "@simplewebauthn/browser";
import { useState } from "react";

export function RecoverPanel({ token }: { token: string }) {
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);

  const recover = async () => {
    setError(null);
    setBusy(true);
    try {
      const optionsResponse = await fetch("/api/auth/recover/options", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token }),
      });
      if (!optionsResponse.ok) {
        setError("This recovery link is invalid or has expired — request a fresh one.");
        return;
      }
      const registration = await startRegistration({ optionsJSON: await optionsResponse.json() });
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
    <div className="card">
      <h2>Recover your account</h2>
      {done ? (
        <p className="ok">
          A new passkey is saved and you're signed in — <a href="/account">back to your account</a>.
        </p>
      ) : (
        <>
          <p className="hint">This adds a fresh passkey to your account on this device.</p>
          <button className="primary" disabled={busy} onClick={recover}>
            Create a new passkey
          </button>
          {error && <p className="error" aria-live="polite">{error}</p>}
        </>
      )}
    </div>
  );
}

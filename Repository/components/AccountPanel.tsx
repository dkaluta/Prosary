"use client";

import { startRegistration } from "@simplewebauthn/browser";
import { useState } from "react";

export function AccountPanel({
  username,
  passkeyCount,
  bundles,
}: {
  username: string;
  passkeyCount: number;
  bundles: { id: string; name: string }[];
}) {
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const addPasskey = async () => {
    setError(null);
    try {
      const optionsResponse = await fetch("/api/auth/register/options", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ mode: "add" }),
      });
      if (!optionsResponse.ok) {
        setError("Could not start adding a passkey.");
        return;
      }
      const registration = await startRegistration({ optionsJSON: await optionsResponse.json() });
      const verify = await fetch("/api/auth/register/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ mode: "add", response: registration }),
      });
      if (!verify.ok) {
        setError("The passkey could not be verified.");
        return;
      }
      setNotice("Passkey added.");
      window.location.reload();
    } catch {
      setError("Passkey creation was cancelled or failed.");
    }
  };

  const signOut = async () => {
    await fetch("/api/auth/logout", { method: "POST" });
    window.location.href = "/";
  };

  const deleteAccount = async () => {
    const typed = window.prompt(
      `This permanently deletes your account, your passkeys, your recovery email, and ALL your published bundles. ` +
        `Installed copies on people's devices keep working, but nobody can download them again.\n\n` +
        `Type your username (${username}) to confirm:`
    );
    if (typed === null) return;
    if (typed.trim().toLowerCase() !== username.toLowerCase()) {
      setError("The username didn't match — nothing was deleted.");
      return;
    }
    const response = await fetch("/api/auth/account", { method: "DELETE" });
    if (response.ok) window.location.href = "/";
    else setError("The account could not be deleted — try again.");
  };

  const removeBundle = async (id: string) => {
    if (!window.confirm(`Remove ${id} from the repository? Installed copies keep working.`)) return;
    const response = await fetch(`/api/bundles/${encodeURIComponent(id)}`, { method: "DELETE" });
    if (response.ok) window.location.reload();
    else setError("Could not remove the bundle.");
  };

  return (
    <>
      <div className="card">
        <h2>{username}</h2>
        <p className="hint">
          Your bundles publish under <span style={{ fontFamily: "ui-monospace, monospace" }}>repo.{username}.…</span>{" "}
          · {passkeyCount} passkey{passkeyCount === 1 ? "" : "s"} on this account
        </p>
        <p style={{ display: "flex", gap: 10 }}>
          <button className="primary" onClick={addPasskey}>
            Add a passkey
          </button>
          <button className="subtle" onClick={signOut}>
            Sign out
          </button>
        </p>
      </div>

      <div className="card">
        <h2>Your bundles</h2>
        {bundles.length === 0 ? (
          <p className="hint">
            Nothing published yet — <a href="/submit">submit a devotion</a>.
          </p>
        ) : (
          bundles.map((bundle) => (
            <p key={bundle.id} style={{ display: "flex", gap: 10, alignItems: "center" }}>
              <span style={{ flex: 1 }}>
                {bundle.name} <span className="hint">({bundle.id})</span>
              </span>
              <button className="subtle" onClick={() => removeBundle(bundle.id)}>
                Remove
              </button>
            </p>
          ))
        )}
      </div>

      <div className="card">
        <h2>Delete account</h2>
        <p className="hint">
          Removes your passkeys, recovery email, and every bundle you've published — immediately
          and permanently. Copies already installed on devices keep working.
        </p>
        <button className="subtle" style={{ color: "var(--danger)", borderColor: "var(--danger)" }} onClick={deleteAccount}>
          Delete my account…
        </button>
      </div>

      {error && <p className="error" aria-live="polite">{error}</p>}
      {notice && <p className="ok" aria-live="polite">{notice}</p>}
    </>
  );
}

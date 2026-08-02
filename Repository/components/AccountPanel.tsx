"use client";

import { startRegistration } from "@simplewebauthn/browser";
import { useState } from "react";

type PasskeyInfo = { credentialId: string; name: string | null; createdAt: string };
type BundleInfo = { id: string; name: string; description: string; tags: string[] };

export function AccountPanel({
  username,
  passkeys,
  bundles,
}: {
  username: string;
  passkeys: PasskeyInfo[];
  bundles: BundleInfo[];
}) {
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editDescription, setEditDescription] = useState("");
  const [editTags, setEditTags] = useState("");

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

  const renamePasskey = async (credentialId: string, current: string | null) => {
    const name = window.prompt("Name this passkey (e.g. “MacBook”, “1Password”):", current ?? "");
    if (name === null || !name.trim()) return;
    const response = await fetch(`/api/auth/passkeys/${encodeURIComponent(credentialId)}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: name.trim() }),
    });
    if (response.ok) window.location.reload();
    else setError("Could not rename the passkey.");
  };

  const removePasskey = async (credentialId: string) => {
    if (!window.confirm("Remove this passkey? You keep signing in with the others.")) return;
    const response = await fetch(`/api/auth/passkeys/${encodeURIComponent(credentialId)}`, {
      method: "DELETE",
    });
    if (response.ok) window.location.reload();
    else {
      const body = await response.json().catch(() => null);
      setError(
        body?.error === "last_passkey"
          ? "That's your only passkey — add another before removing it."
          : "Could not remove the passkey.",
      );
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

  const startEditing = (bundle: BundleInfo) => {
    setEditingId(bundle.id);
    setEditDescription(bundle.description);
    setEditTags(bundle.tags.join(", "));
  };

  const saveEdits = async (id: string) => {
    const response = await fetch(`/api/bundles/${encodeURIComponent(id)}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        description: editDescription,
        tags: editTags.split(",").map((t) => t.trim()).filter(Boolean),
      }),
    });
    if (response.ok) window.location.reload();
    else setError("Could not save the changes.");
  };

  return (
    <>
      <div className="card">
        <h2>{username}</h2>
        <p className="hint">
          Your bundles publish under{" "}
          <span style={{ fontFamily: "ui-monospace, monospace" }}>repo.{username}.…</span> — public
          page: <a href={`/u/${username}`}>/u/{username}</a>
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
        <h2>Passkeys</h2>
        {passkeys.map((passkey) => (
          <p key={passkey.credentialId} style={{ display: "flex", gap: 10, alignItems: "center" }}>
            <span style={{ flex: 1 }}>
              {passkey.name ?? "Unnamed passkey"}{" "}
              <span className="hint">added {passkey.createdAt.slice(0, 10)}</span>
            </span>
            <button className="subtle" onClick={() => renamePasskey(passkey.credentialId, passkey.name)}>
              Rename
            </button>
            <button
              className="subtle"
              onClick={() => removePasskey(passkey.credentialId)}
              disabled={passkeys.length <= 1}
              title={passkeys.length <= 1 ? "Add another passkey before removing this one." : undefined}
            >
              Remove
            </button>
          </p>
        ))}
      </div>

      <div className="card">
        <h2>Your bundles</h2>
        {bundles.length === 0 ? (
          <p className="hint">
            Nothing published yet — <a href="/submit">submit a devotion</a>.
          </p>
        ) : (
          bundles.map((bundle) => (
            <div key={bundle.id} style={{ marginBottom: 10 }}>
              <p style={{ display: "flex", gap: 10, alignItems: "center", margin: 0 }}>
                <span style={{ flex: 1 }}>
                  <a href={`/bundle/${bundle.id}`}>{bundle.name}</a>{" "}
                  <span className="hint">({bundle.id})</span>
                </span>
                <button className="subtle" onClick={() => startEditing(bundle)}>
                  Edit details
                </button>
                <button className="subtle" onClick={() => removeBundle(bundle.id)}>
                  Remove
                </button>
              </p>
              {editingId === bundle.id && (
                <div style={{ paddingLeft: 12, borderLeft: "2px solid var(--brand-primary)" }}>
                  <label className="field">
                    <span>Description</span>
                    <textarea
                      maxLength={500}
                      rows={2}
                      value={editDescription}
                      onChange={(e) => setEditDescription(e.target.value)}
                    />
                  </label>
                  <label className="field">
                    <span>Tags (comma-separated)</span>
                    <input value={editTags} onChange={(e) => setEditTags(e.target.value)} />
                  </label>
                  <p style={{ display: "flex", gap: 10 }}>
                    <button className="primary" onClick={() => saveEdits(bundle.id)}>
                      Save
                    </button>
                    <button className="subtle" onClick={() => setEditingId(null)}>
                      Cancel
                    </button>
                  </p>
                </div>
              )}
            </div>
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

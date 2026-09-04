"use client";

import Link from "next/link";
import { useState } from "react";
import { StatusMessage } from "@/components/StatusMessage";

export type PasskeyInfo = {
  credentialId: string;
  name: string | null;
  createdAt: string;
};

export type AccountBundleInfo = {
  id: string;
  name: string;
  description: string;
  tags: string[];
};

export function AccountPanel({
  username,
  passkeys,
  bundles,
}: {
  username: string;
  passkeys: PasskeyInfo[];
  bundles: AccountBundleInfo[];
}) {
  const [error, setError] = useState<string | null>(null);
  const [activeAction, setActiveAction] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editDescription, setEditDescription] = useState("");
  const [editTags, setEditTags] = useState("");
  const profileHref = `/u/${encodeURIComponent(username)}`;

  const addPasskey = async () => {
    setError(null);
    setActiveAction("add-passkey");
    try {
      const [optionsResponse, { startRegistration }] = await Promise.all([
        fetch("/api/auth/register/options", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ mode: "add" }),
        }),
        import("@simplewebauthn/browser"),
      ]);
      if (!optionsResponse.ok) {
        setError("Could not start adding a passkey.");
        return;
      }
      const registration = await startRegistration({
        optionsJSON: await optionsResponse.json(),
      });
      const verify = await fetch("/api/auth/register/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ mode: "add", response: registration }),
      });
      if (!verify.ok) {
        setError("The passkey could not be verified.");
        return;
      }
      window.location.reload();
    } catch {
      setError("Passkey creation was cancelled or failed.");
    } finally {
      setActiveAction(null);
    }
  };

  const renamePasskey = async (credentialId: string, current: string | null) => {
    const name = window.prompt("Name this passkey (for example, “MacBook” or “1Password”):", current ?? "");
    if (name === null || !name.trim()) return;
    setError(null);
    setActiveAction(`rename-${credentialId}`);
    try {
      const response = await fetch(`/api/auth/passkeys/${encodeURIComponent(credentialId)}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: name.trim() }),
      });
      if (!response.ok) {
        setError("Could not rename the passkey.");
        return;
      }
      window.location.reload();
    } catch {
      setError("Could not rename the passkey — check your connection and try again.");
    } finally {
      setActiveAction(null);
    }
  };

  const removePasskey = async (credentialId: string) => {
    if (!window.confirm("Remove this passkey? You can keep signing in with the others.")) return;
    setError(null);
    setActiveAction(`remove-passkey-${credentialId}`);
    try {
      const response = await fetch(`/api/auth/passkeys/${encodeURIComponent(credentialId)}`, {
        method: "DELETE",
      });
      if (response.ok) {
        window.location.reload();
        return;
      }
      const body = await response.json().catch(() => null);
      setError(
        body?.error === "last_passkey"
          ? "That is your only passkey — add another before removing it."
          : "Could not remove the passkey.",
      );
    } catch {
      setError("Could not remove the passkey — check your connection and try again.");
    } finally {
      setActiveAction(null);
    }
  };

  const signOut = async () => {
    setError(null);
    setActiveAction("sign-out");
    try {
      const response = await fetch("/api/auth/logout", { method: "POST" });
      if (!response.ok) throw new Error("sign-out failed");
      window.location.href = "/";
    } catch {
      setError("Could not sign out — check your connection and try again.");
      setActiveAction(null);
    }
  };

  const deleteAccount = async () => {
    const typed = window.prompt(
      `This permanently deletes your account, passkeys, recovery email, and ALL published bundles. ` +
        `Installed copies keep working, but nobody can download them again.\n\n` +
        `Type your username (${username}) to confirm:`,
    );
    if (typed === null) return;
    if (typed.trim().toLowerCase() !== username.toLowerCase()) {
      setError("The username did not match — nothing was deleted.");
      return;
    }
    setError(null);
    setActiveAction("delete-account");
    try {
      const response = await fetch("/api/auth/account", { method: "DELETE" });
      if (!response.ok) throw new Error("account deletion failed");
      window.location.href = "/";
    } catch {
      setError("The account could not be deleted — try again.");
      setActiveAction(null);
    }
  };

  const removeBundle = async (id: string) => {
    if (!window.confirm(`Remove ${id} from the repository? Installed copies keep working.`)) return;
    setError(null);
    setActiveAction(`remove-bundle-${id}`);
    try {
      const response = await fetch(`/api/bundles/${encodeURIComponent(id)}`, {
        method: "DELETE",
      });
      if (!response.ok) {
        setError("Could not remove the bundle.");
        return;
      }
      window.location.reload();
    } catch {
      setError("Could not remove the bundle — check your connection and try again.");
    } finally {
      setActiveAction(null);
    }
  };

  const startEditing = (bundle: AccountBundleInfo) => {
    setEditingId(bundle.id);
    setEditDescription(bundle.description);
    setEditTags(bundle.tags.join(", "));
  };

  const saveEdits = async (event: React.FormEvent<HTMLFormElement>, id: string) => {
    event.preventDefault();
    setError(null);
    setActiveAction(`save-bundle-${id}`);
    try {
      const response = await fetch(`/api/bundles/${encodeURIComponent(id)}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          description: editDescription,
          tags: editTags
            .split(",")
            .map((tag) => tag.trim())
            .filter(Boolean),
        }),
      });
      if (!response.ok) {
        setError("Could not save the changes.");
        return;
      }
      window.location.reload();
    } catch {
      setError("Could not save the changes — check your connection and try again.");
    } finally {
      setActiveAction(null);
    }
  };

  return (
    <div className="account-grid" aria-busy={activeAction !== null}>
      {error ? <StatusMessage tone="error">{error}</StatusMessage> : null}

      <section className="card" aria-labelledby="account-overview-heading">
        <h2 id="account-overview-heading">@{username}</h2>
        <p className="hint">
          Your bundles publish under <code>repo.{username}.…</code>. Your public profile is{" "}
          <Link href={profileHref}>/u/{username}</Link>.
        </p>
        <div className="action-row">
          <button
            className="button button-primary"
            type="button"
            onClick={addPasskey}
            disabled={activeAction !== null}
          >
            {activeAction === "add-passkey" ? "Adding passkey…" : "Add a passkey"}
          </button>
          <button
            className="button button-subtle"
            type="button"
            onClick={signOut}
            disabled={activeAction !== null}
          >
            {activeAction === "sign-out" ? "Signing out…" : "Sign out"}
          </button>
        </div>
      </section>

      <section className="card" aria-labelledby="passkeys-heading">
        <h2 id="passkeys-heading">Passkeys</h2>
        <p className="hint">Keep at least one passkey. Add a second before removing your last one.</p>
        <ul className="list-clean">
          {passkeys.map((passkey) => {
            const createdDate = passkey.createdAt.slice(0, 10);
            return (
              <li className="managed-row" key={passkey.credentialId}>
                <div className="managed-row-main">
                  <strong>{passkey.name ?? "Unnamed passkey"}</strong>
                  <p className="hint">
                    Added <time dateTime={createdDate}>{createdDate}</time>
                  </p>
                </div>
                <button
                  className="button button-subtle"
                  type="button"
                  onClick={() => renamePasskey(passkey.credentialId, passkey.name)}
                  disabled={activeAction !== null}
                >
                  {activeAction === `rename-${passkey.credentialId}` ? "Renaming…" : "Rename"}
                </button>
                <button
                  className="button button-subtle"
                  type="button"
                  onClick={() => removePasskey(passkey.credentialId)}
                  disabled={passkeys.length <= 1 || activeAction !== null}
                  title={
                    passkeys.length <= 1
                      ? "Add another passkey before removing this one."
                      : undefined
                  }
                >
                  {activeAction === `remove-passkey-${passkey.credentialId}`
                    ? "Removing…"
                    : "Remove"}
                </button>
              </li>
            );
          })}
        </ul>
      </section>

      <section className="card" aria-labelledby="bundles-heading">
        <h2 id="bundles-heading">Your bundles</h2>
        {bundles.length === 0 ? (
          <p className="hint">
            Nothing published yet — <Link href="/submit">submit a devotion</Link>.
          </p>
        ) : (
          <ul className="list-clean">
            {bundles.map((bundle) => {
              const bundleHref = `/bundle/${encodeURIComponent(bundle.id)}`;
              return (
                <li key={bundle.id}>
                  <div className="managed-row">
                    <div className="managed-row-main">
                      <strong>
                        <Link href={bundleHref} dir="auto">
                          {bundle.name}
                        </Link>
                      </strong>
                      <p className="hint identifier">{bundle.id}</p>
                    </div>
                    <button
                      className="button button-subtle"
                      type="button"
                      onClick={() => startEditing(bundle)}
                      disabled={activeAction !== null}
                      aria-expanded={editingId === bundle.id}
                    >
                      Edit details
                    </button>
                    <button
                      className="button button-subtle"
                      type="button"
                      onClick={() => removeBundle(bundle.id)}
                      disabled={activeAction !== null}
                    >
                      {activeAction === `remove-bundle-${bundle.id}` ? "Removing…" : "Remove"}
                    </button>
                  </div>
                  {editingId === bundle.id ? (
                    <form
                      className="bundle-editor"
                      onSubmit={(event) => saveEdits(event, bundle.id)}
                    >
                      <label className="field">
                        <span>Description</span>
                        <textarea
                          maxLength={500}
                          rows={3}
                          dir="auto"
                          value={editDescription}
                          onChange={(event) => setEditDescription(event.target.value)}
                        />
                      </label>
                      <label className="field">
                        <span>Tags</span>
                        <input
                          type="text"
                          value={editTags}
                          onChange={(event) => setEditTags(event.target.value)}
                          aria-describedby={`edit-tags-hint-${bundle.id}`}
                        />
                        <small className="field-hint" id={`edit-tags-hint-${bundle.id}`}>
                          Separate up to eight tags with commas.
                        </small>
                      </label>
                      <div className="action-row">
                        <button
                          className="button button-primary"
                          type="submit"
                          disabled={activeAction !== null}
                        >
                          {activeAction === `save-bundle-${bundle.id}`
                            ? "Saving…"
                            : "Save changes"}
                        </button>
                        <button
                          className="button button-subtle"
                          type="button"
                          onClick={() => setEditingId(null)}
                          disabled={activeAction !== null}
                        >
                          Cancel
                        </button>
                      </div>
                    </form>
                  ) : null}
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <section className="card danger-zone" aria-labelledby="delete-account-heading">
        <h2 id="delete-account-heading">Delete account</h2>
        <p className="hint">
          Permanently removes your passkeys, recovery email, and every bundle you have
          published. Copies already installed on devices keep working.
        </p>
        <button
          className="button button-danger"
          type="button"
          onClick={deleteAccount}
          disabled={activeAction !== null}
        >
          {activeAction === "delete-account" ? "Deleting account…" : "Delete my account…"}
        </button>
      </section>
    </div>
  );
}

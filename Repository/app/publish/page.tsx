"use client";

// The Compose → repository publish receiver. Prosary Compose opens this page in a popup and
// hands over the built bundle via postMessage; everything sensitive then happens first-party
// on this origin — the session cookie, the passkey ceremonies (WebAuthn credentials are bound
// to prayers.prosary.app and can't be exercised from compose.prosary.app), and the actual
// POST /api/bundles. No CORS, no cross-site cookies.
//
// Handshake: on every mount this page posts {type:"prosary-publish-ready"} to its opener;
// Compose answers with {type:"prosary-publish-bundle", name, tags, bytes}. Re-posting on
// mount makes sign-in safe — AuthForms reloads the page on success and the opener simply
// hands the bundle over again.

import { useCallback, useEffect, useState } from "react";
import { AuthForms } from "@/components/AuthForms";

const ALLOWED_OPENERS = ["https://compose.prosary.app", "http://localhost:5173"];

type Payload = { name: string; tags: string[]; bytes: ArrayBuffer; origin: string };

export default function PublishPage() {
  const [username, setUsername] = useState<string | null | "loading">("loading");
  const [payload, setPayload] = useState<Payload | null>(null);
  const [description, setDescription] = useState("");
  const [tags, setTags] = useState("");
  const [busy, setBusy] = useState(false);
  const [publishedId, setPublishedId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  // window is unavailable during prerender — opener presence lands in state on mount.
  const [hasOpener, setHasOpener] = useState(false);

  useEffect(() => {
    setHasOpener(Boolean(window.opener));
    fetch("/api/auth/me")
      .then((r) => r.json())
      .then((body) => setUsername(body.username ?? null))
      .catch(() => setUsername(null));

    const onMessage = (event: MessageEvent) => {
      if (!ALLOWED_OPENERS.includes(event.origin)) return;
      const data = event.data;
      if (data?.type !== "prosary-publish-bundle" || !(data.bytes instanceof ArrayBuffer)) return;
      const manifestTags = Array.isArray(data.tags)
        ? data.tags.filter((t: unknown) => typeof t === "string")
        : [];
      setPayload({
        name: typeof data.name === "string" && data.name ? data.name : "devotion",
        tags: manifestTags,
        bytes: data.bytes,
        origin: event.origin,
      });
      setTags((previous) => previous || manifestTags.join(", "));
    };
    window.addEventListener("message", onMessage);

    if (window.opener) {
      for (const origin of ALLOWED_OPENERS) {
        try {
          (window.opener as Window).postMessage({ type: "prosary-publish-ready" }, origin);
        } catch {
          // Not this origin — the matching one receives it.
        }
      }
    }
    return () => window.removeEventListener("message", onMessage);
  }, []);

  const publish = useCallback(async () => {
    if (!payload) return;
    setBusy(true);
    setError(null);
    try {
      const form = new FormData();
      form.append(
        "file",
        new File([payload.bytes], `${payload.name}.prosaryprayer`, { type: "application/zip" }),
      );
      form.append("description", description);
      form.append("tags", tags);
      const response = await fetch("/api/bundles", { method: "POST", body: form });
      const body = await response.json().catch(() => null);
      if (!response.ok) {
        setError(body?.detail ?? "The bundle could not be published.");
        return;
      }
      setPublishedId(body.id);
      window.opener?.postMessage({ type: "prosary-publish-done", id: body.id }, payload.origin);
    } finally {
      setBusy(false);
    }
  }, [payload, description, tags]);

  if (!payload) {
    return (
      <main>
        <div className="card">
          <h2>Publish from Compose</h2>
          <p className="hint">
            {hasOpener
              ? "Waiting for the bundle from Prosary Compose…"
              : (
                <>
                  This page receives devotions from{" "}
                  <a href="https://compose.prosary.app">Prosary Compose</a> — use its
                  “Publish” button on the Finish screen, or upload a saved file on the{" "}
                  <a href="/submit">submit page</a>.
                </>
              )}
          </p>
        </div>
      </main>
    );
  }

  return (
    <main>
      <div className="card">
        <h2>Publish “{payload.name}”</h2>
        <p className="hint">
          {(payload.bytes.byteLength / 1024).toFixed(0)} KB from Prosary Compose
          {username && typeof username === "string" ? (
            <>
              {" "}— publishing as{" "}
              <span style={{ fontFamily: "ui-monospace, monospace" }}>
                repo.{username}.…
              </span>
            </>
          ) : null}
        </p>

        {username === "loading" ? (
          <p className="hint">Checking your session…</p>
        ) : username === null ? (
          <>
            <p className="hint">Sign in first — the page keeps your bundle while you do.</p>
            <AuthForms />
          </>
        ) : publishedId ? (
          <p className="ok" aria-live="polite">
            Published as {publishedId} — it&apos;s live on the <a href="/">catalog</a> and in the
            apps&apos; Browse tab. You can close this window.
          </p>
        ) : (
          <>
            <label className="field">
              <span>Description (a sentence or two)</span>
              <textarea
                maxLength={500}
                rows={3}
                value={description}
                onChange={(e) => setDescription(e.target.value)}
              />
            </label>
            <label className="field">
              <span>Tags (comma-separated)</span>
              <input type="text" value={tags} onChange={(e) => setTags(e.target.value)} />
            </label>
            <button className="primary" onClick={publish} disabled={busy}>
              Publish
            </button>
          </>
        )}
        {error && <p className="error" aria-live="polite">{error}</p>}
      </div>
    </main>
  );
}

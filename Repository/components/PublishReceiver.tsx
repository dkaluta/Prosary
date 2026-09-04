"use client";

// Prosary Compose opens this route in a popup and transfers the built bundle with postMessage.
// The session cookie, passkey ceremony, and upload then stay first-party on this origin.

import Link from "next/link";
import { useEffect, useState } from "react";
import { AuthForms } from "@/components/AuthForms";
import { StatusMessage } from "@/components/StatusMessage";

const ALLOWED_OPENERS = ["https://compose.prosary.app", "http://localhost:5173"];

type Payload = {
  name: string;
  bytes: ArrayBuffer;
  origin: string;
};

export function PublishReceiver({ username }: { username: string | null }) {
  const [payload, setPayload] = useState<Payload | null>(null);
  const [description, setDescription] = useState("");
  const [tags, setTags] = useState("");
  const [busy, setBusy] = useState(false);
  const [publishedId, setPublishedId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [hasOpener, setHasOpener] = useState<boolean | null>(null);

  useEffect(() => {
    setHasOpener(Boolean(window.opener));
    const onMessage = (event: MessageEvent) => {
      if (!ALLOWED_OPENERS.includes(event.origin) || event.source !== window.opener) return;
      const data = event.data;
      if (data?.type !== "prosary-publish-bundle" || !(data.bytes instanceof ArrayBuffer)) return;
      const manifestTags = Array.isArray(data.tags)
        ? data.tags.filter((tag: unknown): tag is string => typeof tag === "string")
        : [];
      setPayload({
        name: typeof data.name === "string" && data.name ? data.name : "devotion",
        bytes: data.bytes,
        origin: event.origin,
      });
      setTags((current) => current || manifestTags.join(", "));
    };
    window.addEventListener("message", onMessage);

    const opener = window.opener;
    if (opener) {
      for (const origin of ALLOWED_OPENERS) {
        try {
          opener.postMessage({ type: "prosary-publish-ready" }, origin);
        } catch {
          // The matching origin receives the handshake; a closed opener is harmless.
        }
      }
    }
    return () => window.removeEventListener("message", onMessage);
  }, []);

  const publish = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!payload) return;
    setBusy(true);
    setError(null);
    try {
      const form = new FormData();
      form.append(
        "file",
        new File([payload.bytes], `${payload.name}.prosaryprayer`, {
          type: "application/zip",
        }),
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
      window.opener?.postMessage(
        { type: "prosary-publish-done", id: body.id },
        payload.origin,
      );
    } catch {
      setError("The bundle could not be published — check your connection and try again.");
    } finally {
      setBusy(false);
    }
  };

  if (!payload) {
    return (
      <section className="card waiting-card" aria-labelledby="publish-waiting-heading">
        <h2 id="publish-waiting-heading">Waiting for a devotion</h2>
        <p className="hint" role="status" aria-live="polite">
          {hasOpener === false ? (
            <>
              This page receives devotions from{" "}
              <a href="https://compose.prosary.app">Prosary Compose</a>. Use its Publish button,
              or <Link href="/submit">upload a saved bundle</Link> instead.
            </>
          ) : (
            "Keep this window open while Prosary Compose prepares the bundle…"
          )}
        </p>
      </section>
    );
  }

  return (
    <div className="account-grid">
      <section className="card" aria-labelledby="publish-bundle-heading">
        <h2 id="publish-bundle-heading" dir="auto">Publish “{payload.name}”</h2>
        <p className="hint">
          {(payload.bytes.byteLength / 1024).toFixed(0)} KB received securely from Prosary
          Compose
          {username ? (
            <>
              {" "}— publishing under <code>repo.{username}.…</code>
            </>
          ) : null}
          .
        </p>

        {!username ? (
          <StatusMessage tone="info">
            Sign in or create an account below. This window will request the bundle from
            Compose again after sign-in.
          </StatusMessage>
        ) : publishedId ? (
          <StatusMessage tone="success">
            Published as <code>{publishedId}</code>.{" "}
            <Link href={`/bundle/${encodeURIComponent(publishedId)}`}>View it in the catalog</Link>.
            You can now close this window.
          </StatusMessage>
        ) : (
          <form onSubmit={publish} aria-busy={busy}>
            <label className="field" htmlFor="publish-description">
              <span>Description</span>
              <textarea
                id="publish-description"
                maxLength={500}
                rows={4}
                dir="auto"
                value={description}
                onChange={(event) => setDescription(event.target.value)}
                placeholder="A sentence or two about this devotion."
              />
            </label>
            <label className="field" htmlFor="publish-tags">
              <span>Tags</span>
              <input
                id="publish-tags"
                type="text"
                value={tags}
                onChange={(event) => setTags(event.target.value)}
                aria-describedby="publish-tags-hint"
              />
              <small className="field-hint" id="publish-tags-hint">
                Separate up to eight tags with commas.
              </small>
            </label>
            <button className="button button-primary" type="submit" disabled={busy}>
              {busy ? "Publishing…" : "Publish devotion"}
            </button>
          </form>
        )}
        {error ? <StatusMessage tone="error">{error}</StatusMessage> : null}
      </section>

      {!username ? <AuthForms /> : null}
    </div>
  );
}

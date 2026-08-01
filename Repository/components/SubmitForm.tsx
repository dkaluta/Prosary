"use client";

import { useState } from "react";

export function SubmitForm({ username }: { username: string }) {
  const [error, setError] = useState<string | null>(null);
  const [publishedId, setPublishedId] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError(null);
    setPublishedId(null);
    setBusy(true);
    try {
      const response = await fetch("/api/bundles", {
        method: "POST",
        body: new FormData(event.currentTarget),
      });
      const body = await response.json().catch(() => null);
      if (!response.ok) {
        setError(body?.detail ?? "The bundle could not be published.");
        return;
      }
      setPublishedId(body.id);
    } finally {
      setBusy(false);
    }
  };

  return (
    <form className="card" onSubmit={submit}>
      <h2>Submit a devotion</h2>
      <p className="hint">
        Upload a .prosaryprayer authored with{" "}
        <a href="https://compose.prosary.app">Prosary Compose</a> (or by hand — it's validated
        here the same way the apps validate imports). It publishes as{" "}
        <span style={{ fontFamily: "ui-monospace, monospace" }}>repo.{username}.&lt;name&gt;</span>;
        resubmitting the same devotion updates it.
      </p>
      <label className="field">
        <span>Bundle (.prosaryprayer)</span>
        <input type="file" name="file" accept=".prosaryprayer" required />
      </label>
      <label className="field">
        <span>Description (a sentence or two)</span>
        <textarea name="description" maxLength={500} rows={3} />
      </label>
      <label className="field">
        <span>Tags (comma-separated, optional)</span>
        <input type="text" name="tags" placeholder="marian, evening, litany" />
      </label>
      <button className="primary" type="submit" disabled={busy}>
        Publish
      </button>
      {publishedId && (
        <p className="ok" aria-live="polite">
          Published as {publishedId} — it's live on the <a href="/">catalog</a>.
        </p>
      )}
      {error && <p className="error" aria-live="polite">{error}</p>}
    </form>
  );
}

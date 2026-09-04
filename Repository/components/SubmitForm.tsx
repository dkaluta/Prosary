"use client";

import Link from "next/link";
import { useState } from "react";
import { StatusMessage } from "@/components/StatusMessage";

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
    } catch {
      setError("The bundle could not be published — check your connection and try again.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <form className="card" onSubmit={submit} aria-busy={busy}>
      <h2>Bundle details</h2>
      <p className="hint">
        Upload a bundle authored with{" "}
        <a href="https://compose.prosary.app">Prosary Compose</a>. It publishes as{" "}
        <code>repo.{username}.&lt;name&gt;</code>; submitting the same devotion again updates it.
      </p>
      <label className="field" htmlFor="bundle-file">
        <span>Devotion bundle</span>
        <input
          id="bundle-file"
          type="file"
          name="file"
          accept=".prosaryprayer,application/zip"
          aria-describedby="bundle-file-hint"
          required
        />
        <small className="field-hint" id="bundle-file-hint">
          Choose one .prosaryprayer file, up to 8 MB. Its structure and languages are validated.
        </small>
      </label>
      <label className="field" htmlFor="bundle-description">
        <span>Description</span>
        <textarea
          id="bundle-description"
          name="description"
          maxLength={500}
          rows={4}
          dir="auto"
          placeholder="A sentence or two about how and when to pray this devotion."
        />
      </label>
      <label className="field" htmlFor="bundle-tags">
        <span>Tags</span>
        <input
          id="bundle-tags"
          type="text"
          name="tags"
          placeholder="marian, evening, litany"
          aria-describedby="bundle-tags-hint"
        />
        <small className="field-hint" id="bundle-tags-hint">
          Separate up to eight tags with commas. Leave blank to keep the tags from Compose.
        </small>
      </label>
      <button className="button button-primary" type="submit" disabled={busy}>
        {busy ? "Publishing…" : "Publish devotion"}
      </button>
      {publishedId ? (
        <StatusMessage tone="success">
          Published as <code>{publishedId}</code>.{" "}
          <Link href={`/bundle/${encodeURIComponent(publishedId)}`}>View the live devotion</Link>.
        </StatusMessage>
      ) : null}
      {error ? <StatusMessage tone="error">{error}</StatusMessage> : null}
    </form>
  );
}

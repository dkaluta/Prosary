"use client";

// Sign in / create account with a passkey; email is collected once, used only
// for recovery. Mirrors freebee's options -> startRegistration/-Authentication
// -> verify flow.

import { startAuthentication, startRegistration } from "@simplewebauthn/browser";
import { useState } from "react";

async function postJson(url: string, body: unknown): Promise<Response> {
  return fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

export function AuthForms() {
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [recoveryId, setRecoveryId] = useState("");

  const signIn = async () => {
    setError(null);
    setBusy(true);
    try {
      const optionsResponse = await postJson("/api/auth/login/options", { username });
      if (!optionsResponse.ok) {
        setError("No account with that username has a passkey — check the spelling, or recover below.");
        return;
      }
      const assertion = await startAuthentication({ optionsJSON: await optionsResponse.json() });
      const verify = await postJson("/api/auth/login/verify", { response: assertion });
      if (!verify.ok) {
        setError("The passkey could not be verified.");
        return;
      }
      window.location.reload();
    } catch {
      setError("Passkey sign-in was cancelled or failed.");
    } finally {
      setBusy(false);
    }
  };

  const signUp = async () => {
    setError(null);
    setBusy(true);
    try {
      const optionsResponse = await postJson("/api/auth/register/options", {
        mode: "signup",
        username,
        email,
      });
      if (!optionsResponse.ok) {
        const detail = await optionsResponse.json().catch(() => null);
        setError(
          detail?.error === "username_taken"
            ? "That username is taken."
            : detail?.error === "email_taken"
              ? "That email already belongs to an account — use Recover below."
              : detail?.error === "invalid_username"
                ? "Usernames are 3–30 characters: lowercase letters, digits, dashes."
                : "Could not start sign-up."
        );
        return;
      }
      const registration = await startRegistration({ optionsJSON: await optionsResponse.json() });
      const verify = await postJson("/api/auth/register/verify", {
        mode: "signup",
        response: registration,
      });
      if (!verify.ok) {
        setError("The passkey could not be verified.");
        return;
      }
      window.location.reload();
    } catch {
      setError("Passkey creation was cancelled or failed.");
    } finally {
      setBusy(false);
    }
  };

  const recover = async () => {
    setError(null);
    setBusy(true);
    try {
      await postJson("/api/auth/recover/start", { identifier: recoveryId });
      setNotice("If that account exists, a recovery link is on its way to its email address.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <div className="card">
        <h2>Sign in</h2>
        <p className="hint">Your username plus the passkey saved on this device — no password.</p>
        <label className="field">
          <span>Username</span>
          <input
            type="text"
            autoComplete="username webauthn"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
          />
        </label>
        <button className="primary" disabled={busy || !username} onClick={signIn}>
          Sign in with passkey
        </button>
      </div>

      <div className="card">
        <h2>Create an account</h2>
        <p className="hint">
          The username becomes your bundle namespace (repo.{username || "you"}.…). The email is
          used only to recover the account — never shown, never for sign-in.
        </p>
        <label className="field">
          <span>Username</span>
          <input type="text" value={username} onChange={(e) => setUsername(e.target.value)} />
        </label>
        <label className="field">
          <span>Recovery email</span>
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <button className="primary" disabled={busy || !username || !email} onClick={signUp}>
          Create account with passkey
        </button>
      </div>

      <div className="card">
        <h2>Recover</h2>
        <p className="hint">Lost your passkeys? A link to your recovery email adds a new one.</p>
        <label className="field">
          <span>Username or recovery email</span>
          <input type="text" value={recoveryId} onChange={(e) => setRecoveryId(e.target.value)} />
        </label>
        <button className="primary" disabled={busy || !recoveryId} onClick={recover}>
          Send recovery link
        </button>
      </div>

      {error && <p className="error" aria-live="polite">{error}</p>}
      {notice && <p className="ok" aria-live="polite">{notice}</p>}
    </>
  );
}

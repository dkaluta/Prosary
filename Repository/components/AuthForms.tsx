"use client";

// Sign in and account creation use passkeys. The WebAuthn browser library is deliberately
// imported only after an action, so the account shell and recovery-email form stay light.

import { useState } from "react";
import { StatusMessage } from "@/components/StatusMessage";

async function postJson(url: string, body: unknown): Promise<Response> {
  return fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

type ActiveAction = "signin" | "signup" | "recover" | null;

export function AuthForms() {
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [activeAction, setActiveAction] = useState<ActiveAction>(null);
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [recoveryId, setRecoveryId] = useState("");
  const busy = activeAction !== null;

  const signIn = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError(null);
    setNotice(null);
    setActiveAction("signin");
    try {
      const [optionsResponse, { startAuthentication }] = await Promise.all([
        postJson("/api/auth/login/options", { username }),
        import("@simplewebauthn/browser"),
      ]);
      if (!optionsResponse.ok) {
        setError(
          "No account with that username has a passkey — check the spelling, or use recovery below.",
        );
        return;
      }
      const assertion = await startAuthentication({
        optionsJSON: await optionsResponse.json(),
      });
      const verify = await postJson("/api/auth/login/verify", { response: assertion });
      if (!verify.ok) {
        setError("The passkey could not be verified.");
        return;
      }
      window.location.reload();
    } catch {
      setError("Passkey sign-in was cancelled or failed.");
    } finally {
      setActiveAction(null);
    }
  };

  const signUp = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError(null);
    setNotice(null);
    setActiveAction("signup");
    try {
      const [optionsResponse, { startRegistration }] = await Promise.all([
        postJson("/api/auth/register/options", {
          mode: "signup",
          username,
          email,
        }),
        import("@simplewebauthn/browser"),
      ]);
      if (!optionsResponse.ok) {
        const detail = await optionsResponse.json().catch(() => null);
        setError(
          detail?.error === "username_taken"
            ? "That username is taken."
            : detail?.error === "email_taken"
              ? "That email already belongs to an account — use recovery below."
              : detail?.error === "invalid_username"
                ? "Usernames are 3–30 characters: lowercase letters, digits, and dashes."
                : detail?.error === "invalid_email"
                  ? "Enter a valid recovery email address."
                  : "Could not start account creation.",
        );
        return;
      }
      const registration = await startRegistration({
        optionsJSON: await optionsResponse.json(),
      });
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
      setActiveAction(null);
    }
  };

  const recover = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError(null);
    setNotice(null);
    setActiveAction("recover");
    try {
      const response = await postJson("/api/auth/recover/start", {
        identifier: recoveryId,
      });
      if (!response.ok) {
        setError("The recovery request could not be sent. Wait a moment and try again.");
        return;
      }
      setNotice("If that account exists, a recovery link is on its way to its email address.");
    } catch {
      setError("The recovery request could not be sent — check your connection and try again.");
    } finally {
      setActiveAction(null);
    }
  };

  return (
    <div>
      {error ? <StatusMessage tone="error">{error}</StatusMessage> : null}
      {notice ? <StatusMessage tone="success">{notice}</StatusMessage> : null}

      <div className="auth-grid" aria-busy={busy}>
        <form className="card" onSubmit={signIn}>
          <h2>Sign in</h2>
          <p className="hint">Use your username and a passkey saved on this device.</p>
          <label className="field" htmlFor="signin-username">
            <span>Username</span>
            <input
              id="signin-username"
              type="text"
              autoComplete="username webauthn"
              value={username}
              onChange={(event) => setUsername(event.target.value)}
              required
            />
          </label>
          <button className="button button-primary" type="submit" disabled={busy || !username}>
            {activeAction === "signin" ? "Signing in…" : "Sign in with passkey"}
          </button>
        </form>

        <form className="card" onSubmit={signUp}>
          <h2>Create an account</h2>
          <p className="hint">
            Your username becomes <code>repo.{username || "you"}.…</code>. Your email is
            private and used only for recovery.
          </p>
          <label className="field" htmlFor="signup-username">
            <span>Username</span>
            <input
              id="signup-username"
              type="text"
              autoComplete="username"
              minLength={3}
              maxLength={30}
              pattern="[A-Za-z][A-Za-z0-9-]{2,29}"
              value={username}
              onChange={(event) => setUsername(event.target.value)}
              aria-describedby="username-hint"
              required
            />
            <small className="field-hint" id="username-hint">
              Letters, digits, and dashes; start with a letter. The published name is lowercase.
            </small>
          </label>
          <label className="field" htmlFor="signup-email">
            <span>Recovery email</span>
            <input
              id="signup-email"
              type="email"
              autoComplete="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              required
            />
          </label>
          <button
            className="button button-primary"
            type="submit"
            disabled={busy || !username || !email}
          >
            {activeAction === "signup" ? "Creating account…" : "Create account with passkey"}
          </button>
        </form>

        <form className="card recovery-card" onSubmit={recover}>
          <h2>Recover access</h2>
          <p className="hint">
            Lost your passkeys? We will send a single-use link to your private recovery email.
          </p>
          <label className="field" htmlFor="recovery-identifier">
            <span>Username or recovery email</span>
            <input
              id="recovery-identifier"
              type="text"
              autoComplete="username"
              value={recoveryId}
              onChange={(event) => setRecoveryId(event.target.value)}
              required
            />
          </label>
          <button
            className="button button-subtle"
            type="submit"
            disabled={busy || !recoveryId}
          >
            {activeAction === "recover" ? "Sending link…" : "Send recovery link"}
          </button>
        </form>
      </div>
    </div>
  );
}

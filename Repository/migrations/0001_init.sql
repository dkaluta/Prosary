-- prayers.prosary.app initial schema. Forward-only, idempotent (freebee's migration
-- conventions): never edit after merge to main — write a new file.

CREATE EXTENSION IF NOT EXISTS citext;

-- Username-first identity: the username owns the repo.<username>.* bundle namespace.
-- Email exists ONLY for account recovery (a recovery link registers a new passkey) —
-- it is never shown publicly and never used for sign-in.
CREATE TABLE IF NOT EXISTS users (
  id          UUID PRIMARY KEY,
  username    CITEXT NOT NULL UNIQUE,
  email       CITEXT NOT NULL UNIQUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS passkeys (
  credential_id  TEXT PRIMARY KEY,
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  public_key     TEXT NOT NULL,
  counter        BIGINT NOT NULL DEFAULT 0,
  transports     TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS passkeys_user_idx ON passkeys (user_id);

-- Pending WebAuthn ceremonies, keyed by challenge and consumed exactly once
-- (freebee's pending-registration pattern, generalized over ceremony kinds).
CREATE TABLE IF NOT EXISTS webauthn_challenges (
  challenge   TEXT PRIMARY KEY,
  kind        TEXT NOT NULL, -- signup | login | add | recovery
  user_id     UUID,
  username    CITEXT,
  email       CITEXT,
  expires_at  TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS recovery_tokens (
  token_hash  TEXT PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  TIMESTAMPTZ NOT NULL,
  used_at     TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS bundles (
  id          TEXT PRIMARY KEY, -- repo.<username>.<name>
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  languages   TEXT[] NOT NULL,
  tags        TEXT[] NOT NULL DEFAULT '{}',
  file_url    TEXT NOT NULL,
  file_size   INTEGER NOT NULL,
  downloads   BIGINT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS bundles_created_idx ON bundles (created_at DESC);
CREATE INDEX IF NOT EXISTS bundles_user_idx ON bundles (user_id);

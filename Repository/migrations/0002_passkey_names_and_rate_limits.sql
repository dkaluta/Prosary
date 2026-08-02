-- Passkeys become nameable ("MacBook", "1Password") so the account page can list and prune
-- them; rate_limits is freebee's fixed-window pattern for the auth endpoints.
ALTER TABLE passkeys ADD COLUMN name TEXT;

CREATE TABLE rate_limits (
    key          TEXT PRIMARY KEY,
    window_start TIMESTAMPTZ NOT NULL,
    count        INTEGER NOT NULL
);

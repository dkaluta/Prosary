# Prosary Prayers — the devotion repository

`https://prayers.prosary.app`: accounts, submissions, and a catalog of shareable
`.prosaryprayer` bundles (the format in `../Shared/ARCHITECTURE.md` § Content bundles).
Next.js (App Router, TypeScript) on Vercel — **Root Directory `Repository`**, framework
preset Next.js, production tracks `main`; DNS: Namecheap CNAME `prayers →
cname.vercel-dns.com`. Architecture mirrors freebee's conventions (postgres.js tagged
templates, SQL migrations, HMAC-cookie sessions, request-derived WebAuthn RP info).

## How it works

- **Identity is username-first**: sign-up takes a username + passkey (WebAuthn via
  `@simplewebauthn`). The username owns the `repo.<username>.*` bundle namespace. Email is
  collected once and used **only for recovery** — a 30-minute single-use link that registers a
  new passkey (`/recover/[token]`). No passwords anywhere.
- **Submissions** (`POST /api/bundles`, signed-in): upload ordinary Compose output; the server
  validates it like the apps' `installPack` (readable zip, manifest + devotion parse, content
  per declared language, no `builtinKind`) and **re-stamps the manifest id** to
  `repo.<username>.<name>` by rebuilding the zip (`lib/bundles.ts` + `lib/zip.ts`, a copy of
  Compose's zip module — keep them in sync). The file lands in **Vercel Blob**
  (`bundles/<id>.prosaryprayer`, public); metadata lands in **Postgres (Neon)**. Resubmitting
  the same devotion updates it; ids are guarded against cross-user takeover.
- **Catalog**: `/` (search + language filter), `GET /api/bundles`, and the versioned
  **`/index.json`** contract (`{prosaryRepository: 1, bundles: [...]}`) for the future in-app
  browser. Downloads go through `/api/download/<id>` (counts, then redirects to the blob).
- **Database**: schema in `migrations/NNNN_*.sql` — forward-only, idempotent, tracked in
  `_migrations`. Apply locally with `npm run db:migrate`; in production with
  `POST /api/admin/migrate` (header `x-admin-secret: $ADMIN_SECRET`).

## Environment

| Variable | Purpose |
|---|---|
| `POSTGRES_URL` (or `DATABASE_URL`) | Neon connection string — auto-injected by the Vercel Neon integration |
| `BLOB_READ_WRITE_TOKEN` | Vercel Blob — auto-injected by the Blob store |
| `SESSION_SECRET` | 32+ chars, `openssl rand -base64 48` — required in production |
| `ADMIN_SECRET` | guards `POST /api/admin/migrate` |
| `RESEND_API_KEY` | recovery email via Resend; unset = links log to stdout (dev) |
| `EMAIL_FROM` | optional sender override (default `Prosary Prayers <noreply@prosary.app>`) |
| `APP_ORIGIN` | optional; pins emailed link origins (otherwise request-derived) |

Provisioning: Vercel → Storage → **Neon** (Marketplace) and a **Blob** store, both connected
to the project; set `SESSION_SECRET`/`ADMIN_SECRET`; then run the migrate endpoint once and
`npm run db:seed` locally (after `vercel env pull`) to create the founding user + Kyrie
bundle. The seeded account has no passkey — claim it via **Recover** on `/account`.

## Commands

| Command | Action |
|---|---|
| `npm run dev` | Dev server (localhost — WebAuthn works there without config) |
| `npm run build` | Type-check + production build (no env needed; pages degrade gracefully) |
| `npm run db:migrate` | Apply pending migrations |
| `npm run db:seed` | Migrations + founding user + the Kyrie seed bundle |

## Deliberately not yet built

Rate limiting on the auth endpoints (freebee's `rate_limits` pattern is the template),
passkey naming/removal UI, tag-based browsing (the `tags` column and catalog field exist —
see the prayer-tags future feature), and the in-app repository browser.

# Prosary landing page

Astro + TypeScript static site for `https://prosary.app`.

## Commands

Run from this `website/` directory:

| Command | Action |
|---|---|
| `npm install` | Install dependencies |
| `npm run dev` | Start local dev server at `localhost:4321` |
| `npm run build` | Build the production site to `./dist/` |
| `npm run preview` | Preview the build locally before deploying |

## Deployment

Pushes to `main` that touch `Shared/website/**` or the root `LICENSE` are built and deployed to
GitHub Pages automatically by
[`.github/workflows/deploy-pages.yml`](../../.github/workflows/deploy-pages.yml). Enable it once via
repo **Settings → Pages → Build and deployment → Source: GitHub Actions**.

## Custom domain (Namecheap DNS)

`public/CNAME` already declares `prosary.app` as the custom domain — GitHub handles that half
automatically once Pages is enabled. On the Namecheap side (Domain List → Manage → Advanced DNS
for `prosary.app`), point the apex domain at GitHub's Pages IPs with four `A` records:

| Type | Host | Value |
|------|------|-------|
| A | @ | 185.199.108.153 |
| A | @ | 185.199.109.153 |
| A | @ | 185.199.110.153 |
| A | @ | 185.199.111.153 |

Optional, for `www.prosary.app` to also work — add a `CNAME` record:

| Type | Host | Value |
|------|------|-------|
| CNAME | www | dkaluta.github.io |

Then in GitHub Settings → Pages, enter `prosary.app` as the custom domain and enable "Enforce
HTTPS" once DNS has propagated (can take up to 24-48 hours).

## Editing

- `src/layouts/BaseLayout.astro` — shared metadata, navigation, skip link, and page shell.
- `src/pages/index.astro` — the landing page content.
- `src/pages/privacy.astro` — the privacy policy for the native apps and both web tools.
- `src/pages/license.astro` — the license page; its text is read from the root `LICENSE` at build
  time rather than duplicated here.
- `src/styles/global.css` — shared responsive, light/dark, contrast, focus, and reduced-motion
  styling.
- The remaining inline TODO in `index.astro` is for real screenshots. The TestFlight badge should
  become an App Store badge when the Apple release leaves testing.

# Prosary landing page

Astro + TypeScript static site for `https://prosary.app`.

## Commands

Run from this `website/` directory:

| Command | Action |
|---|---|
| `npm install` | Install dependencies |
| `npm run dev -- --background` | Start the local server in the background at `localhost:4321` |
| `npm run astro -- dev status` | Check the background server |
| `npm run astro -- dev stop` | Stop the background server |
| `npm run build` | Build the production site to `./dist/` |
| `npm run check` | Check Astro templates and TypeScript |
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
- `src/data/downloads.ts` — verified beta availability, platform links, and the Windows release
  version. The stable landing-page section is `https://prosary.app/#download`; Windows is
  directly addressable at `https://prosary.app/#windows`.
- `src/components/LineIcon.astro` — small decorative SVG symbols; these are not app screenshots.
- `src/pages/privacy.astro` — the privacy policy for the native apps and both web tools.
- `src/pages/license.astro` — the license page; its text is read from the root `LICENSE` at build
  time rather than duplicated here.
- `src/styles/global.css` — shared responsive, light/dark, contrast, focus, and reduced-motion
  styling.
- The site uses the genuine canonical app icon; it does not present illustrative UI as a screenshot.
- Release links are deliberately explicit. Windows points to a verified published
  GitHub testing release, including its public certificate and installation guide. Change the
  version and links together after a newer release is public. Replace them with the Microsoft
  Store listing only after its direct link is live and verified.
- Apple’s public invitation must not imply that an internal TestFlight build has passed external
  review. Android is a closed test and keeps its invitation link visible.
- Privacy and license pages share the responsive layout. The canonical license is still read
  from the root `LICENSE`; original text’s CC0 dedication remains distinct from software licensing.

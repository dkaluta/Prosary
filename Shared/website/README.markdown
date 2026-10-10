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
- `src/data/downloads.ts` — verified beta availability and platform links.
  The stable landing-page section is `https://prosary.app/#download`; Windows is
  directly addressable at `https://prosary.app/#windows`.
- `src/components/StoreBadge.astro` — accessible beta/store links with aligned download badges.
  TestFlight uses `@csauvage/app-store-button`, rendered at build time with React's static
  renderer. The generated page needs no React runtime or device detection.
- `src/components/LineIcon.astro` — small decorative SVG symbols; these are not app screenshots.
- `src/components/RosaryArtwork.astro` — the decorative 59-bead rosary in the landing-page hero.
  Its 55 loop beads and four stem beads are generated as vector artwork.
- `src/pages/privacy.astro` — the privacy policy for the native apps and both web tools.
- `src/pages/license.astro` — the license page; its text is read from the root `LICENSE` at build
  time rather than duplicated here.
- `src/styles/global.css` — shared responsive, light/dark, contrast, focus, and reduced-motion
  styling.
- The site uses the genuine canonical app icon; it does not present illustrative UI as a screenshot.
- Windows points to the verified Microsoft Store beta listing. Its secondary link retains the
  signed standalone installers, public testing certificate, and installation guide on GitHub.
  Keep release URLs current after verifying availability; omit versions from the visible badges.
- Apple’s public invitation must not imply that an internal TestFlight build has passed external
  review. Android is a closed test and keeps its invitation link visible.
- Privacy and license pages share the responsive layout. The canonical license is still read
  from the root `LICENSE`; original text's CC0 dedication remains distinct from software licensing.

## Page design

The homepage follows the prayer book, readings and languages, personal library, and beta
downloads. Its display headings use a system serif family alongside the system sans-serif
body and controls. Colors, rounded surfaces, focus outlines, and control sizing continue to
come from the canonical Prosary tokens; dark mode follows the system.

The hero's Latin excerpt is imported directly from `Shared/content/rosary/content/la.json`
at build time and preserves the first two lines of `subTuumPraesidium`. Keep the quote as
accessible HTML with its language and prayer title, and retain the decorative rosary on
small screens. The illustration and text do not add a client script.

## Download badge credits

- The TestFlight badge comes from [Clément Sauvage's app-store-button library](https://github.com/csauvage/app-store-button)
  under its [MIT license](public/badges/app-store-button.LICENSE.txt), preserved with the deployed assets.
  This is the library's generated TestFlight artwork, rather than an Apple App Store badge.
- `public/badges/google-play.png` is Google's unmodified
  [English badge](https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png).
  Preserve its built-in clear space and follow Google's
  [brand guidelines](https://developer.android.com/distribute/marketing-tools/brand-guidelines).
  Google Play and the Google Play logo are trademarks of Google LLC.
- `public/badges/microsoft-store.svg` is Microsoft's unmodified
  [English dark badge](https://get.microsoft.com/images/en-us%20dark.svg).
  Microsoft Store and its badge remain Microsoft's trademarks.

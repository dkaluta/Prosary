# Prosary Compose

React + TypeScript single-page app for `https://compose.prosary.app` — a zero-jargon wizard
that lets a non-technical author build and share a `.prosaryprayer` devotion bundle
(see `../Shared/ARCHITECTURE.md` § Content bundles for the format it emits).

**Everything runs in the browser.** There is no backend: validation is a client-side port of
`../Shared/tools/validate-devotion.py`, bundles are packed/unpacked with a dependency-free zip
module (`src/format/zip.ts`, the counterpart of iOS's `MinimalZipReader`), artwork is
square-cropped with a canvas, and the only persistence is a localStorage autosave plus
"Save project" files (`.prosarycompose`, JSON). Nothing an author writes ever leaves their
device.

## Commands

Run from this `Compose/` directory:

| Command | Action |
|---|---|
| `npm install` | Install dependencies |
| `npm run dev` | Start the Vite dev server at `localhost:5173` |
| `npm run build` | Type-check and build the production site to `./dist/` |
| `npm run preview` | Preview the production build locally |

## Deployment (Vercel)

The Vercel project imports this repository with **Root Directory `Compose`**; the Vite preset's
defaults do the rest (`npm run build`, output `dist`). Production deploys track `main`. The
`compose.prosary.app` domain is attached to the project, with a Namecheap CNAME record
`compose → cname.vercel-dns.com`.

## Structure

- `src/format/` — the bundle format, UI-free: `catalog.ts` (languages/common prayers/icons
  mirrored from the apps), `project.ts` (editor state + project-file serialization),
  `zip.ts`, `pack.ts` (Project → bundle), `unpack.ts` (bundle → Project), `validate.ts`
  (client-side authoring rules).
- `src/ui/` — the five wizard screens (Basics, Prayers, Order, Audio, Finish) and media
  helpers. Prayers is the library where texts are written per language; Order arranges the
  sequence, and several steps may pray the same library prayer (they share one bodyKey in the
  emitted bundle, like the Trisagion's repeated acclamation).
- The wizard authors the flat `steps` devotion type; bead-structured ("rosary"), multi-day
  ("days"), variants, and options.json authoring are future work — `unpack.ts` declines such
  bundles with a plain-language message rather than flattening them.

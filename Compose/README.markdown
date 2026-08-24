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
- `src/ui/` — the four wizard screens (Basics, Prayers, Audio, Finish) and media helpers.
- The language picker mirrors the apps' nine-language `LanguageCatalog`: Latin, English,
  Arabic, Hebrew, Classical Syriac/Aramaic, Greek, Spanish, Russian, and Tagalog. A bundle still
  declares only the languages for which its author supplies complete content.
- The wizard authors the `steps` devotion type — flat or with **alternate forms** (the
  format's variants, per-rite `defaultForLanguages` included) — and the multi-day `days`
  type. Bead-structured ("rosary") devotions, option-gated steps, seasonal step swaps, and
  recordings-tied-to-forms remain future work — `unpack.ts` declines such bundles with a
  plain-language message rather than silently flattening them.
- The community repository currently accepts the six languages with complete coverage across
  the original built-in bundles (`la`, `en`, `ar`, `he`, `ru`, `tl`). Compose can author
  `arc`, `el`, and `es` bundles for direct import, but publishing those through
  prayers.prosary.app is not supported yet.
- `scripts/e2e.ts` (`npm run e2e`) authors projects through the same modules the browser
  uses, packs, reopens, and demands a byte-stable round trip; CI then validates the emitted
  bundles with the canonical `validate-devotion.py` — two writers, one format.

# Prosary Compose

React + TypeScript single-page app for `https://compose.prosary.app` — a zero-jargon wizard
that lets a non-technical author build and share a `.prosaryprayer` devotion bundle
(see `../Shared/ARCHITECTURE.markdown` § Content bundles for the format it emits).

**Everything runs in the browser.** There is no backend: validation is a client-side port of
`../Shared/tools/validate-devotion.py`, bundles are packed/unpacked with a dependency-free zip
module (`src/format/zip.ts`, the counterpart of iOS's `MinimalZipReader`), artwork is
square-cropped with the browser's native image decoder and canvas, and autosaves use IndexedDB.
Metadata and binary uploads live in separate records, so typing never re-encodes or duplicates
large media as base64; old localStorage autosaves migrate automatically after the first successful
native save. Portable "Save project" files (`.prosarycompose`, JSON) still carry their media so
they can be moved between devices. Nothing an author writes ever leaves their device.

Image and audio previews use short-lived object URLs that are revoked as screens and files change.
Bundle imports reject unsafe paths, duplicate entries, unsupported/encrypted or Zip64 archives,
oversized indexes and payloads, inconsistent local/central headers, overlapping ranges, invalid
data descriptors, decompression-size mismatches, and CRC failures before content enters editor
state. Files not referenced by the devotion are not retained.

## Commands

Run from this `Compose/` directory:

| Command | Action |
|---|---|
| `npm install` | Install dependencies |
| `npm run dev` | Start the Vite dev server at `localhost:5173` |
| `npm run build` | Type-check and build the production site to `./dist/` |
| `npm run preview` | Preview the production build locally |
| `npm run e2e` | Exercise projects, bundles, autosave splitting, media pruning, and malformed zip rejection |

## Deployment (Vercel)

The Vercel project imports this repository with **Root Directory `Compose`**; the Vite preset's
defaults do the rest (`npm run build`, output `dist`). Production deploys track `main`. The
`compose.prosary.app` domain is attached to the project, with a Namecheap CNAME record
`compose → cname.vercel-dns.com`.

## Structure

- `src/format/` — the bundle format, UI-free: `catalog.ts` (languages/common prayers/icons
  mirrored from the apps), `project.ts` (editor state), `projectFile.ts` (portable project-file
  serialization), `zip.ts`, `pack.ts` (Project → bundle), `unpack.ts` (bundle → Project), and
  `validate.ts` (client-side authoring rules).
- `src/storage/` — the versioned IndexedDB autosave and one-time legacy migration.
- `src/ui/` — the four wizard screens (Basics, Prayers, Audio, Finish) and media helpers.
- The UI uses semantic browser controls, visible keyboard focus, 44-pixel targets, named status
  and error regions, a skip link, native file/color/time/audio controls, RTL-aware fields, forced
  colors, reduced-motion behavior, and responsive layouts from phone widths upward.
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

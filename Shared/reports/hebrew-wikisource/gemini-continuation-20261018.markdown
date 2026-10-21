# Continue the Hebrew source-note review in Gemini

Continue the ongoing Prosary Hebrew deuterocanon review. The goal is to resolve unreadable-point annotations only where the printed source supports an exact reading, preserve genuine uncertainty, and integrate approved changes consistently into the app's shared and generated data. Continue the existing review queue; do not restart the project or assume every remaining note can be removed.

This handoff was prepared on 2026-10-18. Some batch filenames retain `20261017`; that is a batch identifier, not the actual date of every review.

## Mandatory source: PSIK, in Chrome

**Do the source-reading work in PSIK, using the open Kahana volumes in the user's signed-in Chrome session, for every pass.** The user explicitly asked for Chrome throughout, confirmed that both volumes were open, and authorized the browser connection to read them. The preceding agent successfully used the ChatGPT for Chrome extension. Gemini must use an available, authorized Chrome browser connection capable of reading the same PSIK tabs. Do not claim browser access until it actually works, and do not assume Gemini has access to the ChatGPT extension merely because that extension is logged in.

- Kahana volume A: <https://ebooks-psik-io.eu1.proxy.openathens.net/pdfViewerGlance/12306>
- Kahana volume B: <https://ebooks-psik-io.eu1.proxy.openathens.net/pdfViewerGlance/12307>

Use the actual scanned page images in the PSIK reader. Preserve the logged-in tabs. Do not replace this workflow with another edition, an inferred transcription, or local-PDF-only review. Previously captured, hash-pinned images from these same authorized PSIK tabs may be reused as controls. Preserve original screenshot bytes and record their provenance. Do not publish signed storage URLs or encrypted iframe URLs; use the stable reader links above.

If this Gemini environment cannot read the Chrome tabs or local files, state the specific missing capability before making source claims or claiming edits. A source-only review can return precise proposed changes and evidence; repository integration requires actual file access and verification.

## Workspace and progress

Repository: `/Users/dk/Developer/Personal/Prosary`

Current branch: `feature/home-card-columns`. Preserve the branch, all unrelated work, and the existing staged Xcode Cloud manifest. Do not commit, push, release, switch branches, reset, clean, or delete old archives as part of this continuation.

Read `AGENTS.md`, the relevant section of `Shared/ARCHITECTURE.markdown`, `Shared/SCRIPTURE-SOURCE-NOTES.markdown`, and `Shared/BIBLE-SOURCE-STRUCTURE.markdown` before integration. New Markdown files use `.markdown`.

At handoff, **Pass 32's eight corrections are applied, regenerated, independently audited, and tested**:

| State | Count |
|---|---:|
| Source marks resolved since the 650-note checkpoint | 193 |
| Reviewed unreadable points still ambiguous | 230 |
| Unreadable points awaiting their first review | 222 |
| Protected restored-letter disclosures | 5 |
| All remaining annotations | 457 |

First-cycle coverage is **423 of 645 unreadable points, about 65.6%**. This is coverage, not a claim that 65.6% of the uncertainties were resolved. Resolved marks are 193 of 645 unreadable points, about 29.9%. The five restored-letter disclosures are preserved and are not targets for deletion.

Daily-reading source units were reviewed first; 22 such units still retain 41 notes. Continue all remaining unreviewed complete units in descending note-count order. Finish this first cycle before revisiting retained ambiguities; then revisit ambiguities daily-first and by descending count. Use the pinned review-sequence file, not memory of a queue.

## Important unfinished checkpoint step

**The final Pass 32 checkpoint freeze did not complete. There is no finalized priority-after-pass32 file or frozen Pass 33 baseline yet.**

All tests passed: 114 shared, 582 Android tests in 72 suites, and 56 Apple tests. No failures or skips. Windows runtime tests were not run on this Mac; its generated data copies were checked.

The finalizer stopped because `iOS/Prosary/Localizable.xcstrings` differs from its preserved pre-pass hash. The cause has not been established. This file was left untouched during handoff preparation. Do not restore it from Git, erase unrelated changes, change the old preservation evidence, or silently disable the guard. Investigate and explicitly account for this separate drift before finalizing. If the change belongs to another active task, preserve it and document a narrowly scoped reconciliation with exact before/current hashes.

- Expected preserved hash: `deffffb55235c325e5da512f39fa74de569149d16e355895c7cfc1d9754bbb3f`
- Hash at handoff: `c4788730124f77d9288962eca6277050302ea8cc2fa042e72c4637270ab635bc`
- Log: `/private/tmp/prosary-hebrew-pass32-20261017/final-validation.log`
- Finalizer: `/private/tmp/prosary-hebrew-pass32-20261017/finalize-evidence-and-priority.py`

`record-validation.py` succeeded before that failure. All source changes remain applied. Do not apply Pass 32 again. The finalizer checks prerequisites before writing; it has not written the next priority or baseline. After resolving the preservation discrepancy, recheck the current files and carefully finish finalization; do not manufacture a successful checkpoint by changing counts.

## Current evidence and files

Paths below are relative to the repository unless absolute.

- Canonical twelve books: `Shared/content/hebrew-deuterocanon/*.json`
- Canonical approval: `Shared/content/hebrew-deuterocanon-review.json`
- Daily selection approval: `Shared/tools/hebrew-daily-reading-reviews.json`
- Catholic presentation approval: `Shared/tools/hebrew-bible-presentation-reviews.json`
- Current integration: `Shared/reports/hebrew-wikisource/source-note-integration-20261017-pass32.json`
  - SHA256 at handoff: `c68c438301d9aba757185810daa3c2b92f9486992b0bc71491d3bc2790c33bb6`
  - Source/data/test validation is recorded; the final freeze is still pending.
- Last frozen queue: `Shared/reports/hebrew-wikisource/source-note-priority-20261017-after-pass31.json`
  - SHA256 `aa891293b7400860183a429b70c133574c20897f41e7f780c2fb619c1925eec7`
  - This queue predates the applied Pass 32. Do not redo its first three units.
- Sequence policy: `Shared/reports/hebrew-wikisource/source-note-review-sequence-20261017.json`
  - SHA256 `f406dcc6edb5ae5063944f7cf3ef587c950b24182d3ba19a46366a14c84dc642`
- Companion snapshot: `Shared/reports/hebrew-wikisource/gemini-continuation-snapshot-20261018.json`
  - SHA256 `0419251f1ee19f4c5bc52f7977e9f434bd852ba718e231b33a6bd77967b8f101`
  - Contains hashes for all 18 current source/gate/data files, exact text and note objects for the next three units, test evidence, the finalization discrepancy, and hashes of all 13 next-pass captures. It is a handoff snapshot, not a finalized Pass 33 baseline or approval packet.

Pass 32 workspace: `/private/tmp/prosary-hebrew-pass32-20261017`. Its `baseline/` is the old **465-note** baseline, not the current 457-note state. It contains `inputs.json`, `approved-whitelist.json`, `accepted.json`, the exact proposed files, independent source/pixel/mutation audits, live-byte confirmation, test logs, and `apple.xcresult`. Preserve temporary workspaces because audit records reference them.

The audit field `all457SurvivorsIndependentlyResolved` means the surviving annotations' physical locations were resolved. It does **not** mean the remaining 457 annotations were deciphered or can be deleted. A fresh preservation check found all 9,925 historical files and 21 protected untracked files unchanged, with the branch and staged patch unchanged; the localization file above is the sole mismatch among 2,603 protected tracked files.

The authoritative Pass 32 source reports are `WIS-unit11-8-point-comparison-20261017-pass32.json`, `WIS-unit12-5-point-comparison-20261017-pass32.json`, and `WIS-unit16-19-point-comparison-20261017-pass32.json` under `Shared/reports/hebrew-wikisource/`. Their packet paths and hashes are in `inputs.json`. The additional `WIS-chrome-acquisition-20261018-pass32.json` records 21 authorized Chrome source captures and browser provenance.

Pass 32 resolved two marks in WIS 11:8 (source unit extends through verse 9), three in 12:5, and three in 16:19. The kaf note in WIS 11:8 remains ambiguous. The current combined WIS source digest is `0963ef383832b4128e34b574a506308a3959abbd644fd74b82dfa9a14d3f49dc`.

New generated Bible archive: `Shared/dist/bibles/masoretic-delitzsch-6c4a396b692de47a1e934ed6353b317f17a3014dbf019baa02ecfd17f1f122b7.zip`; SHA256 `ee39886aa802c2588a51fabc9f0789f2288f4fc898071e23215f9b4932e535e4`, 3,112,465 bytes. Only WIS chapters 11, 12, 16 and the manifest changed in this pass; 1,333 archive members and nine other editions were unchanged. All three native copies match Shared. All 20 complete daily payloads and the Catholic presentation file were unchanged; nine WIS daily whole-book evidence/digest pins were refreshed.

## Resume at Pass 33: three notes in each unit

Source inspection has started, but **no Pass 33 proposal is approved or applied**, and no Pass 33 source reports or accepted packets have been published. The original reviewers have stopped. Reverify the prospective queue after completing the checkpoint freeze.

Raw captures: `/private/tmp/prosary-hebrew-pass33-20261017/extension-volumeA-*`.

Detailed source-only handoff: `/private/tmp/prosary-hebrew-pass33-20261017/handoff-source-status.markdown`, SHA256 `52daffd9b5bf0bc0c9943e6ce331d4e4924067700bffca4aaa12c293f1ca9baf`.

The 13 files have `.png` filenames but contain the exact original **JPEG/JFIF screenshot bytes**, 1286×931. Preserve those bytes; do not silently re-encode or treat the filename as proof of the format.

| Complete source unit | PSIK volume A viewer / internal page | Printed page | Tentative source finding only |
|---|---|---|---|
| WIS 17:11 | 525 / 540 | תקח (508) | Gimel patah U+05B7 in מוּגת; het hataf-segol U+05B1 and zayin segol U+05B6 in תֶּחזה |
| WIS 18:4 | 526 / 541 | תקט (509) | In בצדק: bet sheva U+05B0, tsadi segol U+05B6, dalet segol U+05B6 |
| WIS 18:23 | 528 / 543 | תקיא (511) | Undecided; obtain larger source views before deciding |

WIS 17:11 has overview, zoom4 left/right, and zoom6 left/right captures. Preserve its complete two-row unit; the next unit starts הלא at the far left of the second row. Literal controls include גם, ויגועו, לב, and המחזה. Previously frozen PSIK captures at viewer 491 (היות) and 499 (כאניה) supply additional compound-vowel controls; pin and inspect them rather than borrowing a conclusion.

WIS 18:4 has overview and four zoom4 views. Its complete unit starts הן בצדק and ends נצח before הם. Useful controls include במים, בחשך, בנים, ויעצבו, נצח, דרך, ידעו, and על־ידם. The proposed בינה control was rejected as insecure; do not use it.

WIS 18:23's three note IDs are `wis-18-23-word12-vav-1-vowel`, `wis-18-23-word12-nun-2-vowel`, and `wis-18-23-word12-ayin-3-vowel`. All share current anchor `ונערְמוּ`, occurrence 1. The physical anchor occupies Unicode scalar span [35,43); target base letters are at scalar offsets 35, 36, and 37. These are Unicode scalars, not UTF-16 code-unit offsets. Its full unit starts ויהי after עם־אבותינו׃ on the row marked כג, continues the following row, and ends אל־החיים׃ on the row marked כד before כי.

For WIS 18:23, take two further reader zoom increments from the last zoom4 state. Capture the right side with the whole target and neighboring ויעמד/ביניהם plus ולא/בכח above; capture the left side with complete נפלו and ויגבר. Reidentify the current page/zoom first. Nun has a possible bar-plus-descender contour, but vav and ayin remain joined enough to require closer views. No mark is certified here yet.

Last observed browser position was viewer 528/internal 543 at zoom4, panned right and down. Browser IDs are ephemeral; rediscover the tab. In this reader, setting the page textbox and pressing Enter changed its displayed value without actually navigating. Previous/Next Page buttons worked. Always verify the actual printed page and visible content after navigation. Viewer/internal/printed numbering differ; do not treat one as another.

## Source and integration requirements

Review the complete source unit, whole target word and glyph, and literal positive and competing marks from the scan. For derived evidence use bounded crops at native resolution or integer nearest-neighbor enlargement, checking bounds before cropping. Do not sharpen, smooth, enhance, reconstruct, or invent pixels. Grammar, OCR, common spelling, Nakdan, parallel verses, or another witness cannot certify a printed point. Preserve visibly unusual source pointing. An ambiguous mark stays omitted with its anchored note and evidence.

Preserve every existing scalar and its combining-mark order, consonants, spaces, punctuation, source pages, printed labels, unit boundaries, witness distinctions, gaps, and all five restored-letter disclosures. Add only the independently certified scalar and retire only its corresponding note. Use exact physical spans; never global anchor replacement. Refresh surviving anchors and occurrence numbers only when proved by the same physical-letter mapping.

Keep combined source units intact, including WIS 11:8/endVerse9 and BEL 1/end2, 3/end4, 17/end18, 23/end24, 31/end32. BEL 9 retains `[לְבֵל]`; BEL 31/end32 ends אֶת־דָּנִיֵאל׃ before ובארץ. ESG 7's translation colophon is a verse-null content block, not a verse. Susanna reviews must keep the correct recension; prior SUS 18 work used the lower one. Source order and Catholic presentation order are separately governed.

Published evidence and reports are immutable. Correct an old report only through a new, hashed supplement stating the exact superseded fields. A source author's own replay does not count as an independent review. Obtain separate source/pixel review and an independent mutation audit before applying. If independent review is unavailable, keep the proposal pending instead of claiming it passed.

Freeze and verify the current 18-file baseline before Pass 33 edits. Prepare all 15 canonical/approval files for comparison: twelve books plus canonical, daily, and presentation approvals. Recompute unit hashes before book digests. Refresh every affected whole-book daily digest/evidence pin, including unavailable entries, while preserving statuses, reasons, selections, and boundaries. Separately verify every surviving note still points to the same physical letter.

Reusable scripts are in the Pass 32 workspace, but they contain pass-specific counts, allowed units, report shapes, and hashes. Adapt deliberately and independently validate them; never run them blindly for Pass 33. In particular, `verify.py` was corrected to compare the WIS 12:5 report's `baselinePins` against the old frozen baseline, not already-mutated live files. WIS 16:19 uses an `evidence` field where other reports use `evidenceFiles`. Distinguish intermediate anchor refresh events from final surviving anchor changes.

## Generation and checks after each approved integration

Run Python tools through `uv run --script`, as required by the repository. Use `UV_CACHE_DIR=/private/tmp/prosary-uv-cache` where needed.

1. `Shared/tools/build-bible-library.py --sync --require-hebrew-supplement`
2. `Shared/tools/build-reading-texts.py --sync`
3. Repeat the Bible command with `--check`, retaining `--sync --require-hebrew-supplement`.
4. Repeat the reading command with `--check --sync`.

Prove regeneration is stable, only approved archive chapters and the manifest changed, other editions are preserved, and Apple/Android/Windows generated copies match. Never hand-edit platform copies.

Shared checks: `test-bible-library.py` (21), `test-hebrew-deuterocanon.py` (22), `test-scripture-source-notes.py` (13), `test-bible-source-structure.py` (12), `test-hebrew-daily-readings.py` (14), and `test-reading-texts.py` (32), plus reading-mapping and scoped whitespace checks. Use current observed counts if tests legitimately change.

Android: from `Android`, `./gradlew testDebugUnitTest --rerun-tasks`; inspect actual XML suite results. Apple: from `iOS`, scheme `Prosary`, destination `platform=macOS`, parallel testing disabled, with the four classes `BibleSourceStructureTests`, `BibleStoreTests`, `ReadingTextStoreTests`, and `ScriptureSourceNoteTests`; use a fresh result bundle and extract its actual summary. Windows runtime results require a Windows host.

End each completed pass with exact counts, evidence and validation paths, unresolved limitations, and the next frozen queue. Report reviewed ambiguities honestly. The immediate next actions are to reconcile the checkpoint's localization discrepancy, freeze the 457-note baseline, then finish PSIK source review of the three Pass 33 units above.

# Hebrew source-note continuation after validated integration Pass 132

This is an active autonomous task handed to a fresh work session at the user's explicit request. The original objective is unfinished. Resume immediately, parallelize independent physical reviews, use larger integration batches, and continue until the available source-review queue is exhausted. Never mistake a session boundary or retained ambiguity for completion.

## Original Step 6, verbatim

**Step 6: Integration Report & Priority Queue**

1. Write `Shared/reports/hebrew-wikisource/source-note-integration-20261017-pass85.json`.
2. Write `Shared/reports/hebrew-wikisource/source-note-priority-20261017-after-pass85.json` (remaining notes will decrease from 247 to 244).
3. Proceed immediately to Pass 86 and continue until exhaustion.

The user subsequently instructed: “this can be parallelized further”; “continue”; “you are allowed to do larger passes”; “create new work sessions when context gets unwieldy”; and explicitly asked that the new context know Step 6. These are continuing authorization, not a request to stop or ask permission.

Original full handoff attachment: `/Users/dk/.codex/attachments/b1a1ccf8-6aac-483a-82a5-59321c7bf0df/Pasted text.txt`.

## Verified current state

- Repository `/Users/dk/Developer/Personal/Prosary`, existing branch `feature/home-card-columns`. Unrelated dirty work predates this task; preserve it. No commit or push requested.
- Both requested Pass 85 JSON reports exist, have been verified, and record 247 starting notes, 3 retired, 244 remaining. Do not reapply Pass 85.
- Published integration reports and queues continue through **Pass 132**. Current count **191 notes: 186 unreadable points and five protected restored-letter disclosures**. There are **145 fresh unreviewed units/145 original unreadable IDs**. Actual next fresh unit is **1MA 16:4**.
- Integration Pass 131 consumed source preparations 131–133; Pass 132 consumed preparations 134–136. From larger batches onward, **preparation IDs differ from published integration pass numbers**. Immutable packet `pass` values are preparation IDs. Do not renumber or mutate hash-bound packets.
- Pass 132 plan SHA256 `5dab74ebcdc2db68c1e6c6daf427dca238e28ac0e8bd1204562934795b9f2610`. All six checks passed, fresh Android 585 tests, Apple full ProsaryTests passed, 113 generated JSON files byte-stable on repeat. No Windows runtime testing available.
- Cumulative independent audit `/private/tmp/prosary-root-cumulative-audit.json`, refreshed at quiescent Pass 132: 56 unique original unreadable IDs retired, 52 certified point insertions, 99 original IDs reviewed, every original scalar/order and all unit metadata preserved, all five protected objects exact, no unpublished canonical application, exhaustion false.
- Monitor `/private/tmp/prosary-offline-continuation/status.json`. Before resuming canonical writes, read the old integrator handoff and verify the old workers are quiescent. Claim one new sole integrator; never allow concurrent canonical writers.

## Non-negotiable source constraints

1. **100% OFFLINE**. Existing saved captures are under `Shared/reports/hebrew-wikisource/source-note-evidence/preemptive-captures/`. No network, browser acquisition or remote research. Existing historical embedded PDF rasters may be reused with honest provenance and exact PDF/source replay. Where old reports pin only a PDF, a fresh direct embedded-byte/full-RGB binding is required; never invent an old raster hash pin.
2. **NEVER call image-viewing tools**, including `view_image`, `view_file`, browser screenshot display or equivalent. They crash this task's media path. Inspect only raw Pillow/NumPy/SciPy arrays, ASCII, connected components, native crops and integer NEAREST enlargements. No OCR, smoothing, sharpening, enhancement, interpolation-derived mark readings, grammatical reconstruction, expected spelling or alternate witnesses.
3. Bind the **complete actual physical source unit**, complete target/control word, own consonant index/occurrence, and actual word/sof-pasuq endpoints. Marginal row numbers do not define units. Shared rows must be clipped at real endpoints. Repeated names produce false numerical registration matches: certify full surrounding consonants before using any point.
4. Keep ambiguous notes unless the own printed glyph supports an exact independently reviewed Unicode mark or exact absence. Literal positive controls require their own pixel certification; current canonical marks cannot label an ambiguous control. No prior verdict or other occurrence supplies a mark.
5. Preserve every existing scalar byte/order, consonant, space, punctuation, unit metadata and **all five protected restoredLetter objects exactly, anchors included**. If an insertion would modify a protected anchor, retain/defer that target.
6. Delete `sourceNotes` entirely when empty. Keep acceptedSourceNoteIds, approval sourceNoteIds, content digest, presentation source digests and applicable daily source pins consistent. Generated native content must come from Shared generators.
7. Use the frozen original Pass 85 baseline and new per-batch unrelated-file baseline. Never compare frozen baseline pins with mutable live data and never weaken an unrelated-file guard.

## Team/work scheduling

The prior session used all four concurrency slots: Root primary/peer, bel_pixels primary/peer, next_pixels primary/peer, and audit_reports sole integrator plus occasional independent research during test waits. Workers are being quiesced for this transfer. Spawn a fresh team; old names in the assignment file are role labels and should be mapped to new workers.

Authoritative locator schedule: `/private/tmp/prosary-offline-continuation/rotating-source-assignments.json`. Its `pass` fields are preparation IDs. Eligibility is `!reviewedInOfflineContinuation && unreadablePointCount > 0`, not the first retained unit in the queue. Skip protected-only units. Integrator live next-eligible preflight always overrides stale assignments. Root/bel/next rotate primary and independent peer; audit was primary for 130 and 139 with bel peer.

Next tasks: finalize/integrate contiguous preparations 137–139; primary 140 (2MA 3:26) is not started, then 141/142 are prepared ahead. Larger batches of 3–10 contiguous units are supported, with final 1–2 permitted. Wait for sensible contiguous batches, but do not wait for unrelated far-ahead work. No independent review may be performed by its own primary author.

### Ready packets at handoff

All below are **unapplied**. Recheck hashes and original canonical text before integration.

- 137, 1MA 16:4, retain Qof: `/private/tmp/pass137-1MA-16-4-pixel-preparation/consensus-preparation.json`, SHA256 `f738e59af20eab21e65468a0a0cb4554e7f6108f63491c8d706a025bef4c7d3d`, 36 crop artifacts. Independent Root peer SHA256 `73c33f3f9b3f0f44182b4e96161e6571241b9af3cd3c6002881fcf4422fa81f7`. Correct own unit is three regions LEFT387/FULL426/RIGHT467, name after נגד. The clearer highresolution name belongs to source8, explicitly excluded. Original own Qof/Nun joined 721px, exact vowel unresolved.
- 138, 1MA 16:8, own Qof Patah: `/private/tmp/pass138-1MA-16-8-pixel-preparation/consensus-preparation.json`, SHA256 `03a5e4a28a4072db025bee4a6eb2bd846c138e6f28872062a51d0a5f67e649fe`, 36 artifacts. Full own word/control and two real shared-row boundaries independently reviewed. Target single detached 243px 28x10 horizontal bar, clean below, distinct from own descender and actual same-unit Qamats/dot controls.
- 139, 2MA 1:10 crossing original180/181, retain He: `/private/tmp/pass139-2MA-1-10-pixel-preparation-v2/consensus-preparation.json`, SHA256 `78aa55da41c31b481620d2d618f564e70d735baa986882332cc7b1f495fdcd8c`, 40 artifacts. Primary SHA256 `853c0507b0706f275b4d4ad7092b2df221a161ab3a6ca6541d7729a3b431f91a`; peer independent-review SHA256 `00bece90f836994b7d36a28708a1264ea2b5fa178b8630b35d27cbb23d666bbf`. Both original-PDF bytes/full RGB replayed by peer. **V1 is superseded**: nearby Mem is one joined 274px vertical compound, not detached nodes. Complete source10 ends וחיים+actualsof684/685 before11מסכנותLEFT.
- 141, 2MA 5:22, third-Lamed Hiriq final consensus: `/private/tmp/pass141-2MA-5-22-pixel-preparation/consensus-preparation.json`, SHA256 `eb5352c080300d411c37107f9d4af6ed5dc06121d13bdc1faa68d07ce23276c2`, 24 artifacts. Root primary SHA256 `f2d396fe4ea90a2bf81c21defc2d558a51e366cd00460128abacc976b33231cf`; next independent-review SHA256 `650e692097c319a781e10b6d4a486b19236481772133a2edc9f44863bd172bc1`. All24 crop artifacts, original embeddedPDF bytes and fullRGB independently replayed. Own compact 117px12x13 dot; literal sameword firstPe112px12x12 dot. Source22 is LEFT710 after21ליבשה+sof1381 then RIGHT750 endingממפקידהו+sof988 before23ואתLEFT957. False paired1519fragments are inside glyph, excluded. Historical companion crop used initial address only, never mark classification. Original197 is honestly newly direct-PDF-bound, no historical raster pin.
- 142, 2MA 7:40, retain Bet: `/private/tmp/pass142-2MA-7-40-pixel-preparation/consensus-preparation.json`, SHA256 `7455a441ce4a8b67d2489d97ca7dd7b3ca9516dc01da86d933abfd5e492dcf8d`, 28 artifacts; peer SHA256 `a4483456e10fbabcb3fcf548fcbd0ec3354d54ef014a048ff954e9f4210f8d37`. New direct-PDF204 binding where historical reports pin PDF only; two actual shared-row regions.

### Primary packets awaiting independent peer

- 145, 2MA 11:25, proposed retain Samekh: `/private/tmp/pass145-2MA-11-25-pixel-preparation/pass145-2MA-11-25-pixel-preparation.json`, SHA256 `48ddcd294a0d36425e963e0663d7bac3f84269b64e28f34c267712bec0644e0b`, 28 artifacts. bel peer **not started**.
- 148, BEL 1:25 lower Theodotion, proposed retain Vav: `/private/tmp/pass148-BEL-1-25-pixel-preparation/pass148-BEL-1-25-pixel-preparation.json`, SHA256 `ac26ca73e3ff3ca239ec284040bc5222687a263a2ff7d7b3645b095f0b0da469`, 32 artifacts. bel peer **not started**. Full source25 LEFT1337 after24לו+sof1616 opensויאמר1535..1598 and endsחי+sof886; next26row1379. Native6lower-right full word[190,1400,620,1630]. Own Vav has left plate plus tiny righttab through4lowerrows; worn stem alternative unresolved. Glyph-only1085match false/excluded.
- 151, ESG 1:13, only early raw read-only registration started, no packet or reading. See next_pixels handoff for pending coordinates. Do not treat tentative localization as certified.

Preparations 140,143,144,146,147 have not started. 147 is BEL1:14 (Root role); 148 is BEL1:25 (next role), not BEL1:14.

## Integration and verification machinery

Use the existing helpers; do not rewrite workflow casually:

- `/private/tmp/prosary-offline-continuation/batch_adapter.py`
- `/private/tmp/prosary-offline-continuation/batch_unit_adapter.py`
- `/private/tmp/prosary-offline-continuation/run_batch.py`
- `/private/tmp/prosary-offline-continuation/daily_guard.py`
- `/private/tmp/prosary-root-batch-audit.py`
- `/private/tmp/prosary-root-cumulative-audit.py`

The old integrator's final handoff supplies exact invocation commands, helper hashes, logs and recovery details: `Shared/reports/hebrew-wikisource/source-note-evidence/20261021-offline-continuation-handoff-after132/handoff-after132.markdown`, SHA256 `7fac8fb80fad6ccde37c405aa6819ad2a48e32eb779b2607f4d3611d9eb5f5bb`. Its sibling `handoff-manifest.json` SHA256 `0e15c39bde185dd1ee25f4518429c79a3ed17625c7ff04165045f1a42214fed3` pins helper/registry snapshots. That handoff's statement about the latest Root cumulative audit is superseded by the refreshed Pass132 result above. bel worker checkpoint `/private/tmp/prosary-offline-continuation/bel-pixels-checkpoint-20261021.json` SHA256 `71223f5b43b69a271007a69f8dc729b16b9e719155c4ba68d8530aff42cb75d0` records quiescence and pending reviews.

A batch freezes the last published state once, simulates contiguous hash-bound preparations on overlays, preflights every source/scalar/crop/daily/protected guard, and prepares one merged plan. **Before every canonical apply, a separate Root reviewer runs**:

`UV_CACHE_DIR=/private/tmp/prosary-pass85-uv /Users/dk/.local/bin/uv run --offline --script /private/tmp/prosary-root-batch-audit.py N`

This writes `/private/tmp/prosary-passN-20261021/root-independent-batch-preflight-review.json`, pinned to exact batch-plan SHA256. Integrator may apply only after the independent review passes. The adapter preserves original unit metadata, all protected objects, exact source notes and accepted IDs, actual priority sequence and unrelated bytes. Existing rejected preflight simulations/plans remain preserved; do not alter frozen baselines.

After the **whole larger batch**, one complete validation cycle is authorized (not one cycle per prepared unit):

1. Bible build and native sync.
2. Readings localize-only and native sync.
3. Hebrew source validator.
4. Asset deduplication/native parity validation.
5. **Fresh** Android `./gradlew --offline testDebugUnitTest --rerun` as used by runner, not UP-TO-DATE.
6. Full macOS Apple `ProsaryTests`.

Then repeat generation for 113-byte stability, run aggregate delivery audit, prove exact live merged units and all retained/no-op units, late source/crop/PDF replay, daily projection audit, and unrelated-file guards. Only then publish the next integration/priority reports and mark preparation IDs consumed in `consumed-preparations.json`. Report explicitly one shared batch validation scope. Never reapply an already applied batch after a test interruption; preserve artifacts and resume checks safely.

Current last-reviewed helper hashes (verify actual hashes before reliance): runner `e394a1755cd2e54c05a70d324c13ba7e0e78e7938d1e8f9d3d886df0899dfafc`; batch adapter `76bdfe9ba7c745dc176d5de308963df7f0395009c15db73aef1bcb418c2a3729`; unit adapter `71981c968239399b36947678728ca0ba9cf1f20dc9648b6ad7f0f65ccfc394d6`.

## Important verification history and pending daily cleanup

- Android85–94 were originally UP-TO-DATE; integration reports honestly annotate that and point to fresh cumulative94 585tests/73suites. Every pass95+ ran fresh Android. Do not claim85–94 fresh individually.
- Apple113/117 first fullsuite hit known MacPrayerStoreLocationTests fixture failure with SQLite vnode unlinked/CocoaError512. Preserved first logs/full xcresult ZIP, one focused retry then unchanged fullsuite passed. No application/test edits or broad cleanup. If identical fixture recurs, preserve evidence and use only bounded retry; do not silently hide failure.
- Frozen original85 had16 stale wholebook daily pins. Only affected-book pins refresh on actualdigestchange; remaining frozen stale pins are honestly reported. Never mutate baselinePins.
- Authorized Pass96 narrow preexisting S3Y daily catchup was reported separately in metadataCorrections (not new96 source points). Historical proof `/private/tmp/prosary-pass96-20261021/historical-daily-drift.json`.
- **Pending authorized ESG3:10 daily catchup**, exact appointment `daily|Esther13:8–11;15–17`, one Pass70 Hiriq plus three prior retired IDs in row/closingText. Historical report SHA256 `9b7086e66a68be6e75e040e349dbbe62ea8e7d59c1c611e50101ed3314b1ca53`; provenance SHA256 `4b1708a31bab6927b2e8f00c1851119f71412183f8a9127b4bcf9ea5d40dc1f4`. Integrator must apply when ESG digest changes or during final cleanup. No other drift authorized. Wisdom7:7–14 appointment unavailable/absent must stay absent.

## Pixel tools and reproducibility

All Python work via uv, never bare Python. Cached offline image runtime:

`UV_CACHE_DIR=/private/tmp/prosary-pass85-uv /Users/dk/.local/bin/uv run --offline --no-project --python /Users/dk/.cache/uv/archive-v0/KexHMObMdBRWyovp/bin/python python SCRIPT.py ARGS`

Standard-library self-contained tools use `uv run --offline --script SCRIPT.py`.

- `/private/tmp/prosary-root-pixels.py PATH --box l t r b --ascii --components --rows --threshold 128`; step decimation is address context only. Native arrays classify marks.
- `/private/tmp/prosary_pixel_packet_util.py`: NativeEvidence exact native/NEAREST4x artifact manifests,64/128/192 metrics, ASCII.
- `/private/tmp/find-highres-any.py DIRECTORY overviewROI SCALES`: numerical context match address only. Repeated words often falsely match. Never infer universal scale or VolumeB page offset.
- `/private/tmp/register-native-to-overview.py SOURCE ROI DEST_IMAGE SCALES`: registration only, never point classification.
- `/private/tmp/find-sof.py`: candidate component pairs, often false inside glyphs; certify full surrounding words and gaps.
- Root packet examples `/private/tmp/prepare-prep141.py`, `/private/tmp/prepare-prep138.py`, `/private/tmp/root-peer137.py`, `/private/tmp/root-peer134.py`.

Detailed chronological checkpoint: `/private/tmp/prosary-pass85-20261021/checkpoints.markdown`. Do not reread all history by default; use current state, team handoffs and exact required artifacts.

## Completion condition and future session handoffs

Continue until all original242 unreadable IDs are either retired from exact independent source evidence or reviewed and explicitly retained as unresolved. Zero notes is not required: five protected objects and physically ambiguous notes remain. Fresh eligibility queue must be zero, deferred physical candidates accounted for, pending ESG cleanup applied/audited, final whole-content/daily/native/crop/unrelated audits and full validation complete, and published state equal live state. Never report exhaustion because remaining count is unchanged.

When context gets unwieldy again, user explicitly authorizes creating another **fresh local Prosary work session** with this objective and a current durable checkpoint. Quiesce all canonical writers, record pending reviews/hashes and exact applied/published state, then create the next session with `create_thread` (not an unnecessary worktree), explicitly carrying Step6 and continue-until-exhaustion. New session should begin automatically; no repeated permission request. Avoid overlapping writers or abandoning pending reviews.

Do not update memory unless separately requested. Relevant memory registry lines978–982 and990 supplied source fidelity/scalar/frozen-baseline safeguards; actual live state is verified above, not sourced from old memory.

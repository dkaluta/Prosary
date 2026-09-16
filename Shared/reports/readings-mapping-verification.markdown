# Readings mapping verification — September 16, 2026

This audit covers the entire shipped offline corpus after the Psalm availability fix. It checks source and numbering provenance; it is not a fresh manual translation or semantic review of every Bible verse.

## Scope and result

- 2,390 distinct citations across 9 editions: **21,510 availability decisions**.
- **17,294 emitted passages and 211,546 verse entries** checked against the hash-pinned source at the emitted book/chapter/verse label; **zero source-fidelity errors**.
- 2,291 citations have text in at least one edition; 99 have none. All missing edition/citation pairs have a recorded reason.
- 108 whole-verse notice keys checked for uniqueness, available text and partial-verse coverage; deterministic generation verifies the complete notice list.
- Exact older edition-boundary reviews retain their verse sequences; no emitted verse comes from an excluded source chapter, repeats a verse label in its passage, or refers to missing source text.
- All source payload hashes, assembled edition digests, numeric inventory/provenance hashes and complete native-copy parity passed. Hebrew retains the documented Divine-Name vowel policy; every Peshitta Hebrew projection and source Syriac partner was checked.

## Coverage by edition

Unavailable counts use the full 2,390-citation universe, including Torah.

| Edition | Daily | Torah | Unavailable | Emitted verse entries | Unique source verses |
| --- | ---: | ---: | ---: | ---: | ---: |
| douay-rheims-1899 | 2,203 | 63 | 124 | 27,945 | 14,822 |
| masoretic-delitzsch | 2,219 | 71 | 100 | 29,117 | 15,437 |
| synodal-1876 | 2,215 | 68 | 107 | 28,606 | 15,153 |
| ang-dating-biblia-1905 | 2,213 | 70 | 107 | 28,891 | 15,269 |
| crampon-1923 | 2,164 | 69 | 157 | 28,162 | 14,888 |
| martini | 1,863 | 58 | 469 | 24,264 | 12,172 |
| kulish-1905 | 2,190 | 49 | 151 | 26,454 | 13,627 |
| jesuit-arabic-1897 | 9 | 0 | 2,381 | 53 | 53 |
| peshitta-1905 | 1,770 | 0 | 620 | 18,054 | 7,302 |

Each of the six complete Psalm editions now supplies all **103/103** bundled Psalm appointments, up from 6/103. Martini, old Jesuit Arabic and Peshitta retain their documented source limits. They are never silently replaced. The Psalm repair changed no non-Psalm text; the subsequent bounded reviews correct two 2 Corinthians endings and four Gospel boundary selections, and disclose the other verified whole-verse expansions. All 13 flagged citation keys have a recorded disposition in the [boundary appendix](readings-boundary-review-2026-09-16.markdown).

## Calendar contexts

One raw citation can occur in multiple calendars; these context counts therefore overlap. Every shared key keeps its complete calendar-context set during resolution.

| Context | Distinct citations | Available in any edition |
| --- | ---: | ---: |
| maronite | 609 | 597 |
| roman | 376 | 367 |
| roman1962 | 407 | 376 |
| syriac | 469 | 453 |
| torah | 71 | 71 |
| ugcc | 728 | 708 |
| ugcc-gregorian | 756 | 727 |

## Unavailable reasons

The machine-readable [coverage report](readings-text-coverage.json) retains every exact citation and reason. Counts below reconcile with it and with the complement of the emitted edition entries.

- **douay-rheims-1899**: alternative or malformed citation: 1; ambiguous appointment numbering: 19; appointment outside source chapter: 16; duplicate or overlapping appointment: 1; missing source versification: 31; source chapter incomplete or numbering differs: 17; unreviewed split or numbering mapping: 39.
- **masoretic-delitzsch**: STEP Standard verse unavailable in source: 1; alternative or malformed citation: 1; ambiguous appointment numbering: 19; appointment outside source chapter: 23; duplicate or overlapping appointment: 1; missing source versification: 31; unreviewed split or numbering mapping: 24.
- **synodal-1876**: STEP Standard verse unavailable in source: 1; alternative or malformed citation: 1; ambiguous appointment numbering: 19; appointment outside source chapter: 21; duplicate or overlapping appointment: 1; missing source versification: 31; source chapter incomplete or numbering differs: 3; unreviewed split or numbering mapping: 30.
- **ang-dating-biblia-1905**: STEP Standard verse unavailable in source: 1; alternative or malformed citation: 1; ambiguous appointment numbering: 19; appointment outside source chapter: 23; duplicate or overlapping appointment: 1; missing source versification: 31; source chapter incomplete or numbering differs: 6; unreviewed split or numbering mapping: 25.
- **crampon-1923**: alternative or malformed citation: 1; ambiguous appointment numbering: 19; appointment outside source chapter: 23; duplicate or overlapping appointment: 1; missing source versification: 31; source chapter excluded by its edition review: 54; source chapter incomplete or numbering differs: 4; unreviewed split or numbering mapping: 24.
- **martini**: STEP Standard verse unavailable in source: 103; alternative or malformed citation: 1; ambiguous appointment numbering: 19; appointment outside source chapter: 16; duplicate or overlapping appointment: 1; edition outside reviewed appointment boundaries: 1; missing source versification: 31; source chapter excluded by its edition review: 21; source chapter incomplete or numbering differs: 237; unreviewed split or numbering mapping: 39.
- **kulish-1905**: STEP Standard verse unavailable in source: 1; alternative or malformed citation: 1; ambiguous appointment numbering: 19; appointment outside source chapter: 23; duplicate or overlapping appointment: 1; missing source versification: 31; source chapter excluded by its edition review: 1; source chapter incomplete or numbering differs: 49; unreviewed split or numbering mapping: 25.
- **jesuit-arabic-1897**: Reference is outside the reviewed Arabic source: 103; alternative or malformed citation: 1; ambiguous appointment numbering: 19; appointment is not a complete reviewed passage unit: 2160; appointment outside source chapter: 16; duplicate or overlapping appointment: 1; edition outside reviewed appointment boundaries: 11; missing source versification: 31; unreviewed split or numbering mapping: 39.
- **peshitta-1905**: STEP Standard verse unavailable in source: 103; alternative or malformed citation: 1; ambiguous appointment numbering: 19; appointment outside source chapter: 23; duplicate or overlapping appointment: 1; edition outside reviewed appointment boundaries: 1; missing source versification: 31; source chapter excluded by its edition review: 66; source chapter incomplete or numbering differs: 350; unreviewed split or numbering mapping: 25.

## Source-numbering evidence

All 103 current Psalm citations are Roman-only. Their source publications contain 642 Hebrew verse markers: 639 consonantal matches at the same pinned Masoretic references, two nonempty partial-verse substrings and one documented Psalm 117:1 spelling variant. The source-numbering manifest preserves exact citation/context scope and source hashes. Hebrew Psalm mapping stays separate from NABRE local verse divisions. Numbered titles and joins use the pinned SIL/STEP relations; the reader always emits the selected edition's original full verse.

The 2,291 available citation keys route through 2,177 legacy agreement checks, 101 new Hebrew-Psalm reviews, 11 exact edition-boundary reviews and two existing NABRE reviews. A review for one calendar never establishes another calendar's convention. Known reviewed keys reject new or mixed unreviewed calendar contexts before any legacy mapping or corpus lookup; the cold-cache integration regression exercises both exact-boundary and source-numbering reviews.

## Reproduction and tests

Run the reusable audit with the hash-pinned Scripture source cache present. It does not call the passage resolver; it independently checks emitted labels/words, availability complements, exact retained reviews and native copies. It writes reference/count/hash metadata only. These source-fidelity checks are separate from the semantic correctness of numerical mappings.

```sh
uv run --script Shared/tools/audit-reading-texts.py --report /tmp/prosary-reading-mapping-audit.json
uv run --script Shared/tools/audit-reading-mappings.py
uv run --script Shared/tools/build-edition-mappings.py --check
uv run --script Shared/tools/build-reading-texts.py --check --sync
```

All 17 reading/numbering suites in the CI reading-validation step passed locally: **260 tests**. This includes cached primary-source checks as well as offline fixtures. Exact commands:

```sh
uv run --script Shared/tools/test-reading-versification.py
uv run --script Shared/tools/test-reading-appointment-reviews.py
uv run --script Shared/tools/test-reading-source-numbering.py
uv run --script Shared/tools/test-reading-step-mapping.py
uv run --script Shared/tools/test-reading-nabre-mapping.py
uv run --script Shared/tools/test-reading-psalm-mapping.py
uv run --script Shared/tools/test-reading-standard-bridge.py
uv run --script Shared/tools/test-nabre-versification.py
uv run --script Shared/tools/test-nabre-versification-fetch.py
uv run --script Shared/tools/test-reading-edition-mapping.py
uv run --script Shared/tools/test-reading-edition-reviews-hebrew.py
uv run --script Shared/tools/test-reading-edition-reviews-western.py
uv run --script Shared/tools/test-reading-edition-reviews-arabic.py
uv run --script Shared/tools/test-delitzsch-numbering.py
uv run --script Shared/tools/test-delitzsch-source.py
uv run --script Shared/tools/test-reading-texts.py
uv run --script Shared/tools/test-peshitta-readings.py
```

This host used temporary uv installation `/private/tmp/prosary-uv/bin/uv`, `UV_CACHE_DIR=/private/tmp/prosary-uv-cache`, and `--python /Users/dk/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`. The parser-fetch suite uses offline fixtures; its logged HTTP 403 is an expected fixture, not a failed live download.

## Artifact identity

| Canonical file | Bytes | SHA-256 |
| --- | ---: | --- |
| readings-texts.json | 45,887,849 | `a289f88839f5d391b793288d82e5d3b5a3d705facf5f57ffd39d496baa6b597d` |
| readings-editions.json | 3,145 | `376ffa2e75ca5a8ffd20b94cc02a36749389ed6f695610dd829b09db4c3f9e47` |

Both files are byte-identical in canonical Shared, Apple, Android and Windows resource directories. The audit does not certify unavailable passages, invent absent text, prove every upstream transcription word against a historical scan, or claim that all remaining ambiguous versification relationships have been reviewed.

## Independent numerical review

The independent, network-free [numeric audit](../tools/audit-reading-mappings.py) passed:

- 217,645 source labels examined: 215,665 successful graph round trips and 1,980 intentionally blocked labels.
- 17,294 emitted passage projections and 2,290 keys with multiple editions compared, including 2,176 legacy agreement checks. The remaining legacy key has only one available edition and no cross-edition comparison.
- 115 exact citation/context reviews checked for scope isolation; 86 exact edition-review passages checked against their retained verse sequences; 614 source-reviewed passage projections checked for complete target coverage and required notices.

The numeric review exposed two actual closing-verse defects: `2 Corinthians 13:3–13` in the two UGCC calendars and `13:5–13` in the Maronite calendar. Primary calendar/lection evidence and pinned STEP rows 27448–27451 establish the complete closing blessing. Exact reviews now retain verse 14 in Tagalog/Peshitta and verse 13 in the other six complete NT editions. They restore the previously unavailable Crampon and Kulish passages. No source text is reconstructed or relabeled.

The original Missale Meum Latin/English `1 Peter 3:8–15` ends within verse 15. The existing complete Bible verses 8–15 stay intact and now carry the whole-verse notice; verse 16 is not added.

The initial graph probe found 98 conservative round-trip widenings across 13 keys. All 13 were subsequently checked against original calendar evidence and pinned target boundaries: eight require explicit complete-verse treatment, including the already corrected 1 Peter notice; five retain their existing selections. There are no unresolved keys from this probe. The [boundary appendix](readings-boundary-review-2026-09-16.markdown) records the full disposition table and 26 primary payload URLs/checksums, including evidence for unchanged cases.

The resulting Gospel corrections retain the house-arrival clause in three Mark 3 appointments and the summons of two disciples in Luke 7:11–18. Shared Mark citations span differing verified calendar cuts, so the selected whole-verse envelope covers both and is disclosed. Acts 3, Ephesians 5 and Mark 16 gain notices while retaining their original verse sequences. No graph companion is appended merely because it is adjacent; Ephesians 1, John 7 and Revelation 12 preserve their proven endpoints.

The separate Philippians probe is fully accounted for in the appendix: 91 false positives from an omitted chapter predicate, and 21 valid chapter-1 pairs already containing both reordered units. No Philippians changes are needed.

These automated correspondence checks and bounded source reviews do not constitute a fresh manual translation review of every Bible verse or certify still-unavailable passages.

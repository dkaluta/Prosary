# Prosary: shared architecture across iOS, Android, and Windows

Prosary ships as three parallel native apps — iOS/macOS (SwiftUI, `../iOS`), Android (Jetpack
Compose, `../Android`), and Windows (WinUI 3, `../Windows`) — in one repository. They share formats
and source assets, not runtime code: each port builds from the copies inside its own tree.
`Shared/` is the canonical home of the cross-platform design, schemas, datasets, bundle source,
tools, fonts, images, and marketing site. A platform change must preserve three-way parity and
update the shared schema or source asset when it changes a shared shape or resource.

## Brand system and web family

The native apps and the three web surfaces share one visual identity: burgundy `#7A1F3D` as the
primary light-mode action color, headline burgundy `#4A0E23`, their accessible pale-rose dark-mode
counterparts, system typography, generous rounded surfaces, and the white rosary cross on a lime
gradient. `Shared/Branding/` owns the canonical web-ready app icon and its size-specific variants.
The landing site (`Shared/website`), prayer repository (`Repository`), and browser authoring app
(`Compose`) run `Shared/tools/sync-web-branding.mjs` before development and production builds, so
their deployment-local artwork and token copies stay generated rather than becoming three more
sources of truth. Shared tokens define not only colors but the 46-pixel single-line control
height, 24-percent scale-relative app-icon mask, control/card/panel radii, border weight, inline
padding, focus geometry, and interaction timing. Keep favicon, Apple touch icon, wordmark
treatment, contrast, reduced motion, responsive touch targets, and those component dimensions
aligned across all three when changing the brand.

## Domain model

Every platform models a saved, user-configurable prayer session the same way, just in its native
idiom (Swift `struct`, Kotlin `data class`, C# `sealed record`):

- **`Prayer`** — a saved configuration (called a "favorite" in older type and directory names):
  `id`, `name`, `kind` (`PrayerKind`), `isDefault` (primary for its devotion — at most one per
  (kind, customDevotionId) at a time), `languageCode`
  (an empty-string/"default" sentinel means "follow the app-level default language setting"),
  nested `RosaryOptions`/`JesusPrayerOptions`, `customDevotionId`, `variantId`, `dayIndex`, and
  schema-driven `customOptions` for generic devotions, plus a list of `PrayerReminder`s.
- **`PrayerKind`** — `Rosary` / `JesusPrayer` / `Custom`, and nothing else. Only the Rosary
  (deeply configurable, options/calendar-driven) and the Jesus Prayer (a repetition counter with
  no steps) warrant their own cases; **every other devotion is `Custom`** — one case covering
  *any number* of generic, bundle-driven devotions (see "Content bundles" below). Adding a
  devotion means shipping a bundle, not adding a case. The five retired per-devotion cases
  (`Angelus`, `StationsOfTheCross`, `FranciscanCrown`, `SevenSorrows`, `DivineMercyChaplet`)
  live on only in persisted favorites from old app versions: their raw values double as the
  matching bundle ids, so iOS/Android remap them to `Custom` + that id **permanently at read
  time** (cloud sync can deliver old rows years later — never a one-shot migration there), while
  Windows (no cloud store; the enum is persisted as its int) runs a one-time
  `PRAGMA user_version`-guarded SQL pass and keeps the retired ordinals reserved forever.
- **`RosaryOptions`** — `mysterySelectionMode` (today's mysteries / a specific fixed set / all 15
  / all 20 / a single mystery), `specificMysteryGroup`, `specificMysteryOrder` (1-based, used only
  for the single-mystery mode), `presenterMode` (collapses each decade's Hail Marys + Glory Be
  onto one combined step — see "Engines" below), toggles for the Apostles' Creed, opening Our
  Father + 3 Hail Marys, an optional Fatima Prayer immediately after those three opening Hail
  Marys, the Fatima Prayer after each decade, eternal-rest placement, the closing Marian antiphon,
  three independent closing intentions (right after the antiphon — for the Pope, the local
  ordinary, and the faithful departed). Each intention opens on its own step, followed by Our
  Father/Hail Mary/Glory Be; the departed group ends with the rest-in-peace versicle/response.
  The groups contain 4/4/5 steps and never repeat the intention as a subtitle. Nullable raw
  Boolean fields `includeClosingPopeIntention`, `includeClosingBishopIntention`, and
  `includeClosingDepartedIntention` resolve as `override ?? includeClosingIntentions`, preserving
  old saved configurations. Engines map these to bundle options `closingPopeIntention`,
  `closingBishopIntention`, and `closingDepartedIntention`; the legacy all-intentions field has
  no editor control. Other options include the St. Michael prayer and the final Sign of
  the Cross, `aramaicSignOfCrossForm` (`formA` / `formB`), and `mysteryImageStyle` (classic paintings
  vs. the `eastern_*` icon set; the engine
  stamps `RosaryStep.imageVariantKey` on every Mystery-carrying step so display resolution —
  `imageVariantKey ?? mystery.imageKey ?? imageOverrideKey` — swaps artwork without touching
  `Mystery.imageKey`, which stays the mystery's identity and translation-lookup key).
- **`JesusPrayerOptions`** / **`JesusPrayerTarget`** — a repetition count (`Count(n)`) or
  `Unbounded` (no target; the user ends the session explicitly).
- **`JesusPrayerProgress`** — the live repetition counter during a session. Immutable
  (Kotlin/C# — `with`/`copy`-based updates) on Android and Windows; a mutable struct on iOS. This
  is a deliberate, known divergence, not a bug.
- **`PrayerReminder`** — `id`, `hour`, `minute`, `isEnabled`. One-off local reminder times, not a
  recurrence rule — see "Reminders" below for why each platform schedules these differently.
- **`LanguageOption`/`LanguageCatalog`** — twelve stored prayer-text codes: `la` (default), `en`,
  `ar`, `he` (Vicariate), `he-x-gamliel` (Mission), `arc`, `el`, `es`, `ru`, `tl`, `fr`, and `it`.
  Public pickers show eleven languages: Hebrew appears once as `עברית`, with a separate
  **Prayer tradition** control for Saint James Vicariate / Mission of St. Gamaliel. These controls
  jointly select the existing `he` / `he-x-gamliel` code, preserving presets, bookmarks and sparse
  overlays without migrating content identities. Aramaic's native label is `ܐܪܡܐܝܬ / ארמית`.
  `aramaicDefaultScript` chooses Hebrew letters (`Hebr`, the initial default) or Syriac
  letters (`Syrc`) when entering an Aramaic prayer. The in-prayer script switch can override
  that choice for the session. Aramaic progress counters and the fruit-of-the-mystery label
  use the selected script.
  `ar`/`he`/`he-x-gamliel`/`arc` are right-to-left, independently of the device's UI language.
  A bundle advertises only the subset it fully supplies; exact community codes can overlay
  their base language without pretending to be complete.
  Apple's system Settings page uses `Settings.bundle` only for a note directing people to
  Prosary's in-app Settings for prayer language, calendars and appearance. It has no custom
  preference controls; Apple manages the system permissions and interface-language controls.
  The note is localized in all seven interface languages. Removing the old duplicate language
  picker does not migrate or reset `defaultLanguageCode`; the app reads the same saved value
  and registers its own Latin fallback. The bundled settings test checks the translated note.


> **Running the Apple test suites:** pass `-parallel-testing-enabled NO`. Both targets share
> global state — `PrayerPackStore` is a singleton and one loader test installs/removes a pack —
> so parallel clones produce failures that have nothing to do with the code under test (and, for
> UI tests, runners that fail to launch at all). Do not pin a test count here; the suites grow
> frequently, and the checked-in test targets are the current inventory.

## Content layer

- **`PrayerKey`** — stable, language-independent identifiers for every fixed prayer text (the
  Sign of the Cross, Our Father, Hail Mary, Glory Be, the Angelus's versicles, etc.).
- **`PrayerTranslations`** — `Get(languageCode, key)`-style lookup, one dictionary per language,
  falling back to Latin then the raw key if a translation is missing.
- **The cross mark `✠`** marks the point in a prayer's text where the sign of the cross is made —
  a reading aid for a gesture, not part of the wording. The Mission of St. Gamaliel's texts
  brought the convention in and use it most: in their Sign of the Cross, their Nicene Creed
  ("with the Father ✠ and the Son is adored") and their Glory Be, always straight after the word
  for *Father*, where the gesture begins. The supplied Aramaic prayers follow that same Mission
  placement in both Hebrew-square and Syriac scripts, including both Sign of the Cross forms.
  `signumCrucis` carries it in **every** language, on the same principle and in the same position.
  Signing at the Glory Be or mid-Creed is the Mission's own use, and stamping ✠ onto the Latin rite's Glory Be would
  be inventing a practice rather than recording one — the same reason their wording is overlaid
  key by key instead of corrected. Each platform's completeness tests pin the mark's presence and
  position so it cannot be dropped by a well-meaning re-typing.
- **`Mystery`/`MysteryCatalog`** — the fixed catalog of all 20 mysteries, grouped into
  `MysteryGroup` (Joyful/Sorrowful/Glorious/Luminous) and ordered within each group. Carries no
  display text itself — title/fruit/description are looked up by `imageKey` via
  `MysteryTranslations`, the same fallback-chain pattern as `PrayerTranslations`.
- The Stations of the Cross, Seven Sorrows, and Franciscan Crown carry **no hardcoded catalogs or
  translation tables anymore** — their step structure lives in each bundle's `devotion.json` and
  their texts in the bundle's `content/<lang>.json` (per-station titles/meditations are composed
  bundle-local keys; the Sorrows'/Magi mystery texts ship in the bundles' `mysteries` maps and
  merge into `MysteryTranslations` at load). `Shared/schema/stations.json`/`seven-sorrows.json`
  document the sequences and point at the bundles.
- **`RosaryStep`** — one prayer "bead" in a fully built session: title, optional subtitle (decade
  context), body text, optional `Mystery`, `isScripture` (true only for the mystery-announcement
  step, whose body is a real quoted Bible verse), `isAntiphon`, `decadeIndex` (0-based, counted
  *globally* across every mystery group in the session — this is what the bead track uses to tell
  decades apart, so it must never reset per group), `hailMaryIndexInDecade` (1–10 for the Rosary/
  Franciscan Crown/Divine Mercy Chaplet, 1–7 for Seven Sorrows), an
  `imageOverrideKey` for steps not tied to a Mystery that still want a specific illustration
  (e.g. "crucifix" for the Sign of the Cross, "our_father" for the Our Father, "madonna_and_child"
  for the antiphon), and an `imageVariantKey` the engine sets on Mystery-carrying steps when the
  favorite's `mysteryImageStyle` selects an alternate artwork set (`"eastern_" + imageKey`);
  display resolution is `imageVariantKey ?? mystery.imageKey ?? imageOverrideKey ??
  "cross_placeholder"` on every platform.

## Engines

One `PrayerEngine` type builds every devotion's steps — `buildSteps(for: Prayer) -> [RosaryStep]`
is the single entry point, dispatching on `Prayer.kind`: the Jesus Prayer returns no steps at all
(every repetition prays the same fixed line, so a single synthesized step plus a
`JesusPrayerProgress` counter is the whole model); everything else — **the Rosary included** — is
built by one fully generic builder from a bundle's `devotion.json` (see "Content bundles" below).
The six per-devotion builders the engine once carried (the Rosary's plus
Angelus/Stations/Franciscan Crown/Seven Sorrows/Divine Mercy) are gone — their step sequences
are reproduced byte-for-byte by the generic builder from bundle data. Each platform's
`CustomDevotionEngineTests` pins the generic sequences (step counts 7/18/17/90/69/63, the Angelus's
Eastertide Regina Caeli swap, the Seven Sorrows' 7-minor decades and non-scripture 4th sorrow,
the Divine Mercy's identical per-decade lines and single reused image, closing repeats without
bead fields), and `RosaryEngineTests` pins the Rosary's — its hardcoded builder was deleted only
after a one-time parity sweep proved the bundle-driven output byte-for-byte identical across the
full option grid, every antiphon, every selection mode/ordinal, and every language (the sweep
lives in git history). The Rosary's genuinely option/calendar-driven pieces stay engine-side
behind the rosary bundle's `decades.source: "mysteryGroups"`: mystery-group resolution
(selection mode + calendar), group-labelled ordinals, the single-mystery mode's true ordinal,
real `Mystery` values on steps, and presenter mode's combined step. `RosaryOptions` remains the
persisted shape and the bespoke editor keeps writing it — the engine maps it onto the bundle's
options.json values (`rosaryOptionValues`). For the Aramaic Sign of the Cross, an explicitly
Aramaic Rosary has a per-favorite `formA` / `formB` choice only while the app default is another
language. Both sourced forms say "and the Son"; they are distinct Syriac recensions, not a
Word/Son substitution. If the app default is Aramaic, the app-wide `aramaicSignOfCrossForm`
setting is the single authority and the saved per-Rosary value is deliberately ignored.

- **Rosary** — the richest: opening (Sign of the Cross, optional Creed, optional opening Our
  Father/3 Hail Marys for Faith/Hope/Charity, then an independently optional Fatima Prayer), one loop per decade across every resolved
  `MysteryGroup` (mystery announcement → Our Father → 10 Hail Marys → Glory Be → optional Fatima
  Prayer → optional per-decade eternal rest), closing (Marian antiphon → optional closing intentions: three intercessions each unfolding
  into Our Father/Hail Mary/Glory Be and closed by "May they rest in peace" → optional St.
  Michael prayer → optional end-of-session eternal rest → optional final Sign of the Cross). The
  single-mystery mode (`mysterySelectionMode == singleMystery`) resolves to the same one-group
  shape as the fixed-set mode, but the per-group loop only builds the one decade at
  `specificMysteryOrder - 1`, keeping the mystery's true ordinal (e.g. "3rd Mystery") for its
  announcement label rather than re-basing it to 1st. Presenter mode
  (`presenterMode == true`) replaces a decade's 10 Hail Mary steps + separate Glory Be step with
  one combined step (title "Hail Mary & Glory Be", both prayers' text in its body); the
  announcement and Our Father steps are unaffected, and Fatima Prayer/eternal rest still follow
  afterward unchanged. That combined step deliberately sets `hailMaryIndexInDecade` to `10`
  (never `nil`) purely so the bead track still renders the traditional 10-bead decade (beads 1–9
  completed, bead 10 current) — do not "simplify" this back to `nil`/omitted, since Windows'
  `BeadLayout` force-unwraps `HailMaryIndexInDecade` in that code path and would crash on null.
- **Generic devotions** (`.custom`) — flat ("steps" type: Angelus, Stations, Via Lucis,
  Trisagion), day-by-day ("days" type: the O Antiphons) or
  decade/bead-structured ("rosary" type: Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet),
  entirely data-driven; the rosary-type builder mirrors the shared decade helper's emission
  (dense global `decadeIndex`, `hailMaryIndexInDecade` on minors only, "ordinal — title"
  subtitles) so bead tracks behave identically to the Rosary's.

Two pieces of logic are shared internally by `PrayerEngine` rather than duplicated per devotion:

- **The per-decade step builder** (announcement → Our Father → N Hail Marys) — used by both the
  Rosary's inner per-group loop and Franciscan Crown/Seven Sorrows' single decade loop, which are
  the same shape underneath (they differ only in catalog, Hail-Marys-per-decade, and which image
  key the Our Father step shows — the Rosary always shows a fixed "our_father" icon there, while
  Franciscan Crown/Seven Sorrows keep showing that decade's own illustration).
- **The Marian antiphon step builder** — used by the Rosary's closing antiphon and by the generic
  builder's `seasonalMarianAntiphon` special step (the Franciscan Crown's fixed seasonal
  antiphon), which stays runtime-composed because it is calendar-dependent.
- **`LiturgicalCalendarService`** — the traditional weekday mystery assignment (Mon/Sat Joyful,
  Tue/Fri Sorrowful, Wed Glorious, Thu Luminous, Sunday follows the liturgical season instead),
  the Meeus/Jones/Butcher Gregorian Easter algorithm, liturgical season (Advent/Christmas/Lent/
  Easter season/Ordinary Time) and its accent color, and the seasonal Marian antiphon.

## Bead progress track

The Rosary flow's bead progress indicator is pure UI-computed presentation state, derived from
the current `RosaryStep` array + index — not something the backend provides. All three platforms
share the exact same model (iOS: `Views/RosaryFlow/BeadModels.swift`; Android:
`ui/rosaryflow/BeadModels.kt`; Windows: `ViewModels/BeadLayout.cs`):

- **`BeadInfo`** — one dot/glyph: `kind` (cross / decade / antiphon), `state` (completed /
  current / upcoming — drives its color). The narrow layout's single-row minor beads are evenly
  spaced — the group-of-5 gap that once marked the 5-bead boundary (`isGroupStart`) was removed
  on every platform: decades that aren't 10 beads long (the Seven Sorrows' 7) split awkwardly
  (5+2) around it.
- **`BeadColumn`** — one mystery group's column of decade beads, for the wide layout's grid: one
  column *per mystery group in the session* (e.g. 3 columns for a 15-mystery session, 4 for a
  20-mystery session), not a flat rows-of-N track spanning every decade regardless of group — a
  long session grows *wider*, not awkwardly taller. `group` is nullable: decades not tied to a
  Rosary `Mystery` at all (Franciscan Crown, Seven Sorrows, and Divine Mercy Chaplet) collapse
  into a single ungrouped (null-group) column rather than being dropped — this
  generalization exists specifically so non-Rosary decade-based devotions get a working bead track
  "for free" from the same model, without needing a `Mystery`/`MysteryGroup` of their own.
- **`BeadLayout.build(steps, currentIndex, hasClosingCross)`** — the full computed layout for the
  current step: `topRows` (major beads wrapped into rows of 5, narrow layout), `openingCross`/
  `groupColumns`/`antiphon`/`closingCross` (wide layout's major-beads column), `bottomBeads`/
  `showBottomBeads` (the current decade's Hail-Mary progress). The bottom-bead count is derived
  from the session's own step data (`max(hailMaryIndexInDecade)` across `steps`, falling back to 10
  if no step has one) rather than hardcoded — 10 for the Rosary/Franciscan Crown/Divine Mercy
  Chaplet, 7 for Seven Sorrows, with no per-devotion branching needed in `BeadLayout` itself.
- The wide layout's minor (bottom) beads additionally split into two 5-tall columns instead of one
  10-tall column when there isn't enough vertical room (a short window) — each platform measures
  its own available height and passes a `hasRoomForSingleMinorColumn`-equivalent flag down (iOS:
  `GeometryReader`; Android: `BoxWithConstraints`; Windows: a `SizeChanged` handler measuring the
  wide layout's actual height, threshold 300).

If you touch the bead track on one platform, check whether the same behavioral change belongs on
the other two — this is one of the most exactly-mirrored pieces of the whole app.

The Rosary flow also exposes **previous mystery** and **next mystery** controls (`⏮` / `⏭`).
They jump to the preceding or following mystery-announcement step without replacing the ordinary
Back/Next bead controls; the unavailable direction is disabled at the first/last mystery.

## Navigation shell

The apps are tabbed (2026-08): **Pray** (the former Home — Rosary card, devotion cards, Jesus
Prayer, "Today"), **Browse** (the prayers.prosary.app catalog), **Categories** (devotions
grouped by manifest `tags`, via a shared per-platform `DevotionDirectory` so nothing
devotion-specific is hardcoded), and **Search** (local + community in one query). Bottom tab
bar on phones, sidebar on desktop: iOS/macOS via `sidebarAdaptable` where available (targets
are iOS 17/macOS 14, so older OSes keep the classic tab control), Android switches
NavigationBar → NavigationRail at 840 dp, Windows wraps the root frame in a NavigationView
whose section switches reset the back stack. Programmatic pushes are single-top on every port:
a rapid repeated click/tap of the same destination must not add an invisible duplicate that
requires an extra Back press. Pray/Categories/Search re-derive their devotion
lists on every appearance, so a bundle installed from Browse/Search/import (or removed in
Settings) shows up
everywhere without a relaunch — the bug that motivated the restructure.

## Prayer flow chrome

Every linear flow shares one presentation chrome per platform (iOS `PrayerStepFlowView`, Android
`PrayerStepFlowScreen`, Windows `PrayerStepFlowControl` plus the bespoke Rosary/generic pages
that mirror it). Two toolbar affordances belong to the flows themselves:

On narrow phones the prayer-flow controls sit in a horizontally scrollable row below the
title, keeping long titles clear of the buttons. Wider layouts retain native toolbar controls.
Their ordering and previous/next section arrows follow the **interface** direction, independently
of the prayer body: in Hebrew/Arabic UI, Next is on the left and Back on the right, with matching
section-jump icons. Actions remain semantically previous/next. Apple retains native glass where
supported, with its existing older-system and visionOS styling.

- **Auto-advance** (all flows) — hands-free praying, from tester feedback: Off / every 3 / 5 /
  10 / 15 seconds, one app-wide setting (`autoAdvanceSeconds` in UserDefaults / SharedPreferences /
  LocalSettings — the `defaultLanguageCode` convention). The countdown restarts on every step
  change, so a manual Back/Next resets it, and it never fires on a flow's last step —
  auto-"Finish" would dismiss the session mid-prayer. The Jesus Prayer's bounded sessions stop
  on their last repetition the same way (Windows `IPrayerStepFlowViewModel.IsLastStep`); an
  unbounded session keeps counting.
- **Language menu** (Rosary and generic-devotion flows) — testers assumed Divine Mercy/Seven Sorrows
  shipped fewer languages than they do, because the app-level setting was the only switch. The
  flow's toolbar globe lists "App setting" plus the bundle manifest's languages,
  rebuilds the session in place *keeping the position* (unlike a variant switch, the sequence is
  identical across languages), and persists the choice to the matching favorite's
  `languageCode` (sentinel = follow the app setting). The Rosary offers the same in-prayer switch;
  changing it keeps the current mystery and bead and records the chosen language in any unfinished
  run bookmark.

Basic Prayers exposes the same language choice in both its list and single-prayer flow. Its
`basicPrayersLanguageCode` preference is shared between those two surfaces on every port,
defaults to the empty "App setting" sentinel, and offers all eleven public prayer languages plus
the separate Hebrew tradition. Selecting
a language refreshes the title, text, direction, and script toggle without changing the app's
default prayer language.

An interrupted Rosary, generic devotion, or Jesus Prayer stores a small device-local bookmark and
offers **Continue** or **Restart** the next time that same prayer is opened. A bookmark contains the
stable run identity/configuration, the zero-based position, the language selected in the flow, and
the local civil date on which it was saved; it never duplicates authored prayer content. Rosary
bookmarks are resumable only on that same local date, while generic devotions and the Jesus Prayer
remain resumable until completion or an explicit restart. Invalid/out-of-range bookmarks and
bookmarks for a changed configuration are discarded. Advancing, going back, jumping mysteries,
or changing language updates the bookmark; Finish clears it. Rosary signatures retain their
legacy fields and append `|closing-v2:1,0,1` (Pope/bishop/departed, comma-separated effective
Boolean flags) when any closing group is enabled or any effective flag differs from the legacy
all-intentions value. This rejects positions shifted by the new intention introductions while
keeping ordinary all-disabled run signatures unchanged.

At Rosary completion, **Pray the Litany** and **Finish** are explicit alternatives. Choosing the
Litany opens the generic `litanyOfLoreto` flow with the resolved Rosary prayer language and
`variantId: "afterRosary"`; it does not start automatically or rewrite a saved Litany configuration.
Every standalone Litany entry, including a saved favorite, forces `standard`, regardless of a
previously saved variant. This built-in devotion hides its manual variant menu: the entry context
selects the ending, while the two canonical variants keep each final collect exclusive to its
own form in every supplied language. The generic custom route therefore accepts optional
`languageCode` and `variantId` session overrides. An old bookmark in another language cannot
replace an explicit incoming language. Apple replaces the outgoing route across main-run-loop
turns so same-depth navigation is not coalesced into a no-op.

## Persistence

Each platform has its own `PresetStore` abstraction (iOS: `Protocols/PresetStore.swift` +
`SwiftDataPresetStore`; Android: `presets/PresetStore.kt` + `persistence/RoomPresetStore.kt`;
Windows: `Persistence/IPresetStore.cs` + `SqlitePresetStore.cs`) with the same contract:

- `all()` / `GetAllAsync()` — every saved configuration.
- `defaultPreset(kind)` / `GetDefaultAsync(kind)` — the primary configuration of that kind, or the
  first configuration of that kind, or none.
- `get(id)` / `GetAsync(id)`.
- `save(prayer)` / `SaveAsync(prayer)` — insert or update by id. If the saved favorite is
  default, every *other favorite of the same devotion* has its default flag cleared — the default
  slot is scoped per **(kind, customDevotionId)**, so two generic devotions never steal each
  other's default, and never a global one.
- `delete(prayer)` / `DeleteAsync(prayer)` — if the deleted favorite was default and others of the
  same (kind, customDevotionId) remain, one is promoted to default.

iOS saved configurations sync through SwiftData + CloudKit (`ModelConfiguration(cloudKitDatabase:
.automatic)` against `iCloud.com.dkaluta.prosary`, falling back to a local-only store when
iCloud is unavailable). Three things must all be present for sync to actually propagate — the
first two were once missing, which looked like "broken sync" (devices only caught up on cold
launch): the `aps-environment` push entitlement (+ its `com.apple.developer.` macOS twin), the
`remote-notification` UIBackgroundModes entry (CloudKit announces remote changes via silent
push), and the CloudKit schema deployed to the **Production** environment in the CloudKit
Console before a TestFlight/App Store build ships (debug builds auto-create it in Development
only — this last step is a console action, not code).

The per-devotion (not global) default/delete scoping is the one behavioral detail worth calling
out explicitly: it's easy to accidentally implement an unscoped version if a platform's store
started out Rosary-only, since "every row" and "every Rosary row" are indistinguishable until a
second devotion is introduced. Each platform's store tests regression-test this, including the
two-generic-devotions case. Legacy rows written before the generic-devotion migration are handled
per platform as described under `PrayerKind` above (iOS: `PresetEntry.resolvedKind`; Android:
`PresetEntity.resolvedKind`; Windows: the `user_version`-guarded SQL pass in
`SqlitePresetStore.InitializeAsync`), and each platform ships `LegacyKindMigration` tests.

### Pray pins and saved configurations

The former Favorites screen is gone. **Pray is a pinned list of devotions**, one row per devotion,
not a flat list of every saved `Prayer`. Pinning (`FavoriteDevotions`) and ordering (`HomeOrder`)
are persisted separately from `PresetStore`, so removing a devotion from Pray never deletes its
saved configuration; Categories and Search remain the discovery surfaces, and the Pray toolbar's
add menu can restore an unpinned devotion. A devotion with an existing saved row is implied-pinned
on first migration so the navigation change does not hide anyone's prayers.

Individual **Basic Prayers** can also be pinned. The historical `favoriteBasicPrayerIds` storage
key now means pins, retaining existing selections; each joins `HomeOrder` as `basic:<prayerId>`
and opens the corresponding single-prayer flow directly in `basicPrayersLanguageCode`. The fixed
Basic Prayers directory row remains below the cards. Pin changes refresh the Home list immediately,
including an already-open Mac window. `BasicPrayersOrder` remains the list's drag order; the old
`favoriteBasicPrayersFirst` preference is ignored and its Settings toggle removed.

The Rosary is the one devotion with a dedicated presets surface: its Pray row opens the default
preset, an ad-hoc "Pray any Rosary" setup, and the remaining named presets, with full editors and
reminder actions. The Jesus Prayer row prays its default saved target or opens setup when none
exists; the Pray add menu can create another named Rosary or Jesus Prayer configuration.

Every generic bundle is still constrained at the UI layer to at most one `Prayer` row, matched by
**bundle id** rather than language. Pinning it from a flow creates that row with the sentinel
`languageCode` (follow the app setting); the flow's language and variant menus, multi-day progress,
and schema-driven options later persist onto the same row. Its compact editor (iOS:
`RemindersOnlyEditorView`; Android: `RemindersOnlyEditorScreen`; Windows:
`RemindersOnlyEditorPage`) exposes bundle `options.json` choices plus reminders. Traditional
times come from `reminderPresetHours`/`reminderPresetFooter` (the Angelus's 6am/noon/6pm bells),
and notification text comes from `reminderBody`, never a hardcoded per-kind table.

## Reminders

Each `PrayerReminder` is a one-off daily time (hour/minute), not a recurrence rule — but the three
platforms' OS-level scheduling APIs differ enough that each implements "daily repeat" differently:

- **iOS**: `UNCalendarNotificationTrigger` with `repeats: true` on the time components alone — a
  true native daily-recurring trigger, the simplest of the three.
- **Android**: `AlarmManager` (exact alarms), with a `BootReceiver` that re-arms all reminders
  after a device reboot (`AlarmManager` alarms don't survive reboot on their own).
- **Windows**: `Windows.UI.Notifications.ScheduledToastNotification` has **no native recurring
  flag at all** — implemented as a rolling window of ~30 pre-scheduled daily instances per
  reminder, topped up on every app launch (scheduled toasts *do* survive reboot on their own, so
  no boot-receiver equivalent is needed there, just periodic re-arming so the window doesn't run
  dry if the app isn't opened for weeks).

All three schedule/cancel through an equivalent `ReminderScheduler` abstraction (iOS:
`Support/ReminderScheduler.swift`; Android: `reminders/ReminderScheduler.kt`; Windows:
`Services/IReminderScheduler.cs` + `WindowsReminderScheduler.cs`) with the same shape:
`requestPermission()`, `schedule(prayer)` (replaces all of that favorite's pending reminders with
its current enabled ones), `removeAll(prayer)`, `rescheduleAll(prayers)` (called at app launch).

## Assets

- **`Fonts/`** — bundled faces for prayer and Scripture typography (see
  `Fonts/ATTRIBUTIONS.markdown` for the complete license notices). Syriac-script Aramaic can use Noto
  Sans Syriac (Default), Noto Sans Syriac Western, or Noto Sans Syriac Eastern, in that order.
  Hebrew prayer text offers Frank Ruhl Libre (`פרנק ריהל` in Hebrew), David Libre, and
  **System sans serif**. The exact Hebrew field labels are `גופן הארמית`, `גופן העברית`, and
  `גופן כתבי הקודש בעברית`.
  Hebrew Scripture offers Shofar, Stam Ashkenaz, Stam Sefarad, and Noto Rashi Hebrew. The two
  Stam fonts are the unmodified Culmus fonts by Yoram Gnat, GPL v2 with their font-embedding
  exception. Amiri/Scheherazade New cover Arabic prayer/Scripture and Cardo covers
  Latin/English Scripture. Latin-script and Cyrillic *ordinary* prayers have independent
  `latinPrayerTypeface` / `cyrillicPrayerTypeface` settings: `default` means **System serif**
  (Apple's New York, Android's system serif, Cambria on Windows), and `sansSerif` means
  **System sans serif**. Greek ordinary prayers retain their existing serif; Scripture retains
  its dedicated face independently of these ordinary-prayer settings.
  Android additionally offers `bundledSansSerif` (**Roboto / Noto**) when the system's actual
  glyph face is not confirmed identical to the bundled one, or that choice is already selected.
  It uses Roboto for Latin/Cyrillic and Noto Sans Hebrew for Hebrew; unknown/older systems show
  the choice conservatively. A one-time migration preserves Android's formerly bundled Hebrew
  `sansSerif` setting as `bundledSansSerif`; **System sans serif** is always the last item.
  All body/acclamation/reading-aid font routing uses the majority of the **visible text's letters**,
  ignoring combining marks, punctuation and numbers. Thus original custom Syriac text obeys
  `syriacTypeface`, while built-in Hebrew-square Aramaic retains Hebrew typography. Changes
  redraw open prayers immediately. Apple delivers UserDefaults typography changes through a
  main-run-loop observable monitor, matching its proven cross-scene language refresh mechanism.
  Hebrew-script **headings** are unpointed at presentation time: the shared display helper removes
  Hebrew cantillation and vowel marks from titles and subtitles only, regardless of whether the
  language is Hebrew or Hebrew-script Aramaic. Canonical content, prayer bodies, acclamations,
  Scripture, and search/selectable text remain byte-for-byte pointed as authored.
- **`Images/`** — the 20 mystery paintings (plus the alternate `eastern_*` icon set — the same
  20 mysteries in an Eastern/illuminated-manuscript style, selected per favorite by
  `RosaryOptions.mysteryImageStyle`; see `Images/CREDITS.markdown` for their AI-generated provenance),
  the 14 Stations (Gebhard Fugel's 1921 Bad Saulgau
  Kreuzweg cycle), the 7 Sorrows (per-scene old masters), the Franciscan Crown's Adoration of the
  Magi (Murillo), the Divine Mercy image (Kazimirowski, 1934) — all public-domain classical art,
  every file an exact 1:1 square — plus ~10 override illustrations used by steps not tied to a
  specific mystery (`crucifix`, `our_father`, `glory_be`, `jesus_portrait`, `eternal_rest`,
  `madonna_and_child`, `st_michael`, `virtue_faith`/`virtue_hope`/`virtue_charity`,
  `christ_pantocrator` — the Sinai icon, the Jesus Prayer's Eastern face) and
  `cross_placeholder` (a simple generated placeholder, not classical art). `Images/CREDITS.markdown`
  records artwork/museum/Commons-file/license per file; each platform's About screen carries the
  user-facing attributions. Prayer artwork ships *inside* the portable bundles and is resolved
  from the pack store's merged image index even when the screen is not itself bundle-driven (the
  Jesus Prayer's `christ_pantocrator` is the important example). It is deliberately **not** copied
  a second time into `Assets.xcassets`, `drawable-nodpi`, or `Assets/Images`. The tiny
  `cross_placeholder` fallback is not declared by a bundle and remains a native resource.

Each platform still builds standalone from physical files in its own tree: generated packs and
datasets are copied from `Shared/dist` / `Shared/data`, and typefaces are copied from
`Shared/Fonts` into the platform font directory. If canonical artwork changes, rebuild and copy
the affected packs; do not recreate a loose native image copy. CI runs
`test-asset-deduplication.py` to prove that every declared pack image matches `Shared/Images`, all
three native pack sets match `Shared/dist` byte-for-byte, and no packed raster has leaked back
into a native resource directory.

## Content bundles (`.prosaryprayer`)

A portable, zip-based content format (UTI `app.prosary.prayer`) for a single devotion's structure,
translated text, artwork, options, alternate forms, multi-day progress, and narrated audio. It is
the production content path for every stepped devotion, including the Rosary; only the counter-
based Jesus Prayer has no bundle. `Shared/content/<devotion>/` is the actual canonical, authored source (not just a
human-synced spec like `Shared/schema/`) — one directory per devotion, each with `manifest.json`,
`content/<lang>.json` per supported language, an optional `catalog.json` for devotions with a
mystery-style catalog, and images pulled from `Shared/Images/` at pack time. `Shared/tools/
make-prosaryprayer.sh` (and its PowerShell twin, `Make-ProsaryPrayer.ps1`) validate a devotion's
source directory and zip it into `Shared/dist/<devotion>.prosaryprayer`.

Self-containment is part of the format: when two portable bundles declare the same artwork key,
each archive keeps its own copy so either file can be imported, exported, or shared by itself.
That intentional cross-pack repetition must not turn into a second native-resource copy. At
runtime the three loaders retain only small JSON metadata and compact archive-source/entry indexes
rather than keeping every encoded image in process memory. Apple and Android open image/audio
entries directly by their ZIP central-directory offsets; the Android JVM-stream initializer keeps
a sequential-scan fallback only for host-side test fixtures. iOS and Android keep a bounded
decoded-image cache, while Windows reopens the chosen entry with .NET's native ZIP reader and
streams it atomically into a disposable per-process `LocalCacheFolder` bridge for WinUI's URI-based
image source. Narrated audio remains file-backed/on-demand as well.

Untrusted imports are bounded before payload allocation. The Apple and Android ZIP indexes accept
only one-disk, non-ZIP64 stored/raw-DEFLATE archives, verify the EOCD and central/local ranges,
supported flags, UTF-8 safe names, duplicate names, local/central name and size agreement, data
descriptors, non-overlapping entry regions, and every extracted entry's size plus CRC. Their
structural ceilings are 4,096 entries, a 16 MiB central directory, 256 MiB per entry, and 512 MiB
expanded per bundle; Apple file-picker/repository reads and Android file-picker/HTTP reads reject
an archive over 576 MiB while the source is still file- or stream-backed (the extra 64 MiB leaves
room for headers around the full expanded budget). Apple and Android then
apply purpose-specific ceilings before use: 8 MiB for one runtime JSON file, 32 MiB for all runtime
JSON together, 64 MiB for one image, and 256 MiB for one recording. These are safety limits, not
targets for authored content. Windows uses its native `System.IO.Compression` reader with a 512
MiB raw-archive ceiling and the same 4,096-entry, 8 MiB control-file, 32 MiB aggregate-control, 64
MiB image, and 256 MiB recording ceilings. Its picker and repository readers reject known lengths
before allocation and spool unknown-length sources through a bounded temporary file before one
exact allocation. Image/audio payloads are copied through bounded streams into sibling temporary
files before an atomic cache publish.

Android's direct reader depends on `androidResources.noCompress += "prosaryprayer"`: bundletool
records that rule as an uncompressed glob in `BundleConfig.pb`, so each generated/install APK stores
the packs and `AssetManager.openFd` can expose their seekable file region (including its non-zero
offset inside the APK). The upload AAB is a transport ZIP and may still show those entries as
DEFLATE-compressed; the generated APK and bundle configuration are the authoritative checks.

**The "main" prayers can be shared through native tables or sourced pack overrides.** Sign of the Cross, Apostles' Creed, Our
Father, Hail Mary, and Glory Be (`signumCrucis`, `symbolumApostolorum`, `paterNoster`, `aveMaria`,
`gloriaPatri`) have native base tables in each platform. A bundle can omit a main prayer when the
shared selected-language table supplies it, or add a sourced translation in canonical content;
the native loaders merge those additions into the shared table. Devotion steps keep referencing
the same `PrayerKey`. Each manifest's `mainPrayerKeysOmitted` array documents shared references,
not proof that the prayer exists in every language. The coverage audit checks the actual text.

The **Rosary** keeps a dedicated `PrayerKind` and typed `RosaryOptions`, but its step structure is
not hardcoded: the shared `PrayerEngine` builds it from the Rosary bundle's `devotion.json` and
maps the typed options onto `options.json`. Its calendar-driven mystery-group resolution remains
engine-side behind `decades.source: "mysteryGroups"`. The manifest's `builtinKind: "rosary"`
keeps the bundle out of generic-devotion discovery so it is not listed twice. Its sourced
Aramaic table carries
both `signumCrucis` (form A) and `signumCrucisFormB` (form B), two sourced variants that both
say "and the Son". The Rosary
definition conditionally places exactly one at each cross position. Other languages resolve
`signumCrucisFormB` to their ordinary Sign of the Cross, so this Aramaic-only distinction never
changes their wording.

At runtime, each platform's `PrayerPackLoader` also merges every loaded bundle's content into the existing
`PrayerTranslations`/`MysteryTranslations` tables (bundle wins on collision) rather than
replacing them — necessary because `PrayerKey`/mystery `imageKey` entries are a shared pool
across devotions (e.g. `our_father` is used by the Rosary and several bundle devotions alike), so
a bundle can only ever *add to* the hardcoded tables, never fully replace them. The rosary pack
loads **first** so its shared mystery texts/images are the base other bundles build on; the
Franciscan Crown deliberately ships *only* its own 4th Joy (`franciscan_04_adoration_of_the_magi`)
and lets the six shared Joys resolve cross-bundle from the rosary pack — duplicating them would
override the Rosary's own content. `hasCatalog` in a manifest strictly means "has a
`catalog.json` authoring file" (the Rosary); mysteries maps merge unconditionally, which is how
rosary-type bundles ship per-decade texts without any catalog.json. Only the Jesus Prayer has no
bundle at all (it has no per-step content to carry).

Mystery entries in `content/<language>.json` are **field-wise overrides**:
`mysteries: {imageKey: {title?, fruit?, description?, transliteratedDescription?}}`. Title, fruit,
and description each resolve independently through exact language → base language → the user's
fallback order → Latin, with a pack override ahead of the hardcoded table at each stop. This is
load-bearing for rite-specific Scripture: an Aramaic Rosary can use the Peshitta passage and its
own source-native citation while inheriting a Hebrew mystery name and fruit, rather than carrying
the Vulgate verse merely because that is where its Latin title lives. A
`transliteratedDescription` must sit beside `description` in the same override and follows that
description as one provenance pair; later-loaded bundles merge only the fields they actually
supply. The engine appends the same resolved fruit to both script renderings.

### Community language overlays

A bundle's `manifest.languages` declares the languages the validator holds to completeness.
Picker choices normally follow that list, with Hebrew presented once and its Vicariate (`he`)
and Mission (`he-x-gamliel`) traditions selected separately. Any `content/<code>.json` whose
code is not in the manifest is an **overlay**:
the loaders read it, and `resolveBodyText` tries the requested wording and then the user's
language precedence, with generic language content beside the first matching tradition. A community use can therefore
ship its own wording for selected prayers and headings without pretending to translate the
whole devotion; the packer needs no extra manifest field because it already copies every
content file it finds.
The fallback-order editor lists Mission Hebrew and Vicariate Hebrew separately. Their stored
codes remain `he-x-gamliel` and `he`, so an order such as Mission → Aramaic → Vicariate survives
save/reopen. Newly available languages are inserted before an existing terminal Latin fallback,
retaining the user's other ordering.

Generic Hebrew, including unmarked `content/he.json` from repository packs, shares the higher
Hebrew priority: it is tried immediately after the first Hebrew tradition, exactly once. Thus
Mission → Aramaic → Vicariate probes Mission wording → generic Hebrew → Aramaic → Vicariate
wording. A prayer with no Mission or generic Hebrew text reaches Aramaic before Vicariate.
`$prayerTraditionByKey: {"prayerKey": "vicariate"}` inside `content/he.json` marks specific
Vicariate wording; unmarked keys and Hebrew mystery/Scripture fields stay generic. The loader
separates marked text and its matching reading aid into an internal `he-x-vicariate` bucket
before merging overrides. That code is never saved or shown in language pickers. Existing
built-in prayer wording is annotated without rewriting it; generic headings, counters and
Scripture stay unmarked. Native Hebrew fixed prayers are Vicariate-specific except the shared
`decadeOrdinalFormat`, `repetitionCounterConnector` and `fructusMysteriiLabel` vocabulary.
Compose retains title/body provenance independently when importing, saving a project and
repacking it, even though the generated prayer keys change. It emits the same per-key metadata
so editing a sourced Vicariate prayer cannot silently turn it into generic repository Hebrew.

Loaded overlays merge into the same `PrayerTranslations` lookup used by built-in text, so
Mission, generic Hebrew and Vicariate wording each retain their own place in the configured precedence.
The Mission of St. Gamaliel's Hebrew is the first user of both halves; in that language the
Nicene Creed occupies the Apostles' Creed key, which is how the Mission's Rosary uses its own
Creed without creating a second prayer-flow shape. Its Our Father deliberately displays the
heading `תפילת האדון` (Lord's Prayer), matching the Aramaic title, even when the body falls back
through another bundle's Hebrew overlay.

### Generic (bundle-driven) devotions

Every devotion except the Rosary and the Jesus Prayer is a **generic devotion**: Angelus,
Stations of the Cross, Via Lucis, Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet,
Trisagion, the O Antiphons, and the Litany of Loreto. A
generic devotion needs *no* hardcoded `PrayerKind` case, engine builder, flow view, or view-model
of its own — its entire step sequence and per-step text are data-driven from its bundle:

- **`PrayerKind.custom`** is the one case covering *every* generic devotion.
  `Prayer.customDevotionId` holds the bundle id (e.g. `"angelus"`) when `kind == custom`. Bundle
  ids are exactly the old per-devotion `PrayerKind` raw values, which is what makes the legacy
  favorites migration a pure string remap.
- **`devotion.json`** (replaces the earlier `steps.json`; no legacy support — we own every
  bundle) is the complete structural description, one of two types:
  - `{"type": "steps"}` — a flat, fixed list: `steps: [Entry…]` plus an optional
    `eastertideSteps: [Entry…]` whole-sequence swap (the Angelus → Regina Caeli substitution,
    resolved via the platform liturgical calendar's `isEasterSeasonToday`). A steps-type
    devotion may instead declare **`variants`** — named alternate step-sets
    (`[{id, name, nameByLanguage?, steps, eastertideSteps?}]`, mutually exclusive with
    top-level `steps`; the first variant is the default) — e.g. the Stations of the Cross's
    traditional (Liguori) vs. scriptural (St. John Paul II) forms. `Prayer.variantId` (nil =
    default) selects one; the flow screens show a toolbar variant menu when a bundle declares
    more than one, rebuilding the session on switch and persisting the choice to the matching
    favorite.
  - A **rosary-type devotion may declare `variants`** too (2026-08-07), the same idea the steps
    type has carried since the Stations grew a scriptural form: `[{id, name, nameByLanguage?,
    opening, decades, closing, hasClosingCross?}]`, mutually exclusive with the top-level four,
    first is the default, selected by the same `Prayer.variantId`. A chaplet's recensions differ
    in their opening prayers, their per-decade invocations and their close while praying the same
    mysteries — the Seven Sorrows is the case that asked for it. Every bead-track invariant is
    checked **per form**: a second form missing its opening Sign of the Cross would crash the
    bead track exactly as a single-form devotion would, so `validate_rosary_form` runs once per
    variant. `hasClosingCross` is likewise per form, and each platform's flow reads it through
    `resolvedRosary(variantId)` rather than off the bundle — one recension can end with the cross
    where another does not.
  - **Per-language default forms** (2026-08-08): any variant (either type) may declare
    `defaultForLanguages: ["he-x-gamliel", …]` — exact prayer-language codes, rites included,
    whose sessions open in that variant when `Prayer.variantId` is nil. The Mission of St.
    Gamaliel prays the Trisagion in its Syriac form, so their rite gets it without touching the
    variant menu. Exact match only (a rite is a deliberate choice; its base language keeps the
    ordinary default), no two variants may claim the same code, and an explicit `variantId`
    always wins — each platform routes every nil-variant lookup (engine, variant-menu checkmark,
    persistence baseline, `hasClosingCross`, audio-track matching) through one
    `effectiveVariantId(variantId, languageCode)` resolver. For everyone without a rite claim,
    "first declared is the default" carries the canonical tradition order **latin → byzantine →
    west syriac → armenian → alexandrian → east syriac**: the validator rejects tradition-named
    variant ids declared out of that order, so the default is always the earliest tradition the
    bundle ships — the Latin form once one exists (what the Vicariate's Hebrew should open in),
    the Byzantine until then. Ids that name no tradition (`traditional`, `scriptural`, …) stay
    in author order.
  - `{"type": "rosary"}` — decade/bead-structured: `opening: [Entry…]` (entry 0 MUST be the Sign
    of the Cross — a bead-track invariant), `decades` (`ordinalNoun` "Joy"/"Sorrow"/"Decade";
    `announceMystery`; either inline `entries: [{imageKey, isScripture? = true}]` (Franciscan
    Crown/Seven Sorrows), *or* `count` + `fixedImageKey` (Divine Mercy), *or*
    `source: "mysteryGroups"` (the Rosary — the decade catalog comes from the engine's
    mystery-group machinery instead of bundle data); `majorStep`/`minorStep`
    `{title | titleKey, bodyKey, imageKey?}` (the optional `imageKey` is the Rosary's fixed Our
    Father icon between mystery-specific images); `minorCount`; optional `preAnnouncement: [Entry…]` emitted
    *before* each decade's announcement (carrying the decade's subtitle but no `decadeIndex` —
    they are not beads; the Servite chaplet asks Our Lady to recall her Son's sorrows before each
    one is named, which `postMinor` could not express because it fires after a decade rather than
    before one), optional `postMinor: [Entry…]` emitted
    after each decade's minors carrying the decade's subtitle/index (the Rosary's Glory Be /
    Fatima Prayer / per-decade eternal rest, each gated with an `"if"`); optional
    `presenter: {combinedTitle | combinedTitleKey, bodyKeys}` — when the gating `presenterMode` option is on, the
    minors collapse into one combined step with `hailMaryIndexInDecade = minorCount` so the
    bead track still renders a full decade), `closing: [Entry…]`, and `hasClosingCross` (when
    true the closing cross must be the literal last step — another bead-track invariant).
    Announcement steps pull title/body from the merged mystery tables by the entry's
    `imageKey`. A closing entry may be `{"kind": "marianAntiphon", "optionKey": …}` (the
    Rosary): the named choice option's value selects the antiphon, with "seasonal" resolved by
    the liturgical calendar and "none" dropping the step.
  - An `Entry` is `{title | titleKey, subtitle? | subtitleKey?, bodyKey?, acclamationKey?,
    imageKey?, repeat?, isScripture?}` — `title` is a literal English UI label (the app-wide convention), `titleKey`
    the alternative for devotions whose step titles are themselves translated content (the
    Stations), and `subtitleKey` likewise for translated subtitles (the Rosary's opening Hail
    Marys "for Faith/Hope/Charity");
    `repeat: n` unrolls into n copies titled "Title (h of n)", deliberately without bead fields;
    `isScripture: true` marks a body that is a quoted Bible passage so it renders in the
    scripture typeface, same as the Rosary's mystery announcements (the scriptural Stations'
    fourteen station steps); `isScriptureByLanguage: {lang: bool}` overrides it per session
    language, for bodies that are scripture in some languages but composed prose in others
    (the traditional Stations: Liguori meditations in la/en, scripture in ar/he/ru/tl);
    `acclamationKey` resolves like `bodyKey` and renders above the body in the regular prayer
    typeface — the Stations'/Via Lucis' versicle-response is a prayer, not part of the reading,
    so a scripture body's typeface never swallows it. A closing entry may
    instead be `{"kind": "seasonalMarianAntiphon"}` (the Franciscan Crown), which stays
    runtime-composed by the engine's shared antiphon builder because it is calendar-dependent.
  - **Composed bodies, no composition grammar**: every step has exactly one `bodyKey`.
    Versicle/response/collect compositions are pre-composed per language into bundle-local keys
    at authoring time, byte-for-byte as the old engines emitted them (`"V\n**R**"`
    bold-response markdown) — e.g. `angelusAnnunciationBody`, `station01Body`/`station01Title`,
    `sevenSorrowsClosingBody`.
- **`manifest.json`** fields for a generic devotion: `id` is the portable identifier and persisted
  filename, restricted to `[A-Za-z0-9][A-Za-z0-9._-]*` so an imported pack is always one safe path
  component (dotted repository ids remain valid); optional `builtinKind` ("rosary") marks a
  bundle whose devotion.json backs a dedicated `PrayerKind` rather than a generic `.custom`
  devotion — its definition loads, but the bundle stays out of `customDevotionIds()` so
  Pray/Categories/Search don't list it twice; `accentColorHex` + optional
  `accentColorDarkHex` (light/dark pair), `iconSystemName` (an SF Symbol name; mapped to the
  nearest Material icon on Android and Segoe Fluent Icons glyph on Windows via a small fixed
  per-platform table), `displayNameByLanguage` (preserves e.g. the Hebrew devotion names — resolved
  **prayer-language-first** as of 2026-08-08: the exact resolved default prayer code, rites
  included, then its base, then the UI language, then `displayName`. A devotion's name is part
  of the prayer, the same principle that moved step headings into the prayed language; it is
  also the only way a key like `"he-x-gamliel": "קדישת"` can ever be read, since UI-language
  lookups truncate to two characters),
  `reminderBody` (per-language notification body), optional `reminderPresetHours` +
  `reminderPresetFooter` (the Angelus's traditional bell times), and optional **`tags`**
  (lowercase category labels, e.g. "marian" — Compose writes them, the repository uses them
  as submission defaults, every loader exposes them, Categories groups by them, and Search
  matches them).
- **`options.json`** (optional bundle file): user-configurable settings, declared separately
  from the structure the same way catalog.json is —
  `{"options": [{key, kind: "toggle" | "choice", name, nameByLanguage?, default,
  cases?: [{id, name, nameByLanguage?}]}]}` (a toggle's `default` is a JSON boolean; a
  choice's is a case id). Any devotion.json entry may carry `"if": "key"` / `"!key"` /
  `"key=caseId"` — the engines evaluate it against the bundle's defaults overlaid with the
  favorite's stored `Prayer.customOptions` (string-encoded: "true"/"false" or a case id;
  overrides only) and drop the entry when it fails. The generic-devotion editor (the former
  reminders-only editor) renders one schema-driven toggle/choice row per option above the
  reminders section. First real use: the Franciscan Crown's optional closing devotions (the
  72-completion Hail Marys, the Our Father for the Pope's intentions), both defaulting on so
  the traditional sequence is unchanged out of the box. The validator checks the declarations
  and that every `if` references a declared option/case.
- **Multi-day devotions** — `{"type": "days"}`: one step list per day
  (`days: [{name, nameByLanguage?, period?, steps: [Entry…]}]` — `period` carries the
  Montfort-style grouping labels), plus optional shared `opening`/`closing` prayed every day.
  Novenas are 9 entries; the de Montfort Total Consecration is 33 (12 preliminary days + three
  weeks + the consecration day). The schema, decoders, engines (shared opening + the day's
  steps + shared closing, with a clamped `dayIndex`), and validator all ship — and so does
  **per-favorite day progress**: `Prayer.dayIndex` (nullable Int on all three stores; null =
  day 1; SwiftData/sqlite-net auto-add the column, Room migration 5→6 adds it explicitly)
  feeds the engine, the flow's calendar toolbar menu jumps to any day (period-prefixed,
  localized names), switching persists to the matching favorite, and finishing a day's
  session advances the favorite to the next day — clamped to the last, so a completed
  devotion re-prays its final day and tomorrow always opens where the novena left off.

  A **series** (`dayProgression: "series"`, the default — the alternative is `"free"`, a set of
  days to pick from with nothing to be behind on) additionally gets a tracked **run**:
  `MultiDayRun` records the start date and *which* days were prayed, so the day the calendar
  calls for and the day that was missed stay separate answers. Opening the devotion resumes,
  offers the three-way choice (the missed day / today's day / start over), or reports the run
  complete; praying twice in one day shows that same day again rather than eating tomorrow's.
  A series may also declare `suggestedStart` ("MM-DD"), `suggestedReminderTime` ("HH:mm") and
  `suggestedNext` (another devotion's id, silently skipped when that bundle is not installed) —
  all advisory, which is what lets a pinned novena announce itself before its first day.
  The **O Antiphons** (7 days, 17–23 December) is the shipped bundle this all runs against.
  Hours are a different beast and get their own type rather than being forced into this
  shape — see below.
- **The Hours** — `{"type": "hours"}`: several offices a day, each of whose contents the
  liturgical calendar chooses. A days-type devotion advances by a counter; an office does not,
  which is the whole reason this is a separate type. **Format and validator only (2026-08-06):
  no decoders, engines, Compose support or bundles ship yet** — this is the shape settled so
  that authoring one is possible, not a feature.

  A bundle declares the *skeleton* of each hour once and leaves the parts that vary as holes:

  - **`hours: [{id, name, nameByLanguage?, suggestedTime?, steps: [Entry…]}]`** — one per office
    (Vespers, Compline, the Office of Readings). Each is structurally a steps-type sequence, so
    `Entry` is reused unchanged. `id` is the reserved handle for which office a favorite opens
    on (a future `Prayer.hourId`, exactly as `Prayer.dayIndex` names a day) and for a per-hour
    reminder; `suggestedTime` ("HH:mm") is the hour's traditional time, advisory the same way a
    series' `suggestedReminderTime` is — which is how the Angelus's `reminderPresetHours`
    generalizes to an office of the day.
  - **Shared `opening`/`closing`** are prayed around every hour, the same pair days-type has —
    the "O God, come to my assistance" that opens each one, and a closing that may be the
    existing `{"kind": "seasonalMarianAntiphon"}` entry, which is precisely what ends Compline.
  - **A slot** — `{"kind": "proper", "slot": "psalmody", "default"?: [Entry…]}` — is the one
    entry that is not itself a step: a named hole the calendar fills. `default` is how an author
    says "unless the calendar says otherwise, this".
  - **`propers: [{when?, hour?, slot, steps: [Entry…]}]`** is the date→content-key resolution
    layer, expressed as data rather than code. Each entry files a piece of content under the days
    it belongs to. `when` constrains any of seven facets, each a non-empty array of allowed
    values — `date` ("MM-DD", the sanctoral), `rank`, `season`, `week` (of the season),
    `weekday`, `psalterWeek` (1–4), `readingYear` (1–2). Every declared facet must match, any
    listed value within a facet matches, an omitted facet is unconstrained, and absent/`{}` is
    the catch-all for that slot.

  **Precedence is a fixed facet order, not a count**: `date`, `rank`, `season`, `week`,
  `weekday`, `psalterWeek`, `readingYear`, compared lexicographically — a proper constraining an
  earlier facet beats one that does not, however many facets either constrains. That is the
  Church's own hierarchy (proper of saints over proper of season over the running psalter);
  counting conditions instead would let "Advent, week 3, Sunday" outrank Christmas Day, which is
  exactly backwards. Ties go to the earlier declaration, and the validator rejects two propers
  for one slot with an identical selector so declaration order never silently decides an office.

  The validator earns the word "robust" by refusing the ways this shape goes wrong: a slot no
  proper can fill and with no `default` (it would vanish from the office silently, every day of
  the year), a proper for a slot no hour asks for, a proper naming an hour that lacks its slot,
  an unknown facet or an out-of-range value, duplicate hour ids, and indistinguishable propers.
  `Shared/tools/fixtures/hours-format-proof/` is the bundle those rules are exercised against —
  two hours, a shared ordinary, the running psalter, a proper of the season, a saint's day, a
  rank override, the two-year reading cycle, a slot with its own default, and an option-gated
  step — and `Shared/tools/test-validate-devotion.py` runs it plus nineteen deliberate breakages
  plus every shipped bundle. Any key beginning with `$` is an author's note anywhere in a
  devotion.json, so a proper can say why it exists without the format growing a field for prose.

  **What implementing it still needs**, none of which is format work:
  `LiturgicalCalendarProviding` must answer week-of-season, `psalterWeek`, `rank` and
  `readingYear` for a date. Only week-of-season is genuinely new computation — `psalterWeek` is
  arithmetic on it, `rank` is a lookup in the `feasts.json` the Pray tab already ships (whose
  `rank` values this vocabulary deliberately mirrors), and `readingYear` alternates with the
  liturgical year. Then decoders, an engine that walks the precedence list per slot, a way to
  choose an hour, and — the part the format cannot help with — texts. The Church's modern
  Liturgy of the Hours (ICEL, the Grail psalms) is under copyright; a shippable bundle wants
  public-domain sources, and **Compline is the sane first office**: a seven-day cycle, a fixed
  ordinary, and a closing Marian antiphon the engine already builds.
- **Audio** — a bundle may ship narrated recordings of its devotion. An optional
  **`audio.json`** (declared separately from the structure, the same way catalog.json/options.json
  are) lists tracks: `{"tracks": [{id, language, file, variantId?, name?, nameByLanguage?,
  chapters: [{start, title | titleKey, stepIndex?}]}]}` — `id` unique within the bundle (what a
  persisted playback position keys against); `language` one of the manifest's languages (a
  recording is in one language); `file` a bundle-relative path that must live under `audio/` and
  end in `.opus`; `variantId` names the steps-type variant the recording follows (a traditional
  vs. scriptural Stations recording differ); `name`/`nameByLanguage` follow the variant-naming
  convention (absent = platforms label by language). **Chapters** are the seek points: `start` in
  seconds (first chapter at 0, strictly increasing), `title` XOR `titleKey` per the step-entry
  convention (`titleKey` resolves through the track language's ordinary content chain), and an
  optional advisory `stepIndex` into the built default-options step sequence — advisory because
  the built sequence is option/calendar-dependent, so the playback UI treats it as a hint
  for step-syncing, never an invariant. Chapters live in `audio.json`, not in Ogg chapter
  comments, because none of the three platforms' media stacks surface embedded Ogg chapters —
  JSON keeps them parseable by the same loaders that already read the bundle.
  **The format is Ogg Opus** (RFC 7845, `.opus`): the best speech codec at low bitrates,
  royalty-free, and seekable; recordings should be mono 48 kHz voice at ~24–32 kbps VBR
  (`opusenc --bitrate 32 --downmix-mono in.wav out.opus`). Audio sources are devotion-specific
  (unlike the shared `Shared/Images/` pool), so they live in the devotion's own source directory
  (`Shared/content/<devotion>/audio/*.opus`); both packers stage `audio.json` plus exactly the
  declared files, and the validator checks the declarations (unique ids, known
  language/variant, chapter monotonicity, titleKey resolution) and each file's Ogg Opus
  signature. Each platform's `PrayerPackLoader` parses `audio.json` into
  `DevotionAudioTrack`/`DevotionAudioChapter` and exposes `audioTracks(bundleId)` +
  `audioData(bundleId, file)` — track *metadata* loads eagerly like everything else, but audio
  *bytes* are re-read from the pack on demand (a full recording dwarfs every other bundle asset;
  never retain it in the process-wide metadata store). **Playback** ships on
  all three platforms: a per-platform player plus the same compact transport bar above the
  prayer flow's footer (chapter skip / play-pause / seekable timeline / current chapter title),
  shown when the session's devotion+language(+variant) has a matching track — the track's
  language must equal the session's resolved code and its variantId (nil = the bundle's
  single/default form) must match the session's; the first declared match wins (audio.json
  order is the author's preference order). Track bytes are extracted once to a per-platform
  cache (iOS `Caches/PrayerAudio/<bundleId>/`, Android `cacheDir/PrayerAudio/`, Windows
  `LocalCacheFolder\PrayerAudio\`) and handed to the OS player. Cache filenames include the
  ZIP entry's CRC and uncompressed size from the already-loaded central-directory index, so
  replacing a bundle under the same bundle/track ids cannot replay an old extraction (or an old
  Apple CAF wrapper); obsolete revisions are pruned opportunistically. Apple and Android stream
  both stored and raw-DEFLATE audio members through fixed-size buffers into a sibling temporary
  file, verify size and CRC, flush it, and only then atomically publish the cache file; playback
  never needs a whole-recording extraction buffer. Android's stock `MediaPlayer`
  and Windows' `Windows.Media.Playback.MediaPlayer` demux Ogg Opus natively (Windows through
  the usually-preinstalled Web Media Extensions codecs — `MediaFailed` degrades to the
  no-audio experience rather than a dead bar), while on Apple platforms
  `AudioPlaybackController` *always* plays through `OggOpusCAF` — a lossless Ogg→CAF
  repackager (packets copied as-is into desc/pakt/data chunks, priming frames from OpusHead's
  pre-skip) whose output is cached beside the extract. Never the `.opus` directly: the
  deployment floor (iOS 17/macOS 14) can't demux bare Ogg at all, and where newer OSes can,
  AVAudioPlayer's Ogg scheduling is byte-rate estimated — measured on macOS 26, a 29 s VBR
  narration "finishes successfully" at 20.6 s (cutting the final section mid-word) and seeks
  land off target the same way; the CAF's explicit packet table plays and seeks exactly.
  Chapter→step syncing: entering a chapter whose advisory `stepIndex` is in range turns the
  page; manual Back/Next seeks the recording to the chapter narrating the new step when one
  exists; and the timer auto-advance stands down while audio plays, so the two advance
  drivers never fight. Only the generic custom-devotion flow surfaces the bar today (no
  built-in bundle ships recordings yet). Playback positions persist per track id (the id's
  reserved purpose): saved on pause/stop/finish, resumed on load when past 10 s and short of
  90 % (finished or barely-started sessions begin fresh), and a resumed session pulls the
  page to the restored chapter instead of re-aligning the recording to step 0. Compose
  authors audio end to end (the Audio wizard screen: one .opus per language, chapters bound
  to authored steps with in-browser preview where the browser decodes Ogg Opus) — and its
  chapter stepIndex hints are emitted as BUILT-sequence indices, repeat-expanded exactly like
  the engines expand them, with the reverse mapping on re-import. `Shared/tools/make-audio-fixture.sh` builds the
  committed test bundle (`Shared/tools/fixtures/kyrieaudiodemo.prosaryprayer`): the Kyrie
  narrated by macOS TTS in Latin/English with measured chapter boundaries — strictly test
  material, never shippable content.
- **User-installed bundles**: anyone can author a `.prosaryprayer` and import it through Browse
  on Apple platforms, through Settings on Android/Windows, or through Apple File menu commands
  where available. `installPack` validates the file
  (readable zip; parseable manifest + devotion.json; content for every declared language; not a
  `builtinKind` pack; no id collision with anything loaded), copies it into a per-platform
  installed-packs directory (iOS Application Support/PrayerPacks — re-pointed at the iCloud
  ubiquity container's `Documents/PrayerPacks` when iCloud Drive is available, so manual
  imports follow the user across Apple devices (existing local packs migrate in;
  `.…icloud` placeholders from other devices get their download kicked off at scan;
  NSFileCoordinator/NSMetadataQuery live updates are deliberately deferred until a visible
  sync UI exists); Android filesDir/prayerpacks, Windows LocalFolder/PrayerPacks), and loads
  it live. Bundles installed from the prayers.prosary.app repository use ids of the form
  `repo.<username>.<name>` — the `repo.` prefix is what the UI keys its "Repository" tag on,
  and it can never collide with compose-authored ids (whose shape forbids dots). The directory is
  rescanned (sorted by filename) after the built-ins on every launch, so installs persist;
  id collisions are skipped so shipped devotions always win. Imported devotions appear in
  Categories and Search immediately and can be pinned to Pray like built-ins. Android and Windows
  Settings can export an installed pack for editing and remove individual packs; all platforms
  can clear installed downloads, while Apple also imports through Browse/File. The loader's
  removal unregisters the bundle plus its archive/image sources immediately, but does not delete
  a persisted `Prayer` row for it; globally merged shared text overrides retain their existing
  process-lifetime semantics. Every platform also ships a **repository browser** (iOS
  `RepositoryBrowserView`, Android `RepositoryBrowserScreen`, Windows `RepositoryBrowserPage` —
  each with a platform `RepositoryClient`): it fetches prayers.prosary.app's versioned
  `/index.json` catalog (`{prosaryRepository: 1, bundles: [...]}` — reject newer versions with
  an update prompt, never guess), filters by search text and tag, and installs through the very
  same `installPack` path, downloading via the catalog's same-origin `/api/download/<id>` so
  server-side counting keeps working. This is the only networked feature in the apps (Android's
  sole INTERNET permission). Compose is the authoring half; the repository is the sharing half — joined
  directly by **publish-from-Compose**: the Finish screen's "Publish" opens the repository's
  `/publish` receiver in a popup and hands the built bundle across via postMessage
  (origin-checked both ways). Everything sensitive stays first-party on the repository origin —
  the session cookie, the passkey ceremony (WebAuthn credentials are bound to
  prayers.prosary.app), and the actual POST /api/bundles — so no CORS or cross-site cookies
  exist. The receiver re-announces readiness on every mount and Compose answers every
  announcement, which makes the handshake survive the sign-in reload for free.
- **Transliterations** (v0.7) — a language file may carry an optional
  `"transliterations": {key: text}` map: a parallel rendering of that language's own prayer
  text in another script, for praying along in a language one can't read (a Hebrew
  transliteration of Tagalog was the motivating case — Gamaliel item 5). The target script is
  the author's choice and every key must exist in the same file's `prayers`. Loaders carry it
  into the built step (`RosaryStep.transliteratedBody`), and the prayer flow shows a toggle
  beside the text whenever the current step has one. Compose authors it per custom step and
  language.
  Reading aids follow the exact source selected for the body, including shared prayer text
  and language fallback. Replacing shared text replaces or clears its reading aid alongside it;
  a missing aid never borrows one from a different text. Decade prayers and combined presenter
  steps preserve these pairs, including the repeated Our Father, Hail Mary, and Glory Be.
  Peshitta imports keep the extracted ETCBC Syriac passage unchanged by script conversion and
  generate the Hebrew-square projection with Erez's deterministic converter
  (`Shared/tools/aramaic_script_converter.py`): contextual Hebrew finals, mapped vowel signs,
  qushshaya/dagesh, and the Syriac waw rules. Prayer bodies use the ordinary `transliterations`
  map; mystery Scripture uses `transliteratedDescription` beside its partial mystery override.
  The current source is unpointed, so the importer never invents points. `$scriptureImport`
  records exactly which fields are generated, and the offline `test-import-scripture.py` checks
  the converter, every generated passage, and byte parity of all four packed copies.
- **`bodyKey`/`titleKey` resolution** (`resolveBodyText`, per bundle): walk the requested wording
  and the user's `languageFallbackOrder`, with generic Hebrew beside the higher Hebrew tradition
  as described above. At each probe try bundle-local text, the Rosary's shared prayer heading,
  then the shared override/native `PrayerTranslations` entry. Only after exhausting the chain
  show the raw key. The shared prayer and mystery tables use the same content probes; mystery
  title, fruit, and description walk them independently. This keeps
  an available English Glory Be in English instead of replacing it with an unrelated bundle
  translation, while bundle-only keys still obey the chosen precedence. Missing Mission wording
  can use generic Hebrew at that priority, but never silently promotes Vicariate wording above
  intervening languages. A rite may stop at different languages for different mystery fields — most
  importantly, its Scripture description stops at its own edition while its title/fruit can keep
  falling back. Each platform's engine tests pin both that partial merge and the Peshitta's
  Hebrew-square/Syriac pair.
  The five main-prayer heading keys also reuse the Rosary bundle's requested/base-language
  titles before falling back to another language, so a devotion can reuse an Aramaic Glory Be
  with its sourced Aramaic heading.
  On Windows, `PrayerKey` is a set of string constants
  rather than a validating enum and every content key also merges into one global PascalCased
  override table, but `ResolveBodyText` follows the same per-bundle-raw-first chain.
  Settings edits `languageFallbackOrder` with the same drag-handle/reorder interaction as the
  Pray tab's Home Order editor and provides a reset to the catalog default. It is an actual
  precedence list, not a collection of independent toggles: each language appears exactly once.
  Every Scripture citation uses an en dash for a range (`26–38`) in every language; a hyphen stays
  a hyphen in ISO/calendar dates (`YYYY-MM-DD`), identifiers, language tags, and compound words.
  Hebrew-script citations, whether in Today
  data or inside a devotion, additionally follow one display grammar: `[book] [chapter in
  gematria] [verses in Arabic numerals]`, with no colon (for example `יוחנן ג׳ 16–17`). The book
  name and verse numbering still belong to the selected edition/rite; formatting must never
  convert a Peshitta or Septuagint citation back to Vulgate numbering.
- **Validation**: `Shared/tools/validate-devotion.py` (run by both packers) checks the schema per
  type, that every referenced key resolves in every manifest language (bundle content ∪ the
  surviving hardcoded `PrayerKey` set ∪ merged mystery keys, minus each bundle's explicit
  `validation-allowlist.json`), field-wise mystery overrides, citation punctuation (en dashes for
  every range; gematria chapter/no colon in Hebrew script), that imageKeys exist, and the
  rosary-type bead invariants. Each
  platform's `PrayerTranslationsCompletenessTests` mirrors the same checks against the
  actually-shipped packs and runtime merge, with the same explicit allowlists (currently: the
  Divine Mercy offering/petition in Hebrew; the Seven Sorrows closing in ar/he/ru/tl).
- **Discovery**: `customDevotionIds()` returns every loaded bundle id that has a
  `devotion.json`, **in pack-load order** — the base directory order. `DevotionDirectory` presents
  the Rosary first, then those bundles (title/accent/icon/tags from each manifest), then the Jesus
  Prayer. Categories and Search use the whole directory; Pray filters it through the user's pins
  and applies `HomeOrder`. Nothing in view code hardcodes a bundle devotion's name.
- **Flow UI**: one shared flow surface per platform (iOS `CustomDevotionFlowView`, Android
  `CustomDevotionFlowScreen`, Windows `CustomDevotionFlowPage`) renders every generic devotion,
  showing the same bead track as the Rosary whenever any built step carries a `decadeIndex` (the
  "rosary" type) and a plain progress bar otherwise. The bead track consumes only
  `decadeIndex`/`hailMaryIndexInDecade`/`isAntiphon`/`hasClosingCross`, which is why the
  devotion.json invariants above exist.

## Offline "Today" data (`Shared/data/`)

Dev-time-generated datasets back the Pray tab's "Today" section (per-platform physical
copies, same convention as the bundles; per-platform `TodayInfoStore` providers):

- **Feast tables, one per liturgical calendar** (2026-08: switchable, Erez's request) — each a
  per-day sanctoral table (`days: {"YYYY-MM-DD": {title, rank, titleByLanguage?}}`) for the generated years,
  movable feasts baked in per year at generation time; no computus or precedence logic ships in
  the app, and ferial days have no entry. `calendars.json` is the registry: id, feast-table
  basename (`file`), reading-table basename (`readingsFile`), and the Settings picker label
  (`name`/`nameByLanguage`, resolved by UI language);
  its `default` names the calendar used when the app-wide `feastCalendarId` setting (stored
  beside `defaultLanguageCode` on every platform) is unset or unknown. Shipped calendars:
  - `lpj` — **`feasts.json`**: the General Roman Calendar (litcal API) overlaid with the Latin
    Patriarchate of Jerusalem's documented propers (Our Lady, Queen of Palestine and of the
    Holy Land — Oct 25, patronal solemnity; the Dedication of the Basilica of the Holy
    Sepulchre — Jul 15; Saint Mary of Jesus Crucified Baouardy — Aug 26). The default; keeps
    the pre-switchable filename.
  - `roman` — **`feasts-roman.json`**: the General Roman Calendar, no overlay (litcal,
    Apache-2.0). Its sourced Hebrew day names are inline as `titleByLanguage.he`, courtesy of
    Evangelizo.org — Daily Gospel (© Evangelizo.org), publication edition HE. The old
    `roman-he` pseudo-calendar is gone; persisted `roman-he` selections migrate to `roman`.
    `feasts.json` carries the same sourced General-calendar names where they match, while an LPJ
    propers receive reviewed display labels from the same shared localization catalogs.
  - `roman1962` — **`feasts-roman1962.json`**: the 1962 Vetus Ordo calendar (missalemeum.com,
    MIT), I–III class days with class ranks ("1st Class"…"3rd Class"); IV-class days and bare
    ferias are omitted the way ferial days are elsewhere. The Pray screens bold a feast title
    when its rank is "Solemnity", **"1st Class"**, or **"Great Feast"**.
  - `ugcc` — **`feasts-ugcc.json`**: Byzantine — Ukrainian Greek Catholic, with
    Gregorian fixed feasts and Julian Pascha by default, matching Ukraine's new-style calendar.
    The optional `easternPaschaStyle` preference selects `julian` or `gregorian`; both
    feast and reading tables switch together through the registry's `paschaVariants`.
    `feasts-ugcc-gregorian.json` supplies the fully Gregorian option. Unknown preferences use
    Julian Pascha. The fixed menologion remains curated; movable Sundays, the Paschal cycle,
    and Sundays around Nativity, Theophany and the Cross are computed separately for each
    style. Both retain September 1 as the liturgical year's beginning. These choices are
    calendar usages, not a blanket substitution of one Eastern church's lectionary for another.
  - `syriac` — **`feasts-syriac.json`**: "West Aramaic — Syriac Catholic" (the Mission's
    own chosen name for its tradition),
    liturgical day titles **courtesy of Evangelizo.org — Daily Gospel (© Evangelizo.org)**,
    via its publication API's English Syriac-calendar edition ("SYE"), one request per day;
    the credit is required and carried on every platform's About screen ("Calendar Data"
    section, which also names LitCal and Missale Meum). Plain-date ferial titles are omitted;
    ranks are title-derived ("Sunday" / "Fast" / "Feast", with Pascha as "Great Feast").
    Evangelizo serves a rolling ~3-month horizon, so new Hebrew Roman titles from that feed and the
    `syriac` table end where the API did at generation time and extend on each rerun — regenerate more often
    than yearly.
  - `maronite` — **`feasts-maronite.json`** and **`readings-maronite.json`**: Evangelizo's
    separate MAE edition. `Shared/tools/fetch-maronite.py` downloads each day once and emits
    both tables. Ordinary ferial captions are omitted from the feast table; Sundays, named
    feasts and Holy Week observances remain. It shares the rolling-source coverage limitation.
    Maronite and Syriac Catholic use their published calendar; a second Pascha setting is not
    offered without a separately verified lectionary for it.
    Adding a further calendar remains a pure data drop: a registry entry + a dataset file +
    its `readingsFile` + platform copies.
  `Shared/tools/fetch-feasts.py` regenerates Roman, Byzantine and Syriac tables;
  `fetch-maronite.py` refreshes the distinct Maronite edition. Their `--sync` mode copies
  all of `Shared/data/*.json` into the three platform asset dirs.
  All six calendars and both Byzantine variants receive sourced Hebrew names from `Shared/tools/hebrew-feast-titles.json`
  and `hebrew-saint-titles.json`. These catalogs preserve Evangelizo HE wording beyond its rolling
  window and relay names from the St James Vicariate's bilingual calendar and Hebrew articles,
  with additional feast names from the Christian Media Center. Thomas the Apostle uses the
  user-preferred `תאמא השליח`, also attested by Vatican News in Hebrew. Every label records its source;
  exact English identities and reviewed aliases reuse names across years and rites without
  copying another calendar's dates, ranks, or precedence. Credited `feast-titles-*.json`
  catalogs supply the remaining display metadata in all seven interface languages; they do
  not claim to be official liturgical translations or prayer texts. Sourced titles override
  editorial labels. Compound observances retain each component. Hebrew Pentecost is
  `שבועות`, including numbered Sundays after Pentecost. The alias list is explicit and
  reviewed; it never fuzzy-matches saints or transfers feast dates. Catalog edits refresh
  matching labels, including labels previously generated. Run `uv run --script Shared/tools/fetch-feasts.py --localize-only --sync`
  to apply catalog additions offline without changing the calendar coverage; `--self-test` checks
  identity matching, preservation, and fallback. New catalogs or sources require matching About
  credits in all three ports. Mother Teresa's 2026-09-05 memorial, for example, gains its sourced
  Hebrew name in the two modern Roman calendars, while 2027-09-05 remains the Sunday already in
  their tables and the other rites retain their own observances.
  `TodayInfoStore` reloads both the feast and reading tables when the selected calendar changes.
  The calendar choice affects the Today feast and its lectionary citations together. A local
  selected date drives every Today row. The navigation row has previous/next arrows and a
  centered date button opening a native calendar, with a Today action inside the popup.
  Prayer-day computations, mystery assignment and Marian antiphons remain independent of
  browsing dates. The supplementary day heading is hidden on Sundays. On weekdays it uses
  the modern Roman seasonal label only for `lpj` and `roman`; other calendars show the
  civil day and month instead of Ordinary Time. Today follows the interface language with no
  separate language picker, and previously stored `todayLanguageCode` overrides are ignored.
  This remains independent of the prayer language. Platform locale aliases such as `iw`
  and `fil` normalize to the shared `he` and `tl` codes. Weekday, season/week headings, rank,
  intention and citation captions follow the interface language. Arabic and Hebrew set the complete
  Today stack to RTL, including the expanded citations. Published feast and intention text
  uses that language when available, with the original source text as fallback. Calendar
  dates, rank identities and appointed readings never change with the language selection.
  The readings row shows compact citations (for example `Gen. 1; Ps. 23; Jn. 3`); a button expands
  the same entries to their complete chapter-and-verse citations. A missing reading file/date hides
  the row: it must never borrow another rite's readings. Each optional Today
  row still has its own Settings switch (2026-08, Erez's request:
  `showTodayFeast` / `showTodayIntention`, both on by default) — either, both, or neither
  row can show, and a row switched off simply never loads.
- **`torah-portions.json`** — optional `showTodayTorahPortion` (default false), from
  Hebcal.com (CC BY 4.0). Always Eretz Israel (`i=on`); there is no diaspora option.
  Each selected day maps to the coming Saturday, including Saturday itself. Festival Torah
  readings replace a weekly portion where appropriate. Only the five books of Moses are
  included; haftarah and festival megillot are excluded. Source Hebrew/French/Russian proper
  names and source transliterations combine with localized captions and citation book names.
  Generate with `fetch-torah-portions.py --sync`; `--offline` reuses the downloaded cache.
- **`pope-intentions.json`** — 2026–2027 monthly intentions from the Pope's Worldwide Prayer
  Network, including published Arabic, French, Italian and Filipino editions, the parish-published
  Russian translation for 2026 (credited to t.me/ihsovs), plus Prosary's
  Hebrew translation. `sourceByLanguage` records published sources and
  `translationCreditByLanguage` distinguishes authored translations. The Hebrew version is not
  an official Vatican edition. `Shared/tools/import-pope-intentions.py --source-dir <pdf-cache>
  --sync` imports the 2026 PDFs and reviewed 2027 snapshots. Arabic and Italian source PDFs
  with broken character maps have visually reviewed transcriptions; corrections from other
  official publications are recorded in the source snapshot. Missing languages use English,
  and months outside the table hide the row.
- **Reading tables, selected through `readingsFile`** — each date contains ordered citation
  objects (`type`, `short`, `full`, and optional `shortByLanguage`/`fullByLanguage`). Only
  citations ship; Scripture text does not. `readings-roman.json` is the Novus Ordo table from
  Evangelizo HE and is shared by `lpj` and `roman`; its Hebrew full book names are relayed in
  the per-language maps. Hebrew short epistle names are deterministic compact forms of those
  sourced titles (`הראשונה אל הקורינתים`, `השנייה של כיפא`, `אל הרומים`): the
  generator removes redundant “epistle”/author wording, standardizes the compact ordinal phrase,
  and does not translate or alter the complete citation's wording. Hebrew word joins and
  numeric prefixes use maqaf (`־`), while verse ranges keep en dashes (`–`).
  `readings-roman1962.json` is the Vetus
  Ordo table from Missale Meum's
  public proper API. Appointed lesson, Passion and Gospel references retain every chapter
  continuation, including Galatians 5:25–26; 6:1–10. Historical book aliases and punctuation
  are normalized explicitly. Grouped Holy Week lessons are retained; rubrics and interspersed
  chant references are excluded. Multiple Mass propers remain in source order.
  `readings-ugcc.json` comes from the UGCC Patriarchal Liturgical Commission's official
  2026 calendar via `import-ugcc-calendar.py` and its checked-in reference-only snapshot.
  The importer distinguishes appointed Liturgy readings from Matins and water-blessing
  readings, retaining prescribed Hours/Vespers references when those are the day's service.
  Source punctuation corrections remain dated and auditable beside the original reference.
  `readings-ugcc-gregorian.json` comes from Royal Doors' fully Gregorian calendar.
  `readings-syriac.json` comes from Evangelizo SYE; Maronite uses MAE. `Shared/tools/
  fetch-readings.py` refreshes the selected sources and `--sync` copies all reading files
  plus the registry into the native apps while removing the retired global `readings.json`.
  Hebrew citation display covers every lectionary: the generator uses the
  credited book names in `Shared/tools/hebrew-reading-books.json`, retaining each calendar's
  dates, chapters, verses, and reading order. `--localize-only --sync` refreshes those localized
  maps offline without fetching or substituting another rite's readings.

A date/month outside the relevant dataset returns nothing and its row simply hides. Regenerate
the multi-year feast tables roughly yearly; refresh the rolling Evangelizo-backed data more often.
See [calendar research and coverage](calendar-research.markdown) for source rules and limits.

Prayer cards and lists use interface-language titles by default. The shared
`showPrayerNameInPrayerLanguage` preference (default false) makes the actual prayer-language
name primary and adds the distinct interface-language name as a subtitle. It does not change
prayer text or its selected language, and ordinary descriptions/progress remain visible.

## Interface languages and new prayer sources

All three interfaces support English, Hebrew, Arabic, Russian, Filipino/Tagalog, French and
Italian. Native locale identifiers may use `fil` while shared content retains `tl`. The
interface language follows each platform's app-language mechanism, and Today follows it; prayer
language preferences remain independent. Resource catalogs include accessibility labels, notifications,
error states, settings, search categories and About credits in all seven languages.

French Scripture passages use Augustin Crampon (1923), public domain, from
[scrollmapper/bible_databases](https://github.com/scrollmapper/bible_databases).
Italian passages use Antonio Martini's public-domain translation; the structured chapter data
is © Giovanni Novelli, [Parola Viva](https://parolaviva.art/opendata), CC BY 4.0. Only the biblical
text is imported. Source wording and source verse numbering stay together; Crampon Isaiah 9
uses a reviewed numbering offset from the Vulgate. French and Italian fixed prayers relay the
[Vatican Compendium](https://www.vatican.va/archive/compendium_ccc/documents/archive_2005_compendium-ccc_en.html)
and other per-content credited publications. `fr`/`it` overlays without enough sourced content
remain partial; bundle language menus advertise declared supported languages only.

Reading-book metadata for all five additional UI languages is recorded with sources in
`Shared/tools/reading-books-localized.json`. `fetch-readings.py --localize-only --sync` applies
those names offline while preserving every calendar's chapter and verse references.

French/Italian full prayer choices now include Rosary, Angelus, Franciscan Crown, Divine Mercy,
Seven Sorrows, Via Lucis, O Antiphons and Trisagion. Spanish now has sourced complete Rosary,
Angelus, Divine Mercy and Trisagion flows. Spanish and Greek have complete Franciscan Crown
flows, and Greek also has the Trisagion. Stations of the Cross has sourced French/Italian
Scripture, opening prayers and fourteen traditional Liguori meditations. The independent
optional closing prayer remains unsourced, so these overlays are still partial.
The original Seven Sorrows fourth reflection is an authored
meditation and its French/Italian rendering is explicitly identified as Prosary's translation.
Each new prayer file has `$sources`; Scripture provenance remains separately in
`$scriptureSource` when a file mixes fixed prayers with imported Bible passages.
The importer preserves authored `$comment` notes in every language. Spanish Wikisource imports
remove nested source annotations before identifying verse numbers, preserve words split by
inline markup, and recognize the misspelled John 21 chapter heading. Source-specific corrections
such as the printed Martini Isaiah 28:16 word join are recorded with their exact edition and verse.

`Shared/tools/audit-prayer-coverage.py` inventories actual selected-language text across all
eleven public prayer languages, before any fallback. `PRAYER-LANGUAGE-COVERAGE.json` records
every missing key; its Markdown companion summarizes complete, partial and absent pack-language
pairs. This coverage check complements structural validation and source research: a resolved
known `PrayerKey` alone does not establish a translation, and text presence is not an editorial
certification. `test-localized-content.py` prevents newly completed flows from regressing to
another language.

The legacy Arabic Scripture credit identifies Dar el-Machreq. The earlier blanket claim that
all editions are public domain was removed: no such status is established here for the modern
Arabic revision. This pass preserves existing Arabic passages rather than changing editions.

Run `test-localized-content.py`, `test-import-scripture.py`, `audit-content.py`,
`test-asset-deduplication.py`, and the feast/readings generators' `--self-test` checks after
regeneration. The content audit exempts UI labels and specific complete unpunctuated source
chants while rejecting blank bodies and known scraped website material. The Via Lucis English
and Latin Matthew 28 passage no longer includes its source website's footer or commentary.
Arabic full reading references isolate their chapter/verse spans left-to-right inside the RTL
book label, preserving semicolon-separated range order on screen.

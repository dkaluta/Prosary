# Prosary: shared architecture across iOS, Android, and Windows

Prosary ships as three independent, native apps — iOS/macOS (SwiftUI, `../iOS`), Android (Jetpack
Compose, `../Android`), and Windows (WinUI3, `../Windows`) — each its own git repo with no shared
code. **This directory holds no code.** It's the canonical copy of assets used by all three
(`Fonts/`, `Images/` — see below) and this doc, which exists so that changing a concept on one
platform is easy to replicate correctly on the other two: the three codebases are independent
*implementations* of one shared *design*, and that design is what's described here. iOS is the
canonical source of truth when the three genuinely disagree — if you find a real divergence,
prefer iOS's current behavior over Android's or Windows's.

## Domain model

Every platform models a saved, user-configurable prayer session the same way, just in its native
idiom (Swift `struct`, Kotlin `data class`, C# `sealed record`):

- **`Prayer`** — a saved favorite: `id`, `name`, `kind` (`PrayerKind`), `isDefault` (starred/
  primary for its kind — at most one per kind at a time), `languageCode` (an empty-string/
  "default" sentinel means "follow the app-level default language setting"), nested
  `RosaryOptions`/`JesusPrayerOptions` (the Angelus, Stations of the Cross, Franciscan Crown,
  Seven Sorrows, and Divine Mercy Chaplet need no options beyond a language), and a list of
  `PrayerReminder`s.
- **`PrayerKind`** — `Rosary` / `Angelus` / `JesusPrayer` / `StationsOfTheCross` /
  `FranciscanCrown` / `SevenSorrows` / `DivineMercyChaplet`. This completes the four-devotion
  rollout (Stations of the Cross, Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet), all
  implemented on all three platforms. Adding a new devotion beyond these means adding a case here
  (all three platforms) plus a matching options type on `Prayer` if the devotion needs one —
  several of the existing ones don't (Angelus, Stations, Franciscan Crown, Seven Sorrows, Divine
  Mercy Chaplet).
- **`RosaryOptions`** — `mysterySelectionMode` (today's mysteries / a specific fixed set / all 15
  / all 20 / a single mystery), `specificMysteryGroup`, `specificMysteryOrder` (1-based, used only
  for the single-mystery mode), `presenterMode` (collapses each decade's Hail Marys + Glory Be
  onto one combined step — see "Engines" below), and toggles for the Apostles' Creed, opening Our
  Father + 3 Hail Marys, the Fatima Prayer, eternal-rest placement, the closing Marian antiphon,
  the St. Michael prayer, and the final Sign of the Cross.
- **`JesusPrayerOptions`** / **`JesusPrayerTarget`** — a repetition count (`Count(n)`) or
  `Unbounded` (no target; the user ends the session explicitly).
- **`JesusPrayerProgress`** — the live repetition counter during a session. Immutable
  (Kotlin/C# — `with`/`copy`-based updates) on Android and Windows; a mutable struct on iOS. This
  is a deliberate, known divergence, not a bug.
- **`PrayerReminder`** — `id`, `hour`, `minute`, `isEnabled`. One-off local reminder times, not a
  recurrence rule — see "Reminders" below for why each platform schedules these differently.
- **`LanguageOption`/`LanguageCatalog`** — the 6 supported prayer languages (`la` default, `en`,
  `ar`, `he`, `ru`, `tl`; `ar`/`he` right-to-left), independent of the device's own UI language.

## Content layer

- **`PrayerKey`** — stable, language-independent identifiers for every fixed prayer text (the
  Sign of the Cross, Our Father, Hail Mary, Glory Be, the Angelus's versicles, etc.).
- **`PrayerTranslations`** — `Get(languageCode, key)`-style lookup, one dictionary per language,
  falling back to Latin then the raw key if a translation is missing.
- **`Mystery`/`MysteryCatalog`** — the fixed catalog of all 20 mysteries, grouped into
  `MysteryGroup` (Joyful/Sorrowful/Glorious/Luminous) and ordered within each group. Carries no
  display text itself — title/fruit/description are looked up by `imageKey` via
  `MysteryTranslations`, the same fallback-chain pattern as `PrayerTranslations`.
- **`Station`/`StationsCatalog`** — the fixed catalog of all 14 Stations of the Cross, ordered, no
  grouping (unlike mysteries, there's only one fixed sequence). Carries no display text itself —
  title/meditation looked up by `imageKey` via `StationsTranslations` (`la`/`en` populated now,
  `ar`/`he`/`ru`/`tl` fall back to Latin). See `Shared/schema/stations.json`.
- **`RosaryStep`** — one prayer "bead" in a fully built session: title, optional subtitle (decade
  context), body text, optional `Mystery`, `isScripture` (true only for the mystery-announcement
  step, whose body is a real quoted Bible verse), `isAntiphon`, `decadeIndex` (0-based, counted
  *globally* across every mystery group in the session — this is what the bead track uses to tell
  decades apart, so it must never reset per group), `hailMaryIndexInDecade` (1–10 for the Rosary/
  Franciscan Crown/Divine Mercy Chaplet, 1–7 for Seven Sorrows), and an
  `imageOverrideKey` for steps not tied to a Mystery that still want a specific illustration
  (e.g. "crucifix" for the Sign of the Cross, "our_father" for the Our Father, "madonna_and_child"
  for the antiphon).

## Engines

One `PrayerEngine` type builds every devotion's steps — `buildSteps(for: Prayer) -> [RosaryStep]`
is the single entry point, dispatching internally on `Prayer.kind`. This replaced 6 separate
protocols (`RosaryEngine`/`AngelusEngine`/`StationsEngine`/`FranciscanCrownEngine`/
`SevenSorrowsEngine`/`DivineMercyEngine`) and their per-devotion production types, which had
accumulated real duplication once all 7 devotions existed side by side — see git history around
the "unify prayer engines" commit on each platform for the before/after. The per-devotion
*behavior* described below didn't change, only how it's organized:

- **Rosary** — the richest: opening (Sign of the Cross, optional Creed, optional opening Our
  Father/3 Hail Marys for Faith/Hope/Charity), one loop per decade across every resolved
  `MysteryGroup` (mystery announcement → Our Father → 10 Hail Marys → Glory Be → optional Fatima
  Prayer → optional per-decade eternal rest), closing (Marian antiphon → optional St. Michael
  prayer → optional end-of-session eternal rest → optional final Sign of the Cross). The
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
- **Angelus** — no user-configurable options (unlike the Rosary): the fixed 7-step Annunciation/
  Fiat/Incarnation/Let-Us-Pray sequence, or a single Regina Caeli step during Eastertide (see
  `LiturgicalCalendarService.isEasterSeason`). The Jesus Prayer has no engine involvement at all
  — `PrayerEngine.buildSteps` returns an empty array for it; every repetition prays the same fixed
  line, so a single synthesized step plus a `JesusPrayerProgress` counter is the whole model.
- **Stations of the Cross** — same "no user-configurable options" shape as Angelus: opening
  prayer, each of the 14 stations (versicle/response + meditation) in order, closing prayer. Every
  step leaves `mystery`/`decadeIndex`/`hailMaryIndexInDecade` at their defaults — no decade/bead
  math at all, so the flow UI shows a plain progress bar, not the bead track (see "Bead progress
  track" below).
- **Franciscan Crown** — same "no user-configurable options" shape, but decade-based like the
  Rosary: Sign of the Cross, 7 decades of the Seven Joys of Mary (Our Father + 10 Hail Marys each
  — same bead math as the Rosary), 2 closing Hail Marys + 1 closing Our Father (72 years
  traditionally attributed to Our Lady's life, and the Pope's intentions), the seasonal Marian
  antiphon, closing Sign of the Cross. Every step leaves `mystery` nil/null — the Seven Joys
  aren't Rosary `Mystery`s even though 6 of the 7 reuse existing mystery imageKeys/content (see
  `mysteries.json`'s `franciscanCrownSevenJoys`) — which is exactly the case the bead track's
  column-grouping generalization (below) exists for.
- **Seven Sorrows** — same "no user-configurable options" shape as Franciscan Crown, decade-based
  like the Rosary, but with 7 Hail Marys per decade instead of 10 (see `seven-sorrows.json`'s
  `hailMarysPerDecade` — this is what the bead track's beads-per-decade generalization, below,
  exists for): Sign of the Cross, 7 decades of the Seven Sorrows of Mary (Our Father + 7 Hail
  Marys each), 3 closing Hail Marys for Our Lady's tears, a fixed closing versicle/response/
  collect (unlike the Rosary/Franciscan Crown, not a user choice), closing Sign of the Cross.
  Every step leaves `mystery` nil/null, same reasoning as Franciscan Crown — but unlike Franciscan
  Crown, none of the 7 Sorrows reuse an existing Rosary mystery imageKey (see `seven-sorrows.
  json`), so all 7 are new content. One sorrow
  (`seven_sorrows_04_meeting_jesus_on_the_way_of_the_cross`) has no direct Gospel citation and is
  marked `isScripture: false`, unlike the other six.
- **Divine Mercy Chaplet** — the lightest of the four rollout devotions: same "no user-
  configurable options" shape, decade-based like the Rosary (5 decades, 10 Hail-Mary-position
  steps each — the standard bead math, no generalization needed), but with **no per-decade
  catalog at all**: opening (Sign of the Cross, Our Father, Hail Mary, Apostles' Creed — all
  reusing existing `PrayerKey`s, nothing new), then 5 decades each of one offering ("Eternal
  Father, I offer You...") at the Our-Father-bead position and 10 petitions ("For the sake of His
  sorrowful Passion...") at the Hail-Mary-bead positions — **the exact same two lines repeated
  every decade**, unlike the Rosary/Franciscan Crown/Seven Sorrows, none of which repeat identical
  content across decades — closing with the acclamation ("Holy God, Holy Mighty One, Holy
  Immortal One...") prayed three times, then a closing Sign of the Cross. Every step leaves
  `mystery` nil/null and reuses the single `divine_mercy_image` illustration, the same reuse
  pattern Angelus uses for `joyful_01_annunciation`.

Two pieces of logic are shared internally by `PrayerEngine` rather than duplicated per devotion:

- **The per-decade step builder** (announcement → Our Father → N Hail Marys) — used by both the
  Rosary's inner per-group loop and Franciscan Crown/Seven Sorrows' single decade loop, which are
  the same shape underneath (they differ only in catalog, Hail-Marys-per-decade, and which image
  key the Our Father step shows — the Rosary always shows a fixed "our_father" icon there, while
  Franciscan Crown/Seven Sorrows keep showing that decade's own illustration).
- **The Marian antiphon step builder** — used by both the Rosary's closing antiphon and Franciscan
  Crown's fixed seasonal antiphon.
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
  current / upcoming — drives its color), `isGroupStart` (true for the first bead of each
  group-of-5, used only by the narrow layout's single-row minor beads to add extra spacing there).
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

## Persistence

Each platform has its own `PresetStore` abstraction (iOS: `Protocols/PresetStore.swift` +
`SwiftDataPresetStore`; Android: `presets/PresetStore.kt` + `persistence/RoomPresetStore.kt`;
Windows: `Persistence/IPresetStore.cs` + `SqlitePresetStore.cs`) with the same contract:

- `all()` / `GetAllAsync()` — every saved favorite.
- `defaultPreset(kind)` / `GetDefaultAsync(kind)` — the starred favorite of that kind, or the
  first favorite of that kind, or none.
- `get(id)` / `GetAsync(id)`.
- `save(prayer)` / `SaveAsync(prayer)` — insert or update by id. If the saved favorite is
  default, every *other favorite of the same kind* has its default flag cleared — **each kind
  keeps its own independent default**, never a global one.
- `delete(prayer)` / `DeleteAsync(prayer)` — if the deleted favorite was default and others of the
  same kind remain, one is promoted to default.

The per-kind (not global) default/delete scoping is the one behavioral detail worth calling out
explicitly: it's easy to accidentally implement an unscoped version (clearing/promoting defaults
across *every* favorite regardless of kind) if a platform's store started out Rosary-only before
Angelus/Jesus Prayer existed, since "every row" and "every Rosary row" are indistinguishable until
a second kind is introduced. Windows's `SqlitePresetStoreTests` specifically regression-tests this.

### Favorites UI: configurable vs. simplified kinds

Rosary and Jesus Prayer are the only kinds with real per-favorite options worth naming and saving
multiple variants of, so they keep the full favorites experience: a card list, "+ Add", and a full
editor (name, language, kind-specific options, reminders). The other 5 kinds (Angelus, Stations of
the Cross, Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet) render as a single star row per
kind instead — no name/language editing, no "+ Add another". Tapping the star still just calls
`save`/`delete` on a `Prayer` row through the same `PresetStore` (no separate persistence entity),
but constrained at the UI layer to at most one row per kind: matched by **kind alone** (not kind +
language), and always saved with the sentinel `languageCode` (follows the app-level default
language setting — there's no per-favorite language choice left to make for these kinds). Once
favorited, a small reminders-only editor (iOS: `RemindersOnlyEditorView`; Android:
`RemindersOnlyEditorScreen`; Windows: `RemindersOnlyEditorPage`) is reachable from the row — it
shares its reminders-list UI with the full editor via one extracted component (iOS:
`RemindersSection`) rather than duplicating it.

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

- **`Fonts/`** — the 5 bundled prayer typefaces (Amiri, Cardo, Frank Ruhl Libre, Scheherazade New,
  Shofar — see `Fonts/ATTRIBUTIONS.md` for licenses) used for Hebrew/Arabic prayer and Scripture
  text, and Latin/English Scripture quotations. Latin-script *ordinary* prayer text uses each
  platform's own system serif instead (Apple's "New York" on iOS/Mac, the system serif on
  Android, Cambria on Windows) — none of those are bundled, only the 5 above are.
- **`Images/`** — the 20 mystery paintings (public-domain classical art) plus ~10 override
  illustrations used by steps not tied to a specific mystery (`crucifix`, `our_father`,
  `glory_be`, `jesus_portrait`, `eternal_rest`, `madonna_and_child`, `st_michael`,
  `virtue_faith`/`virtue_hope`/`virtue_charity`) and `cross_placeholder` (a simple generated
  placeholder, not classical art). See each platform's own About/Settings screen for full
  per-painting artist attributions.

**Each platform keeps its own physical copy** of these files (iOS: `Assets.xcassets` imagesets +
`Fonts/`; Android: `res/drawable-nodpi/` + `res/font/` — filenames snake_cased per Android's
resource-naming requirements; Windows: `Prosary/Assets/Images/` + `Prosary/Assets/Fonts/`) rather
than referencing this directory directly at build time — this directory has no git repo of its
own, so a live cross-repo reference would break any platform repo cloned on its own. If you add or
change an asset, update it here *and* copy it into whichever platform(s) use it.

## Content bundles (`.prosaryprayer`)

A portable, zip-based content format (UTI `app.prosary.prayer`) for a single devotion's translated
text + images, designed so devotion content can eventually live outside each platform's hardcoded
source. `Shared/content/<devotion>/` is the actual canonical, authored source (not just a
human-synced spec like `Shared/schema/`) — one directory per devotion, each with `manifest.json`,
`content/<lang>.json` per supported language, an optional `catalog.json` for devotions with a
mystery-style catalog, and images pulled from `Shared/Images/` at pack time. `Shared/tools/
make-prosaryprayer.sh` (and its PowerShell twin, `Make-ProsaryPrayer.ps1`) validate a devotion's
source directory and zip it into `Shared/dist/<devotion>.prosaryprayer`.

**The "main" prayers are never duplicated into a bundle.** Sign of the Cross, Apostles' Creed, Our
Father, Hail Mary, and Glory Be (`signumCrucis`, `symbolumApostolorum`, `paterNoster`, `aveMaria`,
`gloriaPatri`) stay hardcoded in each platform's `PrayerTranslations` table and are deliberately
absent from every bundle's `content/<lang>.json` — a devotion's steps keep referencing them by the
same `PrayerKey` as always. Each manifest's `mainPrayerKeysOmitted` array documents exactly which
of these 5 a given devotion's flow uses, so their absence from the bundle reads as intentional, not
a content gap.

Only Rosary and Angelus are currently packaged this way (the two most complete devotions — full
6-language coverage, full real artwork). At runtime, each platform's `PrayerPackLoader` merges a
loaded bundle's content into the existing `PrayerTranslations`/`MysteryTranslations` tables
(bundle wins on collision) rather than replacing them — necessary because `PrayerKey`/mystery
`imageKey` entries are a shared pool across devotions (e.g. `our_father` is used by Rosary,
Angelus, Franciscan Crown, Seven Sorrows, and Divine Mercy alike), so a bundle can only ever
*add to* the hardcoded tables, never fully replace them. Devotions without a shipped bundle
(Stations, Franciscan Crown, Seven Sorrows, Divine Mercy, Jesus Prayer) are completely unaffected
and keep resolving 100% from hardcoded source, exactly as before this format existed.

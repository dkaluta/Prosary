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
  primary for its devotion — at most one per (kind, customDevotionId) at a time), `languageCode`
  (an empty-string/"default" sentinel means "follow the app-level default language setting"),
  nested `RosaryOptions`/`JesusPrayerOptions` (generic devotions need no options beyond a
  language), `customDevotionId` (populated only when `kind == custom` — see "Content bundles"
  below), and a list of `PrayerReminder`s.
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
  Franciscan Crown/Divine Mercy Chaplet, 1–7 for Seven Sorrows), and an
  `imageOverrideKey` for steps not tied to a Mystery that still want a specific illustration
  (e.g. "crucifix" for the Sign of the Cross, "our_father" for the Our Father, "madonna_and_child"
  for the antiphon).

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
options.json values (`rosaryOptionValues`), so there is **no data migration**.

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
- **Generic devotions** (`.custom`) — flat ("steps" type: Angelus, Stations, Via Lucis,
  Trisagion) or
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
  default, every *other favorite of the same devotion* has its default flag cleared — the default
  slot is scoped per **(kind, customDevotionId)**, so two generic devotions never steal each
  other's default, and never a global one.
- `delete(prayer)` / `DeleteAsync(prayer)` — if the deleted favorite was default and others of the
  same (kind, customDevotionId) remain, one is promoted to default.

The per-devotion (not global) default/delete scoping is the one behavioral detail worth calling
out explicitly: it's easy to accidentally implement an unscoped version if a platform's store
started out Rosary-only, since "every row" and "every Rosary row" are indistinguishable until a
second devotion is introduced. Each platform's store tests regression-test this, including the
two-generic-devotions case. Legacy rows written before the generic-devotion migration are handled
per platform as described under `PrayerKind` above (iOS: `PresetEntry.resolvedKind`; Android:
`PresetEntity.resolvedKind`; Windows: the `user_version`-guarded SQL pass in
`SqlitePresetStore.InitializeAsync`), and each platform ships `LegacyKindMigration` tests.

### Favorites UI: configurable vs. simplified kinds

Rosary and Jesus Prayer are the only kinds with real per-favorite options worth naming and saving
multiple variants of, so they keep the full favorites experience: a card list, "+ Add", and a full
editor (name, language, kind-specific options, reminders). Every generic (bundle-driven) devotion
renders as a single star row instead, one per discovered bundle in pack-load order — no
name/language editing, no "+ Add another". Tapping the star still just calls `save`/`delete` on a
`Prayer` row through the same `PresetStore` (no separate persistence entity), but constrained at
the UI layer to at most one row per devotion: matched by **bundle id** (not language), and always
saved with the sentinel `languageCode` (follows the app-level default language setting). Once
favorited, a small reminders-only editor (iOS: `RemindersOnlyEditorView`; Android:
`RemindersOnlyEditorScreen`; Windows: `RemindersOnlyEditorPage`) is reachable from the row — it
shares its reminders-list UI with the full editor via one extracted component (iOS:
`RemindersSection`) rather than duplicating it. A devotion with traditional fixed prayer times
declares them in its manifest (`reminderPresetHours` + `reminderPresetFooter` — the Angelus's
6am/noon/6pm bells) and gets quick-toggle preset rows there; reminder notification bodies
likewise come from each manifest's `reminderBody`, not any hardcoded per-kind table.

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
- **`Images/`** — the 20 mystery paintings, the 14 Stations (Gebhard Fugel's 1921 Bad Saulgau
  Kreuzweg cycle), the 7 Sorrows (per-scene old masters), the Franciscan Crown's Adoration of the
  Magi (Murillo), the Divine Mercy image (Kazimirowski, 1934) — all public-domain classical art,
  every file an exact 1:1 square — plus ~10 override illustrations used by steps not tied to a
  specific mystery (`crucifix`, `our_father`, `glory_be`, `jesus_portrait`, `eternal_rest`,
  `madonna_and_child`, `st_michael`, `virtue_faith`/`virtue_hope`/`virtue_charity`) and
  `cross_placeholder` (a simple generated placeholder, not classical art). `Images/CREDITS.md`
  records artwork/museum/Commons-file/license per file; each platform's About screen carries the
  user-facing attributions. Devotion artwork ships *inside* the bundles (every platform prefers
  pack-provided image data over its asset catalog), so the per-platform asset copies now cover
  only the Rosary-and-shared set.

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

The **Rosary** is packaged this way as the one remaining **override bundle** — it is a hardcoded
`PrayerKind` devotion with its own engine builder, and its bundle only supplies translated
*text/artwork* that overrides the hardcoded fallback. At runtime, each platform's
`PrayerPackLoader` merges every loaded bundle's content into the existing
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

### Generic (bundle-driven) devotions

Every devotion except the Rosary and the Jesus Prayer is a **generic devotion**: Angelus,
Stations of the Cross, Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet, and Trisagion. A
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
  - `{"type": "rosary"}` — decade/bead-structured: `opening: [Entry…]` (entry 0 MUST be the Sign
    of the Cross — a bead-track invariant), `decades` (`ordinalNoun` "Joy"/"Sorrow"/"Decade";
    `announceMystery`; either inline `entries: [{imageKey, isScripture? = true}]` (Franciscan
    Crown/Seven Sorrows), *or* `count` + `fixedImageKey` (Divine Mercy), *or*
    `source: "mysteryGroups"` (the Rosary — the decade catalog comes from the engine's
    mystery-group machinery instead of bundle data); `majorStep`/`minorStep`
    `{title, bodyKey, imageKey?}` (the optional `imageKey` is the Rosary's fixed Our Father
    icon between mystery-specific images); `minorCount`; optional `postMinor: [Entry…]` emitted
    after each decade's minors carrying the decade's subtitle/index (the Rosary's Glory Be /
    Fatima Prayer / per-decade eternal rest, each gated with an `"if"`); optional
    `presenter: {combinedTitle, bodyKeys}` — when the gating `presenterMode` option is on, the
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
- **`manifest.json`** fields for a generic devotion: optional `builtinKind` ("rosary") marks a
  bundle whose devotion.json backs a dedicated `PrayerKind` rather than a generic `.custom`
  devotion — its definition loads, but the bundle stays out of `customDevotionIds()` so
  Home/Favorites don't list it twice; `accentColorHex` + optional
  `accentColorDarkHex` (light/dark pair), `iconSystemName` (an SF Symbol name; mapped to the
  nearest Material icon on Android and Segoe Fluent Icons glyph on Windows via a small fixed
  per-platform table), `displayNameByLanguage` (preserves e.g. the Hebrew devotion names),
  `reminderBody` (per-language notification body), and optional `reminderPresetHours` +
  `reminderPresetFooter` (the Angelus's traditional bell times).
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
- **Multi-day devotions (groundwork)** — `{"type": "days"}`: one step list per day
  (`days: [{name, nameByLanguage?, period?, steps: [Entry…]}]` — `period` carries the
  Montfort-style grouping labels), plus optional shared `opening`/`closing` prayed every day.
  Novenas are 9 entries; the de Montfort Total Consecration is 33 (12 preliminary days + three
  weeks + the consecration day). The schema, decoders, engines (shared opening + the day's
  steps + shared closing, with a clamped `dayIndex` seam), and validator all ship now;
  **deliberately not yet shipped**: per-favorite day progress (a
  `{startedOn, lastCompletedDay, lastCompletedOn}` JSON column on the stores + a
  session-completion hook to advance it + a day-picker UI) and any actual days-type bundle —
  those land together so the persistence isn't designed speculatively. Until then a days-type
  bundle prays day 1. Hours/missals are a different beast: their content is selected by the
  liturgical calendar (proper of the day, psalter weeks), not by a day counter — that needs a
  date→content-key resolution layer, for which the Home feast-day data (`Shared/content/data`)
  is the seed, and it should not be forced into the `days` shape.
- **Audio (groundwork)** — a bundle may ship narrated recordings of its devotion. An optional
  **`audio.json`** (declared separately from the structure, the same way catalog.json/options.json
  are) lists tracks: `{"tracks": [{id, language, file, variantId?, name?, nameByLanguage?,
  chapters: [{start, title | titleKey, stepIndex?}]}]}` — `id` unique within the bundle (what a
  future playback position would persist against); `language` one of the manifest's languages (a
  recording is in one language); `file` a bundle-relative path that must live under `audio/` and
  end in `.opus`; `variantId` names the steps-type variant the recording follows (a traditional
  vs. scriptural Stations recording differ); `name`/`nameByLanguage` follow the variant-naming
  convention (absent = platforms label by language). **Chapters** are the seek points: `start` in
  seconds (first chapter at 0, strictly increasing), `title` XOR `titleKey` per the step-entry
  convention (`titleKey` resolves through the track language's ordinary content chain), and an
  optional advisory `stepIndex` into the built default-options step sequence — advisory because
  the built sequence is option/calendar-dependent, so the future playback UI treats it as a hint
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
  never hold it in the load-time cache the way images are held). Playback itself is
  **deliberately not yet shipped** — the player UI/service, extract-to-cache for OS players,
  and chapter↔step syncing land together with the first real recordings (same rationale as the
  multi-day groundwork above). One platform note for that milestone: Android (ExoPlayer/
  MediaPlayer) and Windows (Media Foundation) decode Ogg Opus natively; iOS's AVFoundation does
  not, so the iOS player will decode via libopus or repackage into CAF (CoreAudio's Opus
  container) at load — the interchange format stays Ogg Opus regardless.
- **User-installed bundles**: anyone can author a `.prosaryprayer` and import it from the
  Favorites screen (file picker on all three platforms). `installPack` validates the file
  (readable zip; parseable manifest + devotion.json; content for every declared language; not a
  `builtinKind` pack; no id collision with anything loaded), copies it into a per-platform
  installed-packs directory (iOS Application Support/PrayerPacks, Android
  filesDir/prayerpacks, Windows LocalFolder/PrayerPacks), and loads it live. The directory is
  rescanned (sorted by filename) after the built-ins on every launch, so installs persist;
  id collisions are skipped so shipped devotions always win. Imported devotions get the same
  Favorites star row plus a remove affordance; `removeInstalledPack` deletes the file and
  unregisters the devotion (its merged text/images stay in memory until the next launch,
  harmlessly). This is the runtime half of the planned bundle-authoring webapp.
- **`bodyKey`/`titleKey` resolution** (`resolveBodyText`, per bundle): (1) the bundle's own raw
  content for the requested language; (2) the bundle's own **Latin** content (so a sentinel/
  unknown/undeclared language prays in Latin, never raw keys — the same convention as
  `PrayerTranslations.get`'s Latin fallback); (3) the ordinary `PrayerTranslations` chain for
  shared keys like `gloriaPatri`; (4) the raw key string as last resort.
  `MysteryTranslations.get` has the matching bundle-Latin step in its own chain, since the
  Sorrows/Magi texts live only in bundles. On Windows, `PrayerKey` is a set of string constants
  rather than a validating enum and every content key also merges into one global PascalCased
  override table, but `ResolveBodyText` follows the same per-bundle-raw-first chain.
- **Validation**: `Shared/tools/validate-devotion.py` (run by both packers) checks the schema per
  type, that every referenced key resolves in every manifest language (bundle content ∪ the
  surviving hardcoded `PrayerKey` set ∪ merged mystery keys, minus each bundle's explicit
  `validation-allowlist.json`), that imageKeys exist, and the rosary-type bead invariants. Each
  platform's `PrayerTranslationsCompletenessTests` mirrors the same checks against the
  actually-shipped packs and runtime merge, with the same explicit allowlists (currently: the
  Divine Mercy offering/petition in Hebrew; the Seven Sorrows closing in ar/he/ru/tl).
- **Discovery**: `customDevotionIds()` returns every loaded bundle id that has a
  `devotion.json`, **in pack-load order** — the display order everywhere. Home renders the Rosary
  card first, then one card per discovered bundle (title/accent/icon from the manifest), then the
  Jesus Prayer last; Favorites renders one star-row per bundle. Nothing in view code hardcodes a
  devotion name.
- **Flow UI**: one shared flow surface per platform (iOS `CustomDevotionFlowView`, Android
  `CustomDevotionFlowScreen`, Windows `CustomDevotionFlowPage`) renders every generic devotion,
  showing the same bead track as the Rosary whenever any built step carries a `decadeIndex` (the
  "rosary" type) and a plain progress bar otherwise. The bead track consumes only
  `decadeIndex`/`hailMaryIndexInDecade`/`isAntiphon`/`hasClosingCross`, which is why the
  devotion.json invariants above exist.

## Offline "Today" data (`Shared/data/`)

Two dev-time-generated datasets back the Home screen's "Today" section (per-platform physical
copies, same convention as the bundles; per-platform `TodayInfoStore` providers):

- **`feasts.json`** — a per-day sanctoral table (`days: {"YYYY-MM-DD": {title, rank}}`) for the
  generated years: the General Roman Calendar (fetched from the litcal API at generation time,
  movable feasts baked in per year — no computus or precedence logic ships in the app) overlaid
  with the Latin Patriarchate of Jerusalem's documented propers (Our Lady, Queen of Palestine and
  of the Holy Land — Oct 25, patronal solemnity; the Dedication of the Basilica of the Holy
  Sepulchre — Jul 15; Saint Mary of Jesus Crucified Baouardy — Aug 26). Ferial days have no
  entry.
- **`pope-intentions.json`** — the Pope's Worldwide Prayer Network monthly intentions
  (`months: {"YYYY-MM": {title, text}}`), from popesprayer.va.

A date/month outside the datasets returns nothing and the row simply hides — regenerating the
JSON (roughly yearly) is the only maintenance.

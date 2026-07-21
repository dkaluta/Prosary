# Android port instructions (for a future coding agent)

This document briefs an LLM coding agent tasked with porting this SwiftUI app (Prosary, iOS +
macOS) to Android using **Kotlin and modern Android features** (Jetpack Compose, Material3,
Navigation Compose, coroutines/Flow). Read this fully before writing any code, then read the
actual Swift source referenced throughout — this doc describes *what* to port and *how the pieces
map*, not a line-by-line spec.

## Ground rules

1. **Do not invent or re-translate prayer/Scripture text.** Every prayer and mystery description
   in every language already exists, written by the app's author — port it verbatim. It lives in
   `Prosary/Mocks/Content/*.swift` (see "Content" section below). Translating it yourself, even
   "improving" the wording, would silently corrupt liturgical text.
2. **Preserve the protocol/mock/stub architecture.** The backend (business logic + persistence)
   is intentionally not implemented on iOS either — see `Prosary/Protocols/`, `Prosary/Mocks/`,
   `Prosary/Support/Stubs/`. The Android port should have the same three-way split: interfaces,
   fully-working fake implementations (for previews/manual testing), and empty skeleton
   implementations (for the real backend, TBD by the app's author). Don't wire up real
   networking/persistence — that's out of scope here, same as on iOS.
3. **Verify by actually building and running**, not just reading code. After each major piece,
   run `./gradlew assembleDebug` (or build via Android Studio CLI) and, where feasible, launch on
   an emulator (`adb shell screencap` for screenshots) the same way the iOS port was verified —
   see git history / commit messages on this repo for the iOS verification approach if useful
   context.
4. Match the **visual and interaction design** already built on iOS (colors, typography pairing
   per language, bead progress indicator behavior, adaptive layout breakpoint) rather than
   redesigning from scratch — this is a port, not a reimagining. Deviate only where an iOS-specific
   affordance has no sane Android equivalent (see "Platform-specific notes" below).

## Suggested project setup

- Package/application ID: `app.prosary` (matches the `prosary.app` domain) or
  `com.dkaluta.prosary` (matches the iOS bundle ID `com.dkaluta.prosary`) — either is fine, pick
  one and be consistent.
- `minSdk` 26+ (Android 8.0). No legacy-device constraint was given; prefer a modern baseline over
  broad backward compatibility, matching the iOS port's choice of a recent-but-not-bleeding-edge
  baseline (iOS 17 / macOS 14).
- Jetpack Compose + Material3, Kotlin coroutines/Flow, Navigation Compose, no XML layouts.
- Suggested module/package layout, mirroring the Swift folder structure so the mapping stays
  obvious to future maintainers:

  ```
  app/src/main/java/.../prosary/
    model/            ← Prosary/Models/*.swift
    protocol/         ← Prosary/Protocols/*.swift (Kotlin interfaces)
    mock/             ← Prosary/Mocks/*.swift (fake implementations + content)
    mock/content/      ← Prosary/Mocks/Content/*.swift (ported prayer/Scripture text)
    stub/             ← Prosary/Support/Stubs/*.swift (empty skeletons)
    ui/screen/        ← Prosary/Views/*/*.swift (Composable screens)
    ui/component/     ← Prosary/Views/RosaryFlow/Bead*.swift (bead progress indicator)
    ui/theme/         ← Prosary/Assets.xcassets color sets, Typography/PrayerTypography.swift
  ```

## Models (`Prosary/Models/*.swift` → `model/`)

Straightforward one-to-one translation to Kotlin `data class`/`enum class`:

- `RosaryConfig` (data class, all `var` properties with defaults — Kotlin default parameter
  values work the same way) — note the `id` is a `UUID` on iOS; use `java.util.UUID` on Android.
- `RosaryStep` (data class) — the `imageKey` computed property (mystery image, else override key,
  else `"cross_placeholder"`) should become a Kotlin computed property (`val imageKey: String get()
  = ...`).
- `Mystery`, `MysteryGroup`, `MysterySelectionMode`, `EternalRestPlacement`,
  `MarianAntiphonOption` — enums with a `displayName`/label, same values, same ordinal-sensitive
  meaning where the iOS code switches on them exhaustively.
- `LanguageOption` / `LanguageCatalog`, `MysteryCatalog` — static data tables, port exactly
  (language codes `la`/`en`/`ar`/`he`, the 20 mysteries grouped Joyful/Sorrowful/Glorious/Luminous
  with their `imageKey` file stems).

## Protocols (`Prosary/Protocols/*.swift` → Kotlin `interface`s in `protocol/`)

- `RosaryEngine` — `fun buildSteps(config: RosaryConfig): List<RosaryStep>`.
- `PresetStore` — CRUD, `suspend fun` for each (Kotlin coroutines instead of Swift `async`):
  `all()`, `defaultPreset()`, `get(id: UUID)`, `save(config: RosaryConfig)`,
  `delete(config: RosaryConfig)`.
- `LiturgicalCalendarProviding` — `mysteryGroup(date)`, `seasonColor(date)` (return a Compose
  `Color`, not a hex string — same "UI just wires up whatever Color it's given" philosophy as
  iOS), `seasonalMarianAntiphon(date)`, plus "today" convenience overloads.

## Mocks (`Prosary/Mocks/*.swift` → `mock/`)

These are the fully-working implementations that make the app interactive without a real backend.
Port the logic faithfully:

- `MockRosaryEngine` (`Prosary/Mocks/MockRosaryEngine.swift`) — the step-building algorithm
  (opening prayers → per-mystery-group decades → closing prayers, with all the `RosaryConfig`
  toggles respected). This is real, tested logic — translate the control flow directly, don't
  redesign it.
- `MockPresetStore` (`Prosary/Mocks/MockPresetStore.swift`) — in-memory list, seeded with the same
  two sample presets ("Classic Rosary", "Evening Rosary for the Departed").
- `MockLiturgicalCalendar` (`Prosary/Mocks/MockLiturgicalCalendar.swift`) — weekday → mystery group
  mapping, liturgical season detection (Advent/Christmas/Lent/Easter/Ordinary Time) via the
  anonymous Gregorian Easter algorithm, season → accent color, season → seasonal antiphon. This is
  pure date math with no iOS-specific APIs — `java.time.LocalDate` maps directly onto the
  `Foundation.Calendar`/`DateOnly`-style logic used there.

### Content (`Prosary/Mocks/Content/*.swift` → `mock/content/`)

- `PrayerKey.swift` → Kotlin `enum class PrayerKey`.
- `PrayerTranslations.swift` + `PrayerTranslations+{Latin,English,Arabic,Hebrew}.swift` → a
  `Map<PrayerKey, String>` per language. **Copy the string literals verbatim** — these are real
  Latin/English/Arabic/Hebrew prayer texts, several with Right-to-Left (Arabic/Hebrew) content
  and Unicode niqqud (Hebrew vowel points). Do not run these through translation tooling; copy the
  UTF-8 text as-is from the `.swift` files.
- `MysteryText.swift`, `MysteryTranslations.swift` + per-language files → same pattern, keyed by
  mystery `imageKey` string instead of an enum. The Arabic mystery descriptions are currently
  being upgraded from short paraphrases to verbatim Jesuit Bible (الترجمة اليسوعية) quotations to
  match the other three languages' verbatim-Scripture approach — port whichever version is present
  at the time you do this work.

## Stubs (`Prosary/Support/Stubs/*.swift` → `stub/`)

Empty Kotlin implementations of the three interfaces above, each method simply doing
`TODO("Not implemented")` (Kotlin's stdlib `TODO()` is the direct equivalent of the Swift
`fatalError(...)` used here). These represent where the app's author will plug in real business
logic and persistence later — do not implement them.

## UI (`Prosary/Views/*/*.swift` → Compose screens in `ui/screen/`)

- **Home** (`Views/Home/HomeView.swift`) — app name, today's season-colored mystery badge, "Pray
  the Rosary" button, "My Presets" entry, About entry. On Android there's no Mac-style
  menu-bar-only convention to replicate — just always show an in-app About entry (see
  "Platform-specific notes").
- **Rosary flow** (`Views/RosaryFlow/RosaryFlowView.swift`) — mystery image, subtitle/header,
  prayer body text, Back/Next, progress bar, season-color banner. Adaptive layout: single column
  on compact width, a three-column layout (image / bead track / text) on expanded width — use
  `androidx.compose.material3.adaptive` / `WindowSizeClass` (`WindowWidthSizeClass.COMPACT` vs
  `.EXPANDED`) as the Compose equivalent of the iOS `horizontalSizeClass` check
  (`isWide: Bool { horizontalSizeClass == .regular }`).
- **Bead progress indicator** (`Views/RosaryFlow/BeadModels.swift`, `BeadProgressView.swift`,
  `BeadDotView.swift`, `CrossShape.swift`) — this went through several rounds of visual polish on
  iOS worth preserving exactly:
  - The layout is **pure UI-computed state** derived from the `RosaryStep` list + current index —
    not something the backend provides. Port `BeadLayout.build(...)` as a plain Kotlin function.
  - On expanded width, decades are grouped **one column per mystery group** (so a 15/20-mystery
    session grows wider, not awkwardly taller) rather than one long strip.
  - All bead-to-bead gaps (cross-to-decade, decade-to-decade, decade-to-antiphon) must use **one
    consistent spacing constant** — an earlier version mixed a parent-container spacing value with
    a per-bead padding value and the cross/antiphon ended up with visibly larger gaps than
    decade-to-decade, which read as "goofy". Keep it to a single spacing value applied uniformly
    (see `beadSpacing` in `BeadProgressView.swift`).
  - The opening/closing cross bead is a **hand-drawn shape** (`CrossShape.swift`), not a system
    icon glyph (Android's Material icon equivalent, e.g. an `Icons.Filled` cross-like glyph) — the
    SF Symbol version wasn't horizontally centered the same way a circle is, which threw off
    column alignment. Draw the cross directly (Compose `Canvas`/`Path`, exact same two-rectangle
    construction as `CrossShape.swift`) so it's centered by construction.
  - The minor (Hail Mary progress, 10 beads) group-of-5 marker adds extra space **only before**
    the 6th bead, not symmetrically on both sides of it (that looked like the bead was floating,
    isolated, rather than marking a clean group boundary).
- **Presets list + editor** (`Views/Presets/PresetsListView.swift`,
  `PresetEditorView.swift`) — list with Pray/Edit/Make Default/Delete actions; editor field order
  (top to bottom) is: Name, "use as default" toggle, Prayer Language, Which mysteries (mode picker
  + conditional specific-group picker), Apostles' Creed toggle, Opening Our Father & 3 Hail Marys
  toggle, Fatima Prayer toggle, Eternal rest placement picker, Marian antiphon picker, St. Michael
  Prayer toggle, Final Sign of the Cross toggle. Use Material3 `ExposedDropdownMenuBox` for the
  pickers.
- **About** (`Views/About/AboutView.swift`) — typeface/artwork/Scripture-source attributions,
  content ported verbatim (it's already factual, non-liturgical text — safe to copy directly).

### Typography (`Typography/PrayerTypography.swift` → `ui/theme/`)

Per-language, per-content-type (prayer vs. Scripture) serif font pairing:

| Language | Prayer text | Scripture text |
|---|---|---|
| Latin / English | System serif (iOS: "New York" design; **Android has no equivalent bundled serif** — substitute a bundled serif font, e.g. Noto Serif, or license/bundle a comparable classic serif) | Cardo (bundled, SIL OFL 1.1) |
| Hebrew | Frank Ruhl Libre (bundled, SIL OFL 1.1) | Shofar (bundled, GPL v2 + font-embedding exception) |
| Arabic | Amiri (bundled, SIL OFL 1.1) | Scheherazade New (bundled, SIL OFL 1.1) |

The four bundled non-Latin fonts (Frank Ruhl Libre, Shofar, Amiri, Scheherazade New) plus Cardo
are real font files already in this repo at `Prosary/Fonts/*.ttf` — copy them into
`app/src/main/res/font/` and declare a Compose `FontFamily` per typeface. Load via Android's
`Font(resId = ...)` / `FontFamily(...)`, analogous to the iOS `CTFontManagerRegisterFontsForURL`
runtime registration in `Support/FontRegistration.swift` (Android's resource-based font loading is
simpler — no runtime registration step needed).

### RTL (Arabic, Hebrew)

Android has robust built-in RTL support (`LayoutDirection.Rtl`), and Compose auto-mirrors most
layout primitives. Match the iOS behavior precisely: only the **prayer body text area** flips
reading direction based on the selected language — the surrounding chrome (progress bar, buttons,
bead track) stays LTR always. Wrap just that content in
`CompositionLocalProvider(LocalLayoutDirection provides ...)`.

### Colors / dark mode

iOS defines two adaptive color sets (`Assets.xcassets/BrandPrimary.colorset`,
`BrandHeadline.colorset`) with light/dark variants:

| Token | Light | Dark |
|---|---|---|
| Brand primary (buttons/links) | `#7A1F3D` | `#D8A8B5` |
| Brand headline text | `#4A0E23` | `#FFFFFF` |

Define these as Material3 theme colors (`lightColorScheme`/`darkColorScheme`) rather than
hardcoded hex, so the rest of the UI can just reference `MaterialTheme.colorScheme` — same
principle as the iOS side using named colors instead of inline hex everywhere.

### Navigation

iOS uses `NavigationStack` + a `AppRoute` enum (`rosary(configId)`, `presets`, `about`) pushed via
`.navigationDestination(for:)`. Use Navigation Compose (`NavHost`, a sealed class of routes) the
same way — one route per screen, the Rosary flow route taking a preset ID argument.

### App Intents (`Prosary/AppIntents/*.swift`)

iOS exposes "Pray the Rosary" and "Today's Mysteries" to Shortcuts/Siri/Spotlight via the
AppIntents framework. The nearest Android equivalents are **App Shortcuts**
(`ShortcutManagerCompat`, static/dynamic shortcuts surfaced via long-press on the launcher icon)
and, for voice/Assistant integration, **App Actions** (`shortcuts.xml` + `actions.xml` capability
bindings). This is a nice-to-have, not core to the port — implement after the core screens work.

### Accessibility

iOS marks the bead progress track as a single accessibility element with a spoken summary (e.g.
"Decade 2 of 5, Hail Mary 3 of 10") rather than exposing dozens of unlabeled dots, and hides the
purely-decorative mystery image from VoiceOver since the adjacent text already conveys the same
content (see `BeadProgressView.swift`'s `.accessibilityElement`/`.accessibilityLabel` and
`RosaryFlowView.swift`'s `.accessibilityHidden` on the image). Do the same for TalkBack: wrap the
bead row in `Modifier.clearAndSetSemantics { contentDescription = ... }` and mark the mystery image
`Modifier.semantics { invisibleToUser() }` (or equivalent).

## Platform-specific notes (where NOT to copy iOS 1:1)

- **About screen entry point.** On Mac, About is reachable *only* from the app's menu bar (native
  Mac convention); iPhone/iPad get an in-app button. Android has no menu-bar equivalent at all —
  just always show the in-app entry point, same as iOS's phone/tablet behavior.
- **Keyboard shortcut (Space → Next).** This was a Mac-only affordance (`.keyboardShortcut(.space)`
  gated to `#if os(macOS)`). Skip it on Android entirely, or reintroduce is only if targeting
  Chromebook/hardware-keyboard scenarios explicitly.
- **Window management (About-as-separate-window, quit-on-last-window-closed).** These are
  Mac-specific desktop-app conventions (`Window` scene, `NSApplicationDelegate`). Android has no
  multi-window desktop convention to match — a single-Activity app with Compose navigation is the
  right default.
- **Vision Pro / iPad "wide" layout reuse.** iOS deliberately reuses the same width-based
  adaptive layout logic across Mac, wide iPad, and Vision Pro (regular size class) rather than
  writing bespoke per-platform layouts. Do the equivalent on Android: drive layout off
  `WindowSizeClass`, not device type, so the same code naturally adapts across phone, tablet, and
  Chromebook/foldable.

## Suggested build order

1. Models + protocols + stubs (compiles, does nothing yet).
2. Mock content + mocks (ported logic, verifiable by writing a couple of quick unit tests against
   `MockRosaryEngine.buildSteps` — e.g. assert step count for a known config, matching the "1 of
   79" style totals visible in the iOS port's manual testing).
3. Typography + color theme.
4. Bead progress indicator (in isolation, via a Compose `@Preview`, before wiring into the full
   Rosary flow screen — this component went through the most visual iteration on iOS, so validate
   it on its own first).
5. Home → Rosary flow → Presets list/editor → About, in that order (mirrors the iOS build order).
6. Navigation wiring.
7. App Shortcuts (optional/stretch).
8. Accessibility pass.
9. Full build + manual run-through on an emulator (phone size *and* a tablet/foldable size, to
   exercise both the compact and expanded layouts) before considering the port done.

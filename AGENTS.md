# AGENTS.md

Guidance for AI coding agents (and the humans steering them) working in this repository.

## What this is

Prosary is a Catholic prayer app shipped as **three parallel native ports** plus a shared
content layer:

- `iOS/` — SwiftUI (iPhone/iPad/Mac; SwiftData for prayer presets)
- `Android/` — Kotlin + Jetpack Compose
- `Windows/` — WinUI 3 / C#
- `Shared/` — the canonical cross-platform documentation, JSON schema, datasets, tools,
  fonts, and images. Generated packs, datasets, and fonts are **physically copied** into each
  platform's tree — no platform references `Shared/` at build time. Prayer artwork is the
  exception: it lives once inside the copied `.prosaryprayer` packs and must not also be copied
  into native image catalogs/resource directories.

The deep documentation is `Shared/ARCHITECTURE.markdown` — read the relevant section before
touching a subsystem. The marketing site (Astro) lives in `Shared/website/` and has its own
`AGENTS.md`.

## The rule that matters most: three-way parity

The ports exist for feature parity. A feature or fix on one platform needs matching updates
on the other two **in the same change** — UI, strings, settings, data assets, and tests.
Cross-platform settings share key names verbatim (`defaultLanguageCode`,
`autoAdvanceSeconds`, `feastCalendarId`, `showTodayFeast`, `showTodayIntention`, …); keep
new ones identical on all three platforms.

## Git & releases

- Work on feature branches (`feature/<kebab-name>`); `main` is the release baseline and
  receives finished work via merge commits. CI (GitHub Actions) runs on every branch.
- Name new Markdown documents with the `.markdown` extension. Keep `.md` only when an exact
  conventional filename is required by tooling (for example `AGENTS.md` or `CLAUDE.md`).
- The root `LICENSE` covers every first-party part of Prosary: Apple, Android, Windows, web,
  shared data, documentation, tools, and assets. Link to that canonical file; do not add
  platform-specific license copies. Third-party material keeps its original license.
- Pushing `main` triggers the iOS Xcode Cloud pipeline. Android releases via
  `./gradlew publishReleaseBundle` (Play alpha); the Windows MSIX is built manually on a
  Windows machine. Don't push without being asked.
- Commit messages are a single plain-spoken, slightly poetic line describing the change —
  see `git log --oneline` and match the register.

## Build & test

- **Android**: `cd Android && ./gradlew testDebugUnitTest` — this is CI's bar. The full
  `gradlew build` currently fails on pre-existing `lintDebug` errors in older files; do not
  "fix" those inside an unrelated change.
- **iOS**: `cd iOS && xcodebuild test -scheme Prosary -destination
  'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled NO
  -only-testing:ProsaryTests`
  (`platform=macOS` also works and is faster).
- **Windows**: `dotnet test Windows/Prosary.Tests/Prosary.Tests.csproj -c Debug
  -p:Platform=x64` — needs Windows; on other hosts follow the existing patterns exactly and
  let CI verify.
- **Python** (`Shared/tools/`): every script is a self-contained uv script — run with
  `uv run --script <script>.py`, never bare `python3`.

## Shared data & schema

- `Shared/schema/*.json` documents the cross-platform shapes (screens, domain model,
  devotion content). Whenever a shape it covers changes on any platform, update the schema
  **in the same change**.
- `Shared/data/*.json` contains feast calendars, lectionary citations, and the manually
  maintained Pope intentions. Regenerate calendars with `Shared/tools/fetch-feasts.py`, readings
  with `Shared/tools/fetch-readings.py`, and use either script's `--sync` mode to copy canonical
  data into all three platform asset dirs. Never hand-edit the platform copies. The
  Evangelizo-backed Syriac table and the sourced Hebrew titles merged into
  `feasts-roman.json` cover a rolling ~3-month horizon — regenerate every couple of months.
- Devotions are data-driven `.prosaryprayer` bundles (`devotion.json` v2 + variants +
  options). Adding a devotion or a feast calendar is a data drop, not a new screen. Built-in
  packs stay byte-identical to `Shared/dist`; run
  `uv run --script Shared/tools/test-asset-deduplication.py` to check pack parity and ensure
  packed artwork has not acquired a duplicate native-resource copy.

## Localization & Hebrew

- Every user-facing string ships in English **and** Hebrew on all three platforms:
  - iOS: `iOS/Prosary/Localizable.xcstrings` (`en` + `he`; dotted keys with English
    `defaultValue` in code)
  - Android: `values/strings.xml` + `values-iw/strings.xml` (same key at the same position
    in both files)
  - Windows: `Strings/en-US/` + `Strings/he/` `Resources.resw` (XAML `x:Uid`, C#
    `Loc.Tr(key, englishFallback)`)
- Hebrew liturgical texts are transcribed from the St James Vicariate's printed prayer
  book. **Never machine-translate or invent liturgical Hebrew** — relay it from the print
  or from a credited source, or leave it out.
- Hebrew typography: יהוה always bare (no vowel points); ׳/״ for abbreviations only;
  quotation marks stay quotation marks.

## Platform conventions

- Windows ViewModels strictly use CommunityToolkit.Mvvm (`[ObservableProperty]` /
  `[RelayCommand]`) — no hand-rolled `INotifyPropertyChanged` or `ICommand`.
- iOS presets persist via SwiftData (`PresetEntry`): new columns must be raw
  String/Bool/Int — an enum-typed column aborts reading existing rows on device.
- Settings storage: `@AppStorage`/UserDefaults (iOS), the `AppSettings` object over
  SharedPreferences `"prosary_settings"` (Android), the static `AppSettings` over
  `ApplicationData.LocalSettings` (Windows).
- Attribution is load-bearing: the calendar datasets are used with required credit
  (Evangelizo.org — Daily Gospel, LitCal, Missale Meum) carried in every platform's About
  screen ("Calendar Data") — keep all three in sync when sources change.

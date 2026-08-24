# Prosary

A native WinUI3 (Windows App SDK) companion for praying the Rosary, the Angelus, the Stations
of the Cross, the chaplets, novenas, the Jesus Prayer, and every other devotion the
`.prosaryprayer` bundle format describes — the Windows port in the Prosary monorepo (see the
[repository README](../README.markdown)), kept at feature parity with the iOS app it mirrors.
Latin is the default prayer language, with English, Arabic, Hebrew (in the communities' own
rites), Russian, Tagalog, Spanish, Greek, and Classical Syriac as alternatives. Each bundle lists
the subset it actually supplies; most built-ins currently cover Latin, English, Arabic, Hebrew,
Russian, and Tagalog.

Built with plain WinUI3, not .NET MAUI — see the "Why not MAUI" note below. An earlier
standalone MAUI prototype (`irosary`, not part of this repo) was mined for its validated Rosary
engine, liturgical calendar algorithm, SQLite persistence pattern, and prayer/Scripture text in
four of the app's original six languages.

## Requirements

- Visual Studio 2022 with the "Windows application development" workload (or the Windows App SDK
  command-line tools), on Windows 10 19041+ or Windows 11
- .NET 10 SDK
- Windows x64 or ARM64 to run — this project cannot be built on macOS/Linux (WinUI3/Windows App
  SDK requires the real Windows toolchain; only NuGet restore of platform-agnostic packages works
  cross-platform)

## Why not MAUI

.NET MAUI on Windows compiles to WinUI3 under the hood anyway. Since this app targets Windows
only (no shared iOS/Android/MacCatalyst code — those already exist as separate native apps), MAUI's
cross-platform abstraction doesn't pay for itself here and only adds indirection plus Windows-
specific quirks. All of irosary's actually-reusable code — the Rosary engine, liturgical calendar
algorithm, SQLite repository, and every language's prayer text — is plain C#/.NET with zero MAUI
dependency, so none of that reuse was lost by going with plain WinUI3 instead.

## Building

Open `Prosary.sln` in Visual Studio and run the `Prosary` project (x64 or arm64), or from the
command line on Windows:

```
dotnet build Prosary.sln -p:Platform=x64
```

A signed MSIX package additionally needs the packaging certificate — see Signing below.

## Architecture

Mirrors iOS/Android's unified model: a `Prayer` (`Models/Prayer.cs`) is a saved,
user-configurable prayer session, discriminated by `PrayerKind`: the Rosary, the Jesus Prayer,
and `Custom` — every other devotion, driven entirely by a `.prosaryprayer` bundle (see
`../Shared/ARCHITECTURE.md`). ViewModels strictly use CommunityToolkit.Mvvm
(`[ObservableProperty]`/`[RelayCommand]` — no hand-rolled `INotifyPropertyChanged`).

- `Services/PrayerEngine.cs` — builds Rosary sessions and every bundle-driven devotion, reading
  bundles through `Localization/PrayerPackStore.cs`; the Jesus Prayer is a separate counter.
- `Services/LiturgicalCalendarService.cs` — today's mystery group, season, seasonal Marian
  antiphon, Easter-season check; ported from irosary's `LiturgicalCalendarService.cs`.
- `Persistence/SqlitePresetStore.cs` — SQLite-backed (`sqlite-net-pcl`) saved-configuration store, with
  reminders stored as a JSON column; per-kind default/delete scoping (a correction over irosary's
  unscoped version, matching iOS/Android's actual behavior).
- `Services/WindowsReminderScheduler.cs` — local reminder notifications via
  `Windows.UI.Notifications.ScheduledToastNotification`, implemented as a rolling window of
  pre-scheduled daily instances (Windows has no native "repeat daily" flag), topped up on every
  app launch.
- `Navigation/Router.cs` — thin wrapper over the root `Frame`'s typed navigation; WinUI3's
  equivalent of Shell routing, since plain WinUI3 has no Shell.
- `MainWindow.xaml(.cs)` — a Fluent-style extended title bar (`ExtendsContentIntoTitleBar` +
  `SetTitleBar`, Mica `BaseAlt` backdrop) instead of the default opaque OS title bar, matching
  contemporary Windows 11 app chrome. The `MicaKind.BaseAlt` choice (vs. plain `Base`) is
  Microsoft's documented recommendation for extended-title-bar windows specifically, but hasn't
  been eyeballed on a real build from this (non-Windows) environment — worth a look on first run.

## Signing

The MSIX package is signed with a self-signed certificate kept out of git entirely
(`keystore/Prosary_TemporaryKey.pfx`, `keystore/keystore.properties` — see `.gitignore`).
`Prosary.csproj`'s `PackageCertificateKeyFile` points at it. To regenerate:

```
openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout key.key -out cert.crt \
  -subj "/CN=David Kaluta" \
  -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning"
openssl pkcs12 -export -out keystore/Prosary_TemporaryKey.pfx -inkey key.key -in cert.crt
```

The certificate's `CN` must exactly match `Package.appxmanifest`'s `Identity/@Publisher`. Back
this certificate up somewhere safe — losing it means every future build gets a new, differently-
signed identity, which Windows treats as a different app for update purposes.

## Shared assets

Bundled prayer typefaces and the mystery/prayer illustration images under `Prosary/Assets/Fonts`
and `Prosary/Assets/Images` are physical copies of the canonical originals in `../Shared/` (a
sibling directory to `iOS`/`Android`/`Windows` — see `../Shared/README.md` for what lives there
and why). Each platform keeps its own physical copy rather than referencing `Shared/` at build
time; if you update an image or font, update `Shared/` and re-copy it into each platform that uses
it. Placeholder tile/splash
icons (generated to match the app's brand gradient/cross, lower-fidelity than the real launcher
art on iOS/Android) live in `Prosary/Assets/` directly too — swap those for real icon assets
before any real distribution.

## Tests

`Prosary.Tests` (xUnit) covers the algorithmic core end to end from a plain test host — no
Windows App SDK/UI dependency needed for any of it. The load-bearing suites:

- `CustomDevotionEngineTests` — the generic engine against the real shipped bundles, per
  devotion, per language, rites and variants included (the step sequences are pinned).
- `PrayerPackLoaderTests` — bundle parsing, install validation, the per-key fallback chain.
- `LiturgicalCalendarServiceTests` — the Meeus/Jones/Butcher Easter calculation against known
  public Easter dates, weekday/Sunday mystery-group assignment, season colors, seasonal Marian
  antiphon.
- `SqlitePresetStoreTests` — favorites persistence; saving/deleting a default favorite of one
  `PrayerKind` must never touch another kind's default. Each test runs against its own temp
  SQLite file.
- Plus bead layout, multi-day runs, audio position rules, translation completeness, repository
  client, and legacy-kind migration suites.

Run with `dotnet test Prosary.sln` (Windows only, same constraint as building the app itself).

## License

The app's original source code is licensed under the BSD 2-Clause License — see [LICENSE](LICENSE),
matching the iOS and Android apps. Bundled third-party typefaces retain their own separate
licenses — see `Prosary/Assets/Fonts/ATTRIBUTIONS.md`.

# Prosary

A native WinUI3 (Windows App SDK) companion for praying the Rosary, the Angelus, and the Jesus
Prayer — a Windows port of [dkaluta/Prosary-iOS](https://github.com/dkaluta/Prosary-iOS) (also
ported to [dkaluta/Prosary-Android](https://github.com/dkaluta/Prosary-Android)), serving Holy
Land Christian communities. Latin is the default prayer language, with English, Arabic, Hebrew,
Russian, and Tagalog (Arabic and Hebrew right-to-left) as alternatives.

Built with plain WinUI3, not .NET MAUI — see the "Why not MAUI" note below. An earlier standalone
MAUI prototype, [`irosary`](../../irosary), was mined for its validated Rosary engine, liturgical
calendar algorithm, SQLite persistence pattern, and prayer/Scripture text in 4 of the current
app's 6 languages.

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

Mirrors iOS/Android's unified model: a `Prayer` (`Models/Prayer.cs`) is a saved, user-configurable
prayer session — a Rosary, the Angelus, or the Jesus Prayer — discriminated by `PrayerKind`, each
with its own nested options (`RosaryOptions`, `JesusPrayerOptions`; the Angelus needs none beyond
a language).

- `Services/RosaryEngine.cs` / `AngelusEngine.cs` — build the ordered prayer-step sequence for
  each devotion, ported from irosary's `RosaryEngine.cs` (Rosary) and iOS's `StubAngelusEngine.swift`
  (Angelus, no irosary precedent).
- `Services/LiturgicalCalendarService.cs` — today's mystery group, season, seasonal Marian
  antiphon, Easter-season check; ported from irosary's `LiturgicalCalendarService.cs`.
- `Persistence/SqlitePresetStore.cs` — SQLite-backed (`sqlite-net-pcl`) favorites store, with
  reminders stored as a JSON column; per-kind default/delete scoping (a correction over irosary's
  unscoped version, matching iOS/Android's actual behavior).
- `Services/WindowsReminderScheduler.cs` — local reminder notifications via
  `Windows.UI.Notifications.ScheduledToastNotification`, implemented as a rolling window of
  pre-scheduled daily instances (Windows has no native "repeat daily" flag), topped up on every
  app launch.
- `Navigation/Router.cs` — thin wrapper over the root `Frame`'s typed navigation; WinUI3's
  equivalent of Shell routing, since plain WinUI3 has no Shell.

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

## Store assets

Placeholder tile/splash images live in `Prosary/Assets/` (generated to match the app's actual
brand gradient/cross, but lower-fidelity than the real launcher art on iOS/Android) — swap these
for the real icon assets before any real distribution.

## Tests

(Planned, not yet written — see the project plan for scope: `RosaryEngine`/`AngelusEngine`/
`LiturgicalCalendarService` unit tests, plus `SqlitePresetStore`'s per-kind default/delete
scoping specifically.)

## License

The app's original source code is licensed under the BSD 2-Clause License — see [LICENSE](LICENSE),
matching the iOS and Android apps. Bundled third-party typefaces retain their own separate
licenses — see `Prosary/Assets/Fonts/ATTRIBUTIONS.md`.

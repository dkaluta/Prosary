# Prosary

A SwiftUI multiplatform (iPhone + Mac, iPad and Vision Pro along for the ride) companion for
praying the Rosary, the Angelus, the Stations of the Cross, the Divine Mercy Chaplet, novenas,
the Jesus Prayer, and every other devotion the `.prosaryprayer` bundle format can describe —
serving Holy Land Christian communities. Latin is the default prayer language, with English,
Arabic, Hebrew (in the communities' own rites), Russian, Tagalog, Spanish, Greek, and Classical
Syriac as alternatives. Each bundle lists the subset it actually supplies; most built-ins
currently cover Latin, English, Arabic, Hebrew, Russian, and Tagalog.

This is the iOS/Mac app of a monorepo — the Android and Windows ports, the shared bundle
format, and the web tools live beside it; see the [repository README](../README.markdown).
The apps are in closed testing — see [prosary.app](https://prosary.app) to join.

## Requirements

- Xcode 26+
- iOS 17 / macOS 14 / visionOS 1 minimum deployment target

## Building

Open `Prosary.xcodeproj` and run the `Prosary` scheme on an iOS Simulator, "My Mac", or Vision Pro
destination.

The Mac target keeps its macOS 14 deployment floor and explicitly declines UI compatibility mode.
Build it with Xcode 27 to review the exact macOS 27 appearance; SwiftUI's standard window, sidebar,
toolbar, controls, and Liquid Glass styles then adopt the current system design automatically.

## iCloud Sync

Saved configurations (`PresetEntry`, via SwiftData) sync across a user's devices through CloudKit's
private database — `Prosary/Prosary.entitlements` declares the `iCloud.com.dkaluta.prosary`
container, and `AppServices.modelContainer` builds its `ModelConfiguration` with
`cloudKitDatabase: .automatic`, falling back to a local-only store if iCloud is unavailable
(signed out, disabled for this app, or offline) rather than crashing at launch.

The first CloudKit-enabled build on a developer machine may prompt Xcode to repair signing and
create a provisioning profile for the container. Accept that prompt once; ordinary builds do not
need to repeat it.

## Architecture

A `Prayer` (`Models/Prayer.swift`) is a saved, user-configurable prayer session, discriminated
by `PrayerKind`: the Rosary, the Jesus Prayer, and `custom` — every other devotion, driven
entirely by a `.prosaryprayer` bundle (see `Shared/ARCHITECTURE.markdown`). New devotions are new
bundles, not new code.

`Support/PrayerEngine.swift` builds Rosary sessions and every bundle-driven devotion;
`Support/PrayerPack/PrayerPackLoader.swift` supplies the parsed bundle content. The Jesus Prayer
is a separate tap counter and needs no step engine. The UI is built
against two protocols in `Prosary/Protocols/`:

- `PresetStore` — CRUD over saved `Prayer` configurations. Older source directories still use
  `Favorites`; the current UI calls these presets or saved configurations.
- `LiturgicalCalendarProviding` — today's mystery group, season accent color, seasonal antiphon,
  Easter-season and Lent checks.

(The Jesus Prayer needs no engine — it's just a tap counter toward a target, modeled directly by
`JesusPrayerOptions`/`JesusPrayerProgress`.)

`Prosary/Support/Stubs/` holds the real, production implementations of each protocol —
`StubLiturgicalCalendar` is the actual liturgical-calendar algorithm, and `StubPresetStore`
delegates to `Support/SwiftData/SwiftDataPresetStore`, which persists every `Prayer` via
SwiftData. (The "Stub" name is a holdover from before this was real — see `Prosary/Mocks/`
below.)

`Prosary/Mocks/` holds Preview/test doubles — `MockPresetStore` is a real in-memory
`PresetStore` seeded with sample favorites, since Previews shouldn't touch SwiftData.
`Mocks/Content/` holds the shared prayer/mystery tables the bundles' per-key fallback chain
ends in, in every prayer language.

`AppServices.shared` wires the `Stub*` implementations together (plus the shared `ModelContainer`
for persistence) and is read by every view through the protocols above — nothing downstream needs
to change if the backing implementation does.

Reminders are local notifications, not part of the protocol/Stub split: `Support/ReminderScheduler.swift`
wraps `UNUserNotificationCenter`, scheduling one repeating daily notification per enabled
`PrayerReminder` on a `Prayer`, with a per-`PrayerKind` message.

Other notable pieces:

- `Views/RosaryFlow/BeadModels.swift` — computes the two-part bead progress indicator (major
  beads track + minor Hail-Mary beads) from a `RosaryStep` array and the current index; purely
  derived UI state, not something the backend provides.
- `Typography/PrayerTypography.swift` — resolves the serif typeface per language and
  prayer/Scripture content type.
- `AppIntents/` — Shortcuts/Siri/Spotlight support ("Pray the Rosary", "Today's Mysteries").

## Assets

Fonts, mystery illustrations, and other artwork are bundled with their original third-party
licenses intact — see the in-app About screen (Mac: **Prosary → About Prosary** in the app menu;
iPhone/iPad: the About button on the Pray tab), implemented in `Views/About/AboutView.swift`,
for full attribution.

## Website

An Astro + TypeScript landing page for `https://prosary.app` lives in
[`../Shared/website/`](../Shared/website/), auto-deployed to GitHub Pages on push — see its
[README](../Shared/website/README.markdown)
for local dev, deployment, and DNS setup. The site links to the TestFlight beta and the Android
closed test, and hosts the shared privacy policy and repository-wide license pages for all native
apps and web projects.

## License

All original Prosary material is licensed under the repository-wide BSD 2-Clause License — see
[LICENSE](../LICENSE). Third-party material retains its original license.

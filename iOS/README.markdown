# Prosary

A SwiftUI multiplatform (iPhone + Mac, iPad and Vision Pro along for the ride) companion for
praying the Rosary, the Angelus, the Stations of the Cross, the Divine Mercy Chaplet, novenas,
the Jesus Prayer, and every other devotion the `.prosaryprayer` bundle format can describe —
serving Holy Land Christian communities. Latin is the default prayer language, with English,
Arabic, Hebrew (in the communities' own rites), Russian, Tagalog, Spanish, Greek, and Classical
Syriac as alternatives.

This is the iOS/Mac app of a monorepo — the Android and Windows ports, the shared bundle
format, and the web tools live beside it; see the [repository README](../README.markdown).
The apps are in closed testing — see [prosary.app](https://prosary.app) to join.

## Requirements

- Xcode 26+
- iOS 17 / macOS 14 / visionOS 1 minimum deployment target

## Building

Open `Prosary.xcodeproj` and run the `Prosary` scheme on an iOS Simulator, "My Mac", or Vision Pro
destination.

## iCloud Sync

Saved favorites (`PresetEntry`, via SwiftData) sync across a user's devices through CloudKit's
private database — `Prosary/Prosary.entitlements` declares the `iCloud.com.dkaluta.prosary`
container, and `AppServices.modelContainer` builds its `ModelConfiguration` with
`cloudKitDatabase: .automatic`, falling back to a local-only store if iCloud is unavailable
(signed out, disabled for this app, or offline) rather than crashing at launch.

**First build after pulling this change**: opening the project in Xcode will prompt to fix a
signing issue, since the CloudKit capability needs a provisioning profile that doesn't exist yet —
accept the prompt once (Xcode registers the container against your Apple Developer account and
regenerates the profile automatically). This is a one-time step per developer machine, not
something a normal build needs afterward.

## Architecture

A `Prayer` (`Models/Prayer.swift`) is a saved, user-configurable prayer session, discriminated
by `PrayerKind`: the Rosary, the Jesus Prayer, and `custom` — every other devotion, driven
entirely by a `.prosaryprayer` bundle (see `Shared/ARCHITECTURE.md`). New devotions are new
bundles, not new code.

The UI is built entirely against four protocols in `Prosary/Protocols/`:

- `RosaryEngine` — turns a `Prayer` into an ordered sequence of Rosary steps.
- `AngelusEngine` — turns a language code into an ordered sequence of Angelus steps.
- `PresetStore` — CRUD over saved `Prayer`s (the UI calls these "favorites"; the protocol name
  and the underlying SwiftData model class, `PresetEntry`, predate that renaming).
- `LiturgicalCalendarProviding` — today's mystery group, season accent color, seasonal antiphon,
  Easter-season check.

(The Jesus Prayer needs no engine — it's just a tap counter toward a target, modeled directly by
`JesusPrayerOptions`/`JesusPrayerProgress`.)

`Prosary/Support/Stubs/` holds the real, production implementations of each protocol —
`StubRosaryEngine`, `StubAngelusEngine`, and `StubLiturgicalCalendar` contain the actual prayer-
building and liturgical-calendar algorithms, and `StubPresetStore` delegates to
`Support/SwiftData/SwiftDataPresetStore`, which persists every `Prayer` via SwiftData. (The
"Stub" name is a holdover from before this was real — see `Prosary/Mocks/` below.)

`Prosary/Mocks/` holds thin wrappers around the `Stub*` types, used only in SwiftUI Previews and
unit tests — except `MockPresetStore`, which is a real in-memory `PresetStore` seeded with sample
favorites, since Previews shouldn't touch SwiftData. `Mocks/Content/` holds the ported
prayer/mystery text for all six languages, read by both the Stub and Mock engines.

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
iPhone/iPad: the About button on the Home screen), implemented in `Views/About/AboutView.swift`,
for full attribution.

## Website

An Astro + TypeScript landing page for `https://prosary.app` lives in
[`../Shared/website/`](../Shared/website/), auto-deployed to GitHub Pages on push — see its
[README](../Shared/website/README.markdown)
for local dev, deployment, and DNS setup. The site links to the TestFlight beta and the Android
closed test, and hosts the shared privacy policy and license pages for both apps.

## License

The app's original source code is licensed under the BSD 2-Clause License — see [LICENSE](LICENSE).
Bundled third-party assets retain their own separate licenses.

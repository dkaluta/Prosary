# Prosary

A SwiftUI multiplatform (iPhone + Mac, iPad and Vision Pro along for the ride) companion for
praying the Rosary and other Catholic devotions, serving Holy Land Christian communities. Latin
is the default prayer language, with English, Arabic, and Hebrew (right-to-left) as alternatives.

## Requirements

- Xcode 26+
- iOS 17 / macOS 14 minimum deployment target

## Building

Open `Prosary.xcodeproj` and run the `Prosary` scheme on an iOS Simulator or "My Mac" destination.

## Architecture

The backend — data models, prayer-flow business logic, persistence, and all prayer/Scripture
text — is intentionally **not implemented** here. The UI is built entirely against three
protocols in `Prosary/Protocols/`:

- `RosaryEngine` — turns a saved preset into an ordered sequence of prayer steps.
- `PresetStore` — CRUD for saved presets.
- `LiturgicalCalendarProviding` — today's mystery group, season accent color, seasonal antiphon.

`Prosary/Support/Stubs/` holds skeleton implementations of each protocol (`Stub*`) meant to be
replaced with real logic and real persistence.

`Prosary/Mocks/` holds fully-working implementations (`Mock*`) built on ported prayer/Scripture
content in `Mocks/Content/`, wired in by default via `AppServices.shared` so the app is fully
interactive today. Swap the `AppServices.shared` initializer to point at the `Stub*`
implementations once your real backend is ready — every view reads only through the protocols
above, so nothing downstream needs to change.

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

An Astro + TypeScript landing page skeleton for `https://prosary.app` lives in
[`website/`](website/), auto-deployed to GitHub Pages on push — see
[`website/README.markdown`](website/README.markdown) for local dev, deployment, and DNS setup.

## Future Android port

[`ANDROID_PORT.markdown`](ANDROID_PORT.markdown) briefs a future coding agent on porting this app
to Kotlin/Jetpack Compose, mapping the existing architecture and flagging iOS-specific details
worth preserving (or deliberately not copying) on Android.

## License

The app's original source code is licensed under the BSD 2-Clause License — see [LICENSE](LICENSE).
Bundled third-party assets retain their own separate licenses.

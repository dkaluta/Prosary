# Prosary

A Jetpack Compose companion for praying the Rosary, the Angelus, and the Jesus Prayer — an
Android port of [dkaluta/Prosary-iOS](https://github.com/dkaluta/Prosary-iOS), serving Holy Land
Christian communities. Latin is the default prayer language, with English, Arabic, Hebrew,
Russian, and Tagalog (Arabic and Hebrew right-to-left) as alternatives.

The app is currently in Play Store internal testing — see [prosary.app](https://prosary.app) to
join, or email mail@dkaluta.com to be added to the tester list.

## Requirements

- Android Studio (AGP 9, built-in Kotlin support)
- JDK 21
- minSdk 24, targetSdk / compileSdk 36

## Building

Open the project root in Android Studio and run the `app` configuration, or from the command line:

```
./gradlew :app:installDebug
```

A signed release build additionally needs an upload keystore. See [Signing](#signing) below.

## Architecture

A `Prayer` (`models/Prayer.kt`) is a saved, user-configurable prayer session — a Rosary, the
Angelus, or the Jesus Prayer — discriminated by `PrayerKind`, each with its own nested options
(`RosaryOptions`, `JesusPrayerOptions`; the Angelus needs none beyond a language). This mirrors
the iOS app's model exactly, so the two stay in lockstep as devotions are added.

Unlike iOS's protocol/Stub/Mock split, the `Mock*` engines here (`engine/MockRosaryEngine.kt`,
`engine/MockAngelusEngine.kt`, `calendar/MockLiturgicalCalendar.kt`) are wired directly into
`services/AppServices.kt` as the sole, real implementation — there's no separate "production"
layer to swap in later. (The Jesus Prayer needs no engine — it's just a tap counter toward a
target, modeled directly by `JesusPrayerOptions`/`JesusPrayerProgress`.)

Persistence is Room, not SwiftData: `persistence/PresetEntity.kt` is the `@Entity`, with reminders
stored as a JSON string (`org.json`, no extra dependency); `persistence/RoomPresetStore.kt`
implements `presets/PresetStore.kt` against it, seeding one "Classic Rosary" favorite on first
launch. `services/AppServices.kt` owns the single `AppDatabase`.

Reminders are local notifications, scheduled with `AlarmManager` rather than iOS's
`UNUserNotificationCenter`: `reminders/ReminderScheduler.kt` sets one daily repeating alarm per
enabled `PrayerReminder` on a `Prayer`, `reminders/ReminderBroadcastReceiver.kt` posts the
notification when it fires, and `reminders/BootReceiver.kt` re-schedules everything after a
reboot, since (unlike iOS) `AlarmManager` alarms don't survive one.

Other notable pieces:

- `ui/rosaryflow/BeadModels.kt` / `BeadProgressView.kt` — the two-part bead progress indicator
  (major beads track + minor Hail-Mary beads), computed from the current step list and index;
  mirrors iOS's `BeadModels.swift`.
- `typography/PrayerTypography.kt` — resolves the serif typeface per language and
  prayer/Scripture content type.

## Signing

Release builds are signed with an upload keystore kept out of git entirely
(`keystore/keystore.properties`, `keystore/*.keystore` — see `.gitignore`). `app/build.gradle.kts`
reads it if present and falls back to an unsigned release build otherwise, so a fresh clone still
builds without it. To generate one:

```
keytool -genkeypair -v -keystore keystore/prosary-upload.keystore -storetype PKCS12 \
  -alias prosary-upload -keyalg RSA -keysize 2048 -validity 10000
```

then write `keystore/keystore.properties` with `storeFile`, `storePassword`, `keyAlias`, and
`keyPassword`. Back this keystore up somewhere safe — losing it means going through Google's
account-recovery process to reset the upload key.

## Store assets

`store-assets/` holds the Play Store hi-res icon, feature graphic, phone/tablet screenshots, and
draft listing copy — see `store-assets/listing.md`.

## Tests

Unit tests (`app/src/test/`) cover the engines, calendar, models, and preset store; instrumented
tests (`app/src/androidTest/`) cover the Angelus and Jesus Prayer flows end-to-end on a device or
emulator.

```
./gradlew :app:testDebugUnitTest
./gradlew :app:connectedDebugAndroidTest
```

## License

The app's original source code is licensed under the BSD 2-Clause License — see [LICENSE](LICENSE),
matching the iOS app's. Bundled third-party assets retain their own separate licenses — see the
in-app About screen for details.

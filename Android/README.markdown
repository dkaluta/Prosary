# Prosary

A Jetpack Compose companion for praying the Rosary, the Angelus, the Stations of the Cross,
the chaplets, novenas, the Jesus Prayer, and every other devotion the `.prosaryprayer` bundle
format describes — the Android port in the Prosary monorepo (see the
[repository README](../README.markdown)), kept at feature parity with the iOS app it mirrors.
Latin is the default prayer language, with English, Arabic, Hebrew (in the communities' own
rites), Russian, Tagalog, Spanish, Greek, and Classical Syriac as alternatives. Each bundle lists
the subset it actually supplies; most built-ins currently cover Latin, English, Arabic, Hebrew,
Russian, and Tagalog.

The app is currently in Play Store closed testing — see [prosary.app](https://prosary.app) or
[the Play Store listing](https://play.google.com/store/apps/details?id=com.dkaluta.prosary) to
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

A `Prayer` (`models/Prayer.kt`) is a saved, user-configurable prayer session, discriminated by
`PrayerKind`: the Rosary, the Jesus Prayer, and `Custom` — every other devotion, driven
entirely by a `.prosaryprayer` bundle (see `../Shared/ARCHITECTURE.markdown`). New devotions are new
bundles, not new code. `engine/PrayerEngine.kt` builds Rosary sessions and every bundle-driven
devotion, reading bundles through `content/prayerpack/PrayerPackLoader.kt`; the Jesus Prayer is a
separate tap counter modeled directly by `JesusPrayerOptions`/`JesusPrayerProgress`.

Persistence is Room, not SwiftData: `persistence/PresetEntity.kt` is the `@Entity`, with reminders
stored as a JSON string (`org.json`, no extra dependency); `persistence/RoomPresetStore.kt`
implements `presets/PresetStore.kt` against it, seeding one "Classic Rosary" configuration on first
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
draft listing copy — see `store-assets/listing.markdown`.

## Tests

Unit tests (`app/src/test/`) cover the generic devotion engine against the real shipped
bundles, the calendar, the pack loader, models, and the preset store; instrumented tests
(`app/src/androidTest/`) cover flows end-to-end on a device or emulator.

```
./gradlew :app:testDebugUnitTest
./gradlew :app:connectedDebugAndroidTest
```

## License

All original Prosary material is licensed under the repository-wide BSD 2-Clause License — see
[LICENSE](../LICENSE). Third-party material retains its original license — see the in-app About
screen for details.

# Privacy Policy for Prosary

**Last updated:** 2026-08-24

Prosary is a Catholic prayer companion app for the Rosary, chaplets, novenas, and other
devotions. This policy covers the Android app. The full policy covering the apps and Prosary's
web services is published at [prosary.app/privacy](https://prosary.app/privacy).

## Data collection

The Android app has no account, sign-in, analytics, crash-reporting, advertising, or tracking
SDK. Your saved prayer configurations, reminder times, settings, progress, and installed devotion
bundles are stored by the app on your device.

The optional Browse and Search features fetch the public catalog from prayers.prosary.app and
download only the devotion bundles you choose to install. As with any web request, the hosting
provider processes technical request information such as an IP address to serve it. A download
increments an anonymous aggregate counter for that bundle; the app sends no Prosary account,
advertising identifier, saved prayer, reminder, or other personal profile.

Android's operating-system backup or device-transfer service may copy local app data according to
the backup settings of your Google account and device. Prosary does not operate or have access to
that backup service.

## Notifications

Prayer reminders you configure are scheduled locally on your device using Android's
`AlarmManager` and shown using local notifications. No reminder data ever leaves your device.

## Permissions

- **Notifications** (`POST_NOTIFICATIONS`): used only to show the prayer reminders you configure.
- **Receive boot completed** (`RECEIVE_BOOT_COMPLETED`): used only to re-schedule your existing
  reminders after your device restarts, since Android clears scheduled alarms on reboot.
- **Internet** (`INTERNET`): used only to browse, search, and download public community devotion
  bundles from prayers.prosary.app.

No permission is used for analytics, advertising, or tracking.

## Changes to this policy

If this policy changes, the "Last updated" date above will change accordingly.

## Contact

Questions about this policy can be sent to mail@dkaluta.com.

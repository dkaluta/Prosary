# Privacy Policy for Prosary

**Last updated:** 2026-07-25

Prosary is a Catholic prayer companion app (Rosary, Angelus, and the Jesus Prayer). This policy
covers the Android app.

## Data collection

Prosary does not collect, transmit, or share any personal data. Specifically:

- The app has no network access — it does not request the Android `INTERNET` permission, and it
  is not capable of sending or receiving data over the internet.
- There are no accounts, sign-in, analytics, crash reporting, advertising, or third-party SDKs.
- Your saved prayer favorites and reminder times are stored only in a local database on your
  device (using Android's Room persistence library) and are never uploaded anywhere.

## Notifications

Prayer reminders you configure are scheduled locally on your device using Android's
`AlarmManager` and shown using local notifications. No reminder data ever leaves your device.

## Permissions

- **Notifications** (`POST_NOTIFICATIONS`): used only to show the prayer reminders you configure.
- **Receive boot completed** (`RECEIVE_BOOT_COMPLETED`): used only to re-schedule your existing
  reminders after your device restarts, since Android clears scheduled alarms on reboot.

Neither permission is used to collect or transmit data.

## Changes to this policy

If this policy changes, the "Last updated" date above will change accordingly.

## Contact

Questions about this policy can be sent to mail@dkaluta.com.

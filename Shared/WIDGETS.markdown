# Prosary widgets

Prosary offers **Today** and **Saved Prayer** widgets on iPhone/iPad, Android, and Mac.
Today brings the selected calendar's feast and reading citations to the home screen or
desktop, with a shortcut to today's Rosary. Saved Prayer opens a specific saved configuration
and shows its valid unfinished position. A widget opens the normal prayer flow; it does not
advance prayers or mark a day complete in the background.

This feature's platform scope is iOS, Android, and macOS. Native Windows widgets are outside
this implementation. The saved `Prayer`, authored packs, calendar datasets, and existing
Windows data keep their cross-platform contracts. The machine-readable companion
is [schema/widgets.json](schema/widgets.json).

Apple supports small, medium, and large widgets on iOS 17+/macOS 14+, plus rectangular
Lock Screen widgets on iOS. The Today Rosary shortcut appears in the medium and large
Apple layouts; the small and Lock Screen layouts open Today. Android uses resizable native
home-screen widgets with a 3-by-2-cell default. Launcher grids can round their dimensions.

## Today

The widget uses the current local civil date, independently of any date being browsed in
the app. It uses the existing offline calendar registry and generated datasets:

- `feastCalendarId` selects both the feast and the appointed readings. A missing reading
  file or date leaves readings unavailable; another rite's readings must never substitute.
- `easternPaschaStyle` retains the app's selected Julian/Gregorian Pascha behavior for
  calendars that support it.
- `showTodayFeast`, `showTodayIntention`, and `showTodayTorahPortion` control their existing
  optional rows. Their defaults remain true, true, and false. Available space determines
  how much of an enabled row is visible. Turning a row off removes it from widget content.
- The interface language controls Today text. It is independent of `defaultLanguageCode`
  and saved prayer languages; the legacy `todayLanguageCode` override remains ignored,
  matching the current app. `fil` and `iw` normalize to shared data codes `tl` and `he`.
- English, Hebrew, Arabic, Russian, Filipino, French, Italian, and Ukrainian interface
  strings are supported. Hebrew and Arabic content uses right-to-left layout. Source text
  remains the fallback when a dataset does not supply the selected language.

Feast titles, intention text, Torah portion names, and Scripture citations come from the
same credited data as Today in the app. No widget-specific prayer or Scripture translation
is generated. Compact citations may be shortened by the widget's available space; tapping
Today opens the app's full view. Attribution remains in the app's Calendar Data credits.

Where a layout shows a weekday heading, it follows the existing rite rules: modern Roman calendars use the
liturgical season/week, other calendars use a civil-date heading, and Sundays omit the
supplementary heading. A Rosary shortcut uses the actual current prayer day, not a date
previously selected in Today.

## Saved Prayer

Each widget instance selects a saved `Prayer.id`. Names are display text, not identity:
renaming or editing a prayer keeps its widget selection, while a duplicated prayer has a
different UUID. The app re-reads the selected UUID on launch so the saved language, options,
variant, and day remain authoritative. A missing or deleted selection asks the person to
choose a saved prayer; it must not silently open another configuration.

The widget supports the Rosary, bounded or unbounded Jesus Prayer, and installed generic
devotions. Step counts come from the prayer engine with the selected saved configuration.
The Jesus Prayer uses its repetition target instead of engine steps. An unbounded prayer
shows a position without inventing a total or completion percentage.

An unfinished position is displayable only when the app would offer to continue it:

1. The checkpoint's zero-based `stepIndex` is greater than zero and less than the rebuilt
   step count or bounded repetition target.
2. Its configuration signature matches the current sequence. Custom signatures use the
   effective variant after language resolution, the actual selected day, and normalized
   custom options; the bookmark key still uses the raw launch variant.
3. A Rosary checkpoint's `savedLocalDate` equals the current local civil date. Its position
   disappears after local midnight, including after a time-zone change.

Apple also expires a multi-day series' projected position at the end of the projection's
local day. Its next pending day can change while the app is closed; the widget opens the
app to resolve it again rather than carrying yesterday's day position into tomorrow.

The visible position is `stepIndex + 1`, matching the prayer flow. Completing or restarting
a session clears its bookmark. A widget launch retains the app's existing Continue/Restart
decision and missed-day choice; displaying a checkpoint does not commit to either action.

For multi-day series, derive the day from the same `MultiDayRun.resumption` rules as the
flow: start at the first day, resume the pending day, use the missed day until the person
chooses, or show the last day for a completed series. Reopening a day already prayed today
uses the last recorded day. Fixed-date or manually selected devotions retain their normal
day selection. Do not calculate a total from `Prayer.dayIndex` alone.
Android omits the checkpoint while the existing missed-day chooser requires a decision.

Widgets inherit existing progress ownership. Rosary and saved Jesus Prayer checkpoints use
the saved UUID. On Mac, generic devotion copies use the saved UUID plus bundle identity;
their windows keep independent namespaces while the shared checkpoint records the most
recently saved continuation. The phone apps' existing generic-devotion progress remains
bundle/variant/day scoped. Choosing two saved configurations of the same generic devotion
does not introduce a new progress store; each widget validates that checkpoint against its
own options before showing it.

On Mac, opening a saved prayer uses the normal `PrayerWindowRequest` identity: it brings the
existing window for that copy forward or opens a prayer window. It does not replace the
library view, create a new saved copy, or take control of a sibling window's progress.

## Storage and refresh

Apple's host app publishes a small Codable snapshot into the App Group
`group.com.dkaluta.prosary`, under `prosaryWidgetSnapshot.v1`. It contains Today settings,
saved prayer identities/names, and validated progress summaries. The extension reads that
snapshot; it never opens the app's SwiftData database or joins its iCloud store. Calendar
datasets are bundled with the extension so Today can advance while the host app is closed.
No prayer pack or artwork is duplicated into a native image catalog for the widgets.

Android uses the existing local app settings, saved-prayer store, prayer engine, progress,
and offline Today provider. Configuration belongs to the individual Android widget ID.
Removing a widget removes its selection, not the saved prayer or its progress.

Refreshes are requested after relevant app settings, library, and progress changes. Today
must also refresh for the next local day and after a date/time-zone change. Use calendar-day
arithmetic for midnight; adding 24 hours is incorrect across daylight-saving transitions.
The operating system schedules widget rendering, so a refresh request does not guarantee
an immediate visual update. Opening the app always resolves current data and saved state.

Apple supplies timeline entries for the current day and the next seven days, and requests
the next reload after local midnight. Android requests hourly updates, schedules an inexact
alarm for the next civil midnight, and refreshes after relevant date, time, time-zone,
locale, boot, and app-update events. App-side settings/library/progress updates are coalesced
to avoid redrawing on every intermediate change.

## Adding a widget

Open Prosary at least once after installation so it can publish current settings and saved
prayers. Save a prayer configuration in the app before selecting it in a Saved Prayer widget.

- On iPhone/iPad, add a Prosary widget from the system widget gallery. For Saved Prayer,
  edit the widget and choose the saved prayer.
- On Mac, add a Prosary widget through Edit Widgets, then edit Saved Prayer to choose a
  saved library copy. The Mac and iPhone widgets use their respective device's app state.
- On Android, add Today or Saved Prayer from the launcher's Widgets picker. Saved Prayer
  opens its configuration screen to select a prayer; multiple instances can select
  different saved prayers.

## Apple signing

The containing app and the WidgetKit extension must both have the App Groups capability for
`group.com.dkaluta.prosary`, with signing profiles that include that group. Register/enable
the identifier for both targets under the project's existing development team before a
signed installation or archive. The containing app must embed the extension. App Group
sharing is required for the saved-prayer picker and the user's Today settings; an unsigned
compile alone cannot prove it works in an installed app.

The widget's storage is device-local presentation data. Do not migrate the main SwiftData
store into the App Group, add widget fields to `PresetEntry`, or copy the database into the
extension to solve signing or sharing failures.

## Verification matrix

Local verification on 2026-09-10 passed 454 Mac unit tests, 398 iPhone simulator unit tests,
and 351 Android unit tests. Both Apple extension destinations compile unsigned; Android debug
app and instrumentation packages build. Apple static native view captures covered 22
size/language/appearance/content combinations, including Hebrew and Arabic. Those captures
do not establish installed WidgetKit gallery behavior.

Three Android emulator instrumentation tests passed: cold/warm navigation and Activity
recreation, real `AppWidgetHost` selection/progress/deleted-prayer handling, and 16 native
RemoteViews combinations across English, Hebrew, Arabic and Filipino, compact/expanded
sizes and light/dark appearance. These do not establish OEM launcher scheduling or behavior
on physical devices. The remaining live checks are recorded below:

| Surface | Required checks | Live evidence |
| --- | --- | --- |
| iPhone/iPad | Gallery registration, add/edit each family, choose saved prayer, tap cold/warm app, supported sizes | Pending |
| Mac | Gallery registration, desktop/Notification Center placement, saved selection, existing-window activation, independent sibling window | Pending |
| Android | Launcher registration, initial configuration/cancel, multiple instances, resize/reconfigure, cold/warm launch | Emulator host and cold/warm/recreation checks passed; OEM picker/resize and physical devices pending |
| All requested platforms | Selected rite and Pascha style, missing-day data, all visibility flags, offline operation, local midnight and time-zone change | Automated data/boundary coverage passed; live clock and device changes pending |
| All requested platforms | All eight locales, Arabic/Hebrew RTL, long prayer names, large text, light/dark appearance, screen-reader labels | Resource coverage and native view captures passed; installed Apple layouts, complete locale/device matrix and screen readers pending |
| Saved Prayer | Rename/edit/delete, invalid signature, completed/restarted prayer, same-day Rosary expiry, bounded/unbounded counter, custom multi-day choice | Unit coverage and Android host progress/deletion passed; remaining live lifecycle/series cases pending |
| Signed Apple installation | Shared App Group storage, saved-prayer picker population, extension embedding and provisioning | Pending |

Keep automated coverage focused on meaningful boundaries: strict widget URL parsing, saved
UUID routing, checkpoint signature/bounds/day validation, missing calendar data, locale
aliases, and midnight calculation. Package/build checks do not establish launcher, device,
or signed App Group behavior.

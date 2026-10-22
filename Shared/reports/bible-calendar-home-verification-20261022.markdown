# Bible, calendar and Home layout verification

Local feature branch: `feature/bible-calendar-home-layout`, based on release commit
`f8597a1930dafcf2719ec218d79d8a4cc9346ad3`. This records local validation before the 0.23.1 release.

## Behavior

- iPhone/iPad Holy Scripture uses a full-screen presentation with the existing navigation
  stack and localized Done action. Calendar retains its native sheet. Mac keeps its library.
- Calendar grids use system calendar/region preferences independently of interface language.
  Weekday headings and month padding agree; event lookup retains Gregorian civil identity.
  No new persistent preference or translation strings are introduced.
- Apple, Android and Windows Home layouts place saved cards into the shortest column,
  breaking ties from the logical leading edge. Adding a card preserves earlier placements
  and minimizes its added height. Expansion and resizing may reflow later cards. Narrow
  layouts and the separate safe-pane fold assignment retain their existing behavior.

## Verified

- Android `./gradlew testDebugUnitTest compileDebugAndroidTestKotlin`: 585 JVM tests in
  73 suites passed; device-test compilation passed.
- Android `SystemCalendarMonthInstrumentedTest`: two tests passed on a disposable API 36
  tablet. US/UK week starts preserve the same leap-day civil dates; Hebrew Adar I/II
  month lengths, navigation and civil identities agree.
- Direct Android debug-app smoke check: Home rendered normally with three natural-height
  columns and a Sunday-first calendar, outside the Compose test harness.
- Apple focused macOS suites `HomeDashboardLayoutTests`, `SystemCalendarMonthTests` and
  `Version021PresentationTests`: 14 tests passed. Coverage includes shortest-column
  placement, unchanged earlier frames when adding, Sunday/Monday padding and Hebrew leap months.
- iPad Pro 11-inch (M5), iOS 27.0: full-window Bible opening/Done and Calendar dismissal
  passed. Facing-page advance/back and verse jump passed with the catalog-verified offline
  Douay archive. Regional weekday headers passed for US and UK. Home packing and saved
  accessibility order passed in English and Hebrew.
- Final iPad rerun after restoring the established toolbar owner: all three reader,
  Calendar and Done-navigation tests passed (`prosary-home-calendar-ipad-verified.xcresult`).
- `DESIGN.md` lint and strict premium UI audit: no errors or warnings. Shared schema JSON
  parses; `git diff --check` passed. Existing localized labels are reused.

## Limits and retained diagnostics

Windows native code and matching tests were updated; Windows build/runtime checks require
a Windows host and were not executed locally. The native Mac Home workflow is unchanged.
visionOS retains its native sheet presentation; its build was not run in this verification.

Broader Android Compose UI tests failed inside the test frame clock: view layout was applied
from `DefaultDispatcher-worker-1`, followed by a slot-table disposal exception. The native
calendar tests passed again independently; the app also opened normally without that harness.
This does not certify broader Android UI automation.

An intermediate experiment moving the Apple toolbar outside its existing navigation owner
failed dismissal checks and was reverted. The final implementation retains the established
toolbar owner. Raw logs, screenshots and `.xcresult` bundles remain under
`/private/tmp/prosary-home-calendar-*`; they are not committed as source material.

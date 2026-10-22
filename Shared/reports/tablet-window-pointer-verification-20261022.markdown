# Tablet windows and pointer input

Local changes on `feature/bible-calendar-home-layout`, before release.

## Changes

- iPhone/iPad date pickers accept their offered width and height. The calendar body scrolls
  in short windows even when the vertical size class remains regular; Today and Done stay
  outside that scrolling body. Mac and visionOS keep their existing preferred calendar sizes.
- The shared Apple plain-control hover owner now also provides native iPad pointer highlights.
  Home expansion headers, calendar dates and event rows use the same owner; existing prayer,
  category and search actions inherit it. Reading text does not acquire a hover platter.
- Native Apple page-curl pan gestures accept touch/Pencil rather than indirect pointer drags.
  Android Bible page turns likewise leave mouse drags to native text selection. Touch turns
  and explicit page controls remain available. Custom Android clickable cards, dates and
  event rows expose the native hand cursor without overriding descendant text cursors.
- Android narrow-reader anchors now use `firstVisibleItemIndex`: an extra preceding paragraph
  in scroll padding must not become the saved reading position during a window-size change.
  The reader device tests use Compose's current v2 scheduler and explicitly wait for the
  asynchronous anchor update before testing a subsequent resize.
- Windows already uses native controls and resizing; no new Windows implementation was needed.

## Verification

- Android JVM suite: 585 tests passed. Device-test compilation passed.
- API 36 tablet: all five `BibleBookReaderInstrumentedTest` tests passed, without skips.
  Coverage includes mouse drags versus touch turns, RTL, narrow/wide anchor retention, verse
  navigation, large text and typography. The initial resize test exposed the preceding-row
  anchor bug; the same assertion passed after the viewport-index correction.
- iPad Pro 11-inch (M5), iOS 27.0: date picker bounds/dismissal passed. Native corner-drag
  window resizing passed, including calendar width, Today/Done reachability and return to Home.
  The final repeat resized the window to 375 by 486 points and restored full-screen geometry
  afterward, without skips or failures.
  Facing-page advance/back, verse jumps and dismissal passed after the pointer change.
- The resized-window screenshot was visually inspected. The calendar fits inside the native
  floating app window with Today/Done visible. Evidence is in
  `/private/tmp/prosary-tablet-window-pointer-attachments/`.
- iPhone 17e, iOS 27.0: portrait and short-landscape calendar checks passed. The tests scroll
  to the month's final date and confirm that Done remains reachable; they no longer assume
  offscreen weeks in a virtualized grid must all be mounted simultaneously.
- Maintained design-context lint and strict UI audit passed without warnings/errors;
  `git diff --check` passed. Existing localization is reused; source content is unchanged.

Raw logs and `.xcresult` bundles are retained under `/private/tmp/prosary-tablet-window-pointer-*`.
No claim is made for physical iPad mouse/trackpad hardware, Windows runtime or visionOS runtime.
This task does not certify the separate, older Android Home UI test harness.

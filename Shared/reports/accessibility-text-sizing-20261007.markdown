# Accessibility and text sizing review — 7 October 2026

This review covers the native prayer reader, prayer setup, reminder settings and shared
typography paths. It records concrete code fixes and focused emulator evidence. It is not
a certification of every screen, screen reader, hardware configuration or script renderer.

## How text size is controlled

| App | Reader sizing | User control |
| --- | --- | --- |
| iPhone/iPad | Native semantic fonts and bundled fonts relative to Dynamic Type `.body`. Hebrew system sans uses a scaled 21-point baseline. Prayer bodies wrap and scroll. | iOS Text Size/Larger Text and per-app text size. Prosary Typography chooses the typeface rather than overriding the system text-size preference. |
| Mac | Native desktop control fonts; bundled prayer faces use the existing 0.76 desktop proportion. Presenter Mode deliberately uses an explicit reading size and wraps/scrolls without shrinking. | Presenter Mode text-size buttons, 24–96 points. The saved prayer copy retains that size. Typography settings choose typefaces. |
| Android | Material semantic fonts and prayer/Scripture sizes expressed in `sp`; both body size and line height follow the system font scale. No code overrides `fontScale` for production prayer text. | Android Font Size/Display Size. Prosary Typography chooses typefaces. |
| Windows | Native WinUI text enlargement remains enabled. TextBlocks wrap; reader content scrolls and remains selectable. Base prayer sizes are adjusted by Windows text scaling. | Windows Settings → Accessibility → Text size, plus display scaling. Prosary Typography chooses typefaces. |
| Terminal | Text occupies terminal cells; the terminal application owns font face, text size and zoom. The reader handles terminal resize. | Terminal application preferences/zoom. Complex-script shaping and assistive access depend on that terminal. |

The mobile/Windows base prayer/Scripture sizes are Hebrew 21/16, Arabic 18/16, Syriac
19/19, and Latin/Cyrillic/Greek 17/19. These are script-specific baselines rather than
limits on accessibility enlargement. Mac retains its deliberate desktop proportion.

## Fixes made

- Hebrew **System sans serif** prayer text on Apple used a fixed system font size while
  bundled Hebrew faces already followed Dynamic Type. The shared body-font modifier now
  scales the system face with `@ScaledMetric(relativeTo: .body)`, retaining its normal
  21-point baseline. The direct system-font fallback uses a semantic body style.
- Standalone Android settings and prayer-option switches were visually next to labels,
  but the label was not the switch's accessible name. The shared labeled-switch component
  attaches the actual setting name while retaining native checked/unchecked semantics and
  existing test identifiers. Daily notification switches use it too.
- The Android prayer script/reading-aid button now matches the iPhone's outlined/filled
  book treatment, announces **Show Original Text** after selecting the alternate text, and
  exposes the currently displayed Hebrew/Syriac script as its state. Windows alternate-text
  buttons also announce the action for the text currently shown.
- The central Jesus Prayer action had a fixed 104-unit frame in all three native ports.
  It now has a minimum size and padding, allowing enlarged or longer translated labels to
  expand the button.
- Windows Cyrillic Scripture incorrectly used the 17-unit ordinary-prayer size. It now
  uses the same 19-unit Scripture baseline as Apple and Android, retaining the independent
  ordinary-prayer size and typeface preferences.
- The optional published Pope's intention is separate from the sourced prayer body in all
  native readers. Its own publication language controls direction and native text sizing.
  In particular, an English fallback cannot change an Aramaic prayer's font, heading,
  progress labels or direction. Open Windows readers refresh when the option changes.
- Saved-prayer deletion in the compact settings editor preserves persistence failures and
  partial cleanup errors long enough to read them. A partial cleanup error is acknowledged
  before the deleted-copy editor closes. Mac keeps the editor's parent window alive until
  its attached sheet dismisses. Compact-editor updates on all three ports use existing-row
  writes, so a concurrently deleted copy cannot be recreated by Save.

## Android reminder findings

Ordinary `AlarmManager.set` alarms were deferred during Doze. All user-requested prayer,
multi-day and daily-topic reminders now use inexact `setAndAllowWhileIdle`, preserving the
chosen local clock time and avoiding exact-alarm permission. Delivery remains subject to
Android's inexact-alarm timing and platform quotas.

Startup/reboot/time-change restoration now includes persisted multi-day series. Disabled
saved reminders are cancelled during restoration. Notification availability checks include
the runtime permission, app-wide notification setting and reminder channel. Saved-prayer
editors keep their permission callback alive, explain blocked notifications, and offer system
settings or saving without notifications. Series completion uses an Activity-owned permission
launcher so leaving the prayer screen cannot discard the result. The notification channel and
settings links are guarded for the supported Android 7 devices, which predate channels.

## Evidence

A disposable Pixel 8 emulator using the installed Android 16/API 36 arm64 image ran these
five focused tests successfully in separate suites:

| Test | Result |
| --- | --- |
| Android setting switch name/checked state at 200% font scale | Passed |
| Android prayer script toggle changes displayed text and announced action in both directions | Passed |
| Real AlarmManager policy under forced Doze, compared with an ordinary-alarm control | Passed; reminder remains eligible while the control receives a future idle deferral |
| Persisted seven-day series restoration after its kernel alarms are removed | Passed; all seven remaining alarms restored |
| Series notification permission result after the requesting prayer screen is replaced | Passed; Android permission granted and callback retained |

The emulator's forced idle state and test alarms were restored/removed after the tests.
These scheduling checks establish the Android service policy and restoration behavior;
they do not establish physical-device/OEM overnight delivery or exact notification timing.

The parent integration observed 507 passing Android unit tests and 624 passing Mac unit
tests before the later launch-choice and final review changes. On the iPhone simulator,
529 test cases passed, including the Hebrew system-sans rendered-height regression at
`.large` versus `.accessibility3`; the test runner then hung during completion and was
interrupted. Those passing cases do not establish a successfully completed iPhone test run.
Final integration is rerun after the remaining changes. A Windows regression covers
Russian/Ukrainian Scripture size and the actual-script override; Windows execution remains
pending the Windows CI/runtime.

Physical VoiceOver/TalkBack/Narrator traversal, high-contrast settings, maximum text size
across every screen, Android 7 runtime behavior, OEM battery restrictions, and Windows
runtime layout remain target-device checks. Mac presenter controls already expose native
labels and text-size values; their full keyboard/VoiceOver traversal remains a live Mac check.

## Platform references

- [Android alarm scheduling and Doze](https://developer.android.com/develop/background-work/services/alarms)
- [Apple ScaledMetric](https://developer.apple.com/documentation/swiftui/scaledmetric)
- [Apple custom fonts with Dynamic Type](https://developer.apple.com/documentation/swiftui/applying-custom-fonts-to-text)
- [Windows accessible text and automatic enlargement](https://learn.microsoft.com/en-us/windows/apps/design/accessibility/accessible-text-requirements)

Terminal rendering boundaries are also documented in [Terminal README](../../Terminal/README.markdown).


## Final local verification

- Android: 511 unit tests passed; debug app, instrumentation APK and signed Android
  0.19.0 (49) bundle built successfully after the final selector change.
- Android API 36 emulator: eight focused checks passed (five accessibility/reminder
  checks and three launch-chooser checks). The launch chooser starts empty, exposes four
  sets through its top selector, lists exactly five mysteries per selected set,
  preserves opening prayers, follows Luminous 4 then 5 in the configured two-mystery
  session, and cancels without beginning. Eight screenshots were visually inspected.
- Mac: all 628 final unit tests passed. One rendered native chooser smoke passed,
  including all four sets, five rows per set, first-step progress, reopening and Cancel.
  This caught and fixed the chooser's previously collapsed sheet height.
- iPhone 17 simulator: 77 final focused tests passed with successful runner completion,
  including real Hebrew Dynamic Type height measurement, Rosary engines, navigation and
  continuation. The earlier full run's 529 test cases passed before its cleanup stalled;
  the final focused run uses a fresh build directory and completes successfully.
- Windows: 31 XAML files parse and unit regressions are provided; the Windows CI runner
  verifies execution before merge. Narrator, physical screen-reader traversal, Windows
  runtime layout, and OEM overnight notification delivery remain target-device checks.

[Verified Android mystery-set chooser](accessibility-20261007/mystery-set-chooser.png)


The final Android Entire Set smoke also verified all five Glorious mysteries in
order, group-only checkpoint restoration in a fresh flow, and unchanged saved
`chooseOnLaunch` mode/count/options. Individual range choices and Cancel still pass.
Apple/Android progress widgets reconstruct both whole-set and individual launch
choices before validating their checkpoint. The final Mac suite includes that widget
regression. The later Mac Entire Set UI retry could not start app interaction because
the test host timed out enabling automation; it does not supersede the earlier
passing top-selector smoke or claim that additional interaction was verified.

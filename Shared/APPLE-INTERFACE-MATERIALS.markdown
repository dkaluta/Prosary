# Apple interface materials

Prosary separates navigation from prayer and Scripture content. Use each platform's native
controls rather than treating every button or translucent background as Liquid Glass.

## iPhone and Mac

- Native tab bars, sidebars, toolbars, menus and popovers own their system appearance. Do not
  add custom material backgrounds over these surfaces.
- Mac prayer-library toolbar actions appear only in library and tag views. Today/Readings
  puts date navigation and settings in the native window toolbar, without a second custom
  control row. Previous/Next, Today and Settings use circular icon buttons; the selected date
  stays readable in a compact capsule. Keep accessibility labels and tooltips on icon actions.
- iPhone Readings puts Previous, the selected date, Next and Settings in the native top
  toolbar. Separate circular icon buttons flank the date capsule; Today stays in the calendar
  popover to leave room for the date on a narrow screen. Calendar metadata scrolls with content.
- iPad retains its detached date row: its adaptive tabs share the top toolbar, where date
  controls would be hidden in overflow. Detached date and prayer navigation use `prosaryNavigationButtonStyle` and
  `prosaryProminentNavigationButtonStyle`. Adjacent custom glass controls belong to one
  `ProsaryGlassControlGroup`; the group does not add a second glass background.
- Register custom bars with `prosaryNavigationBar` so the system supplies the scroll-edge
  treatment on iOS/macOS 26 and later. Older versions retain safe-area insets and bordered
  controls.
- Content actions use ordinary styles. This includes Pray inside a saved-prayer card, the
  Today action inside a date popover, the date row that scrolls with the Pray page, and the
  Mac repetition counter beside prayer text.
- Calendar metadata is ordinary text outside the date button. Do not stretch a glass control
  across a reading surface merely to hold descriptive text.
- Scripture and prayer bodies remain content. Mac Today uses the semantic text background;
  Gallery artwork and Presenter Mode keep their existing readable surfaces.
- Prayer and saved-preset cards use opaque semantic content backgrounds on iPhone, iPad and
  Mac. Their text and inline actions scroll with the content, so translucency adds no useful
  separation from an underlying layer. Keep the existing rounded shapes and accent strips.
- Standard SwiftUI materials such as `regularMaterial` are distinct from Liquid Glass and are
  not categorically excluded from content. The transient Gallery loading overlay and visionOS
  content groups retain standard material where it provides useful separation.
- System glass controls handle Reduce Transparency and related accessibility settings. Keep
  semantic foregrounds and platform controls; do not simulate glass with custom blur or opacity.
- The app accent uses the existing burgundy/rose brand palette. Primary navigation and prayer
  actions use that accent; ordinary glass controls stay neutral. Mystery and seasonal colors
  identify content and progress rather than changing the meaning of the Next action. The custom
  iPhone repetition button uses a semantic contrasting label in both appearances.
- iPhone transport, disclosure and script controls need at least 44-point interaction areas.
  Keep Mac controls compact and preserve their native keyboard behavior.
- Inline Pray, iPad and spatial date navigation give previous, date and next labels the same
  available height before the native button style is applied. Native toolbars own the sizing
  of their date controls. The shared calendar popover includes Today and Done. Size
  its graphical calendar for the platform rather than trusting the UIKit wrapper's reported
  ideal width; the iPad uses the same native calendar as iPhone. In compact-height iPhone
  landscape, use a sheet with a scrollable calendar and a persistent Today/Done footer so
  the native calendar's full height cannot push its actions off-screen.
- Date selection alone does not call for custom glass. iPhone Readings and Mac Today use
  their native toolbar appearance. The Pray date row scrolls within content and uses ordinary
  bordered buttons. The graphical calendar keeps the native
  popover appearance, with no additional material background or glass applied to its days.
- Prayer Back and Next/Finish remain native glass controls in their detached navigation bar.
  Next/Finish uses the prominent tinted glass style for the primary action; its stronger fill
  is intentional, not a separate opaque content button.

## visionOS

- Keep the native glass window and system tab/navigation controls. Do not paint an opaque
  iPhone or Mac background across the spatial window.
- Custom brand, headline, current-bead and seasonal colors use the iPhone dark-mode palette:
  rose accents and light headings. Asset variants and `Color.adaptive` choose these values
  explicitly on visionOS; do not force a window-wide color scheme or replace adaptive glass.
- The iPhone/Mac glass helpers fall back to native bordered spatial buttons. They do not add
  another Liquid Glass layer to the window.
- Use standard materials to distinguish groups within the window, and native bordered controls
  for transport, pins, filters and the repetition counter.
- Custom plain rows and cards explicitly opt into native gaze feedback with
  `prosarySpatialHoverEffect`. Apply `prosarySpatialTarget` to labels so their interaction area
  includes at least 60 points; keep hover shapes aligned with the actionable surface.
- Scripture retains its actual-script font and direction. Do not use color alone for state;
  category filters include a checkmark and selected accessibility traits.
- Give the graphical date picker 500 points plus its popover padding so all seven columns and
  both month controls remain visible. The phone-sized 320-point popover clips spatial controls.

## Sources and verification

Reviewed against Apple's [Liquid Glass overview](https://developer.apple.com/documentation/technologyoverviews/liquid-glass),
[adoption guide](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass),
[Materials HIG](https://developer.apple.com/design/human-interface-guidelines/materials),
[Buttons HIG](https://developer.apple.com/design/human-interface-guidelines/buttons),
[Pickers HIG](https://developer.apple.com/design/human-interface-guidelines/pickers), and
[visionOS adoption guidance](https://developer.apple.com/documentation/visionos/bringing-your-app-to-visionos).

The 2026-09-24 follow-up checks the contextual Mac Today toolbar in a freshly built app, and
the iPhone Readings toolbar on an iPhone 17e simulator running iOS 26.5. Checks cover portrait,
landscape, Hebrew/Arabic ordering, navigation before and after scrolling, calendar bounds and
dismissal, and the compact-height calendar footer on both Pray and Readings. An iPad mini
simulator confirms its separate date row remains reachable below the adaptive tabs. The
shared calendar also builds on Mac, with all four date-selection tests passing.
The current build also passes the Readings toolbar check on iPhone 18 Pro with iOS 27:
screenshots retain the full large heading and show no compressed inline title after scrolling.

The 2026-09-16 pass checks iPhone navigation/date controls and Hebrew/Arabic prayer layouts in
Simulator, and Mac Today scrolling, Gallery, the native date popover, and prayer controls in an
isolated live app. The final date-picker checks cover both Pray and Readings on iPad in portrait
and landscape and in the visionOS simulator, including equal button heights, minimum target
dimensions, all seven calendar columns, and dismissal without changing the selected date.
Simulator/build checks do not establish physical-device, headset gaze,
VoiceOver, or minimum-OS coverage. Recheck dark appearance, increased text sizes, Reduce
Transparency, and Increase Contrast on target devices before claiming that coverage.

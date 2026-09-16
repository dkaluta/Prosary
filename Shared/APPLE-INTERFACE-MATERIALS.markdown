# Apple interface materials

Prosary separates navigation from prayer and Scripture content. Use each platform's native
controls rather than treating every button or translucent background as Liquid Glass.

## iPhone and Mac

- Native tab bars, sidebars, toolbars, menus and popovers own their system appearance. Do not
  add custom material backgrounds over these surfaces.
- Detached date navigation and prayer navigation use `prosaryNavigationButtonStyle` and
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
- Standard SwiftUI materials such as `regularMaterial` are distinct from Liquid Glass and may
  group content. The existing prayer-card backgrounds and Gallery loading overlay use these
  standard materials intentionally.
- System glass controls handle Reduce Transparency and related accessibility settings. Keep
  semantic foregrounds and platform controls; do not simulate glass with custom blur or opacity.
- The app accent uses the existing burgundy/rose brand palette. Primary navigation and prayer
  actions use that accent; ordinary glass controls stay neutral. Mystery and seasonal colors
  identify content and progress rather than changing the meaning of the Next action. The custom
  iPhone repetition button uses a semantic contrasting label in both appearances.
- iPhone transport, disclosure and script controls need at least 44-point interaction areas.
  Keep Mac controls compact and preserve their native keyboard behavior.

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

## Sources and verification

Reviewed against Apple's [Liquid Glass overview](https://developer.apple.com/documentation/technologyoverviews/liquid-glass),
[adoption guide](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass),
[Materials HIG](https://developer.apple.com/design/human-interface-guidelines/materials),
[Buttons HIG](https://developer.apple.com/design/human-interface-guidelines/buttons), and
[visionOS adoption guidance](https://developer.apple.com/documentation/visionos/bringing-your-app-to-visionos).

The 2026-09-16 pass checks iPhone navigation/date controls and Hebrew/Arabic prayer layouts in
Simulator, and Mac Today scrolling, Gallery, the native date popover, and prayer controls in an
isolated live app. Simulator/build checks do not establish physical-device, headset gaze,
VoiceOver, or minimum-OS coverage. Recheck dark appearance, increased text sizes, Reduce
Transparency, and Increase Contrast on target devices before claiming that coverage.

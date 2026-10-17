# Folding and resizing

Prosary preserves the active prayer, language/form/day selection, unsaved editor draft, and
reading position while its available space changes. A size change is part of the current
session; it must not be treated as leaving a prayer and reopening its saved bookmark.

## Android

The navigation host remains in the same composition while the shell changes between a bottom
bar and a navigation rail. Navigation-entry ViewModels retain prayer sessions, narration and
editor drafts across Activity recreation. The normal lifecycle remains enabled in the manifest.
The narration player pauses on ordinary backgrounding and releases on navigation-entry removal;
configuration recreation does neither. A new entry still offers Continue/Restart for a valid
saved run. Auto-advance retains the remaining interval across recreation and is suspended by
audio and session decisions.

Prayer layouts keep one reading list with stable paragraph keys, preserving the text and bold
annotations from the content packs. Wide layouts account for the width of all mystery groups.
Tests cover activity recreation, changing navigation width, retained reading anchors, large text,
right-to-left text, unsaved edits, narration, and genuine exit/reentry. Run them on an isolated
emulator; debug test hosts use in-memory presets and disposable preferences/content.
Draft retention covers configuration recreation, including folding and rotation. It does not
serialize an entire unsaved draft for recovery after the operating system kills the process.

Home observes the current Activity's real folding features with Jetpack WindowManager 1.5.1.
An active separating fold or fully occluding hinge constrains its toolbar and card grid to the
largest unobstructed pane; equal panes prefer the lower or physical right side. Window-relative
feature bounds are converted through Home's measured window origin, without mirroring for RTL.
One grid and remembered scroll state remain in place while pane geometry changes. The centered
grid uses up to 1200 dp on ordinary tablets and flat nonseparating folds, with 340-dp minimum cards;
inside a partial fold's safe pane it uses as many columns as that pane can fit. This is a
conservative one-safe-pane fallback, not a dual-pane tabletop dashboard. Native dialogs remain
platform-owned and require posture interaction checks; prayer/session ownership is unchanged.

## Apple and iPhone Duo

[Apple's iPhone Duo HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)
was published on September 9, 2026. It calls for continuous state, compact/regular layouts,
system-managed bar placement, and avoidance of reserved camera/folding regions. Duo uses vertical
system controls on its outer display and inner landscape display. That placement follows the
hardware and does not mirror for right-to-left languages. Native alerts, sheets, menus and split
views adapt to reserved regions automatically; custom prayer content needs explicit review.

The current Apple reader keeps a position relative to the prayer text when columns or wrapping
change. It does not promise restoration to the exact same character after reflow.

Xcode 27.1 supplies the Duo SDK and simulator. Standard tabs, navigation, sheets and menus
adapt through the SDK. Prosary keeps this system behavior rather than identifying the device
or manually placing side bars. Custom prayer controls read `toolbarVerticalEdge`: vertical
bars receive native grouped actions and high-priority Back/Next buttons, with prayer actions
preferred over the tab bar when space is tight. Horizontal compact windows retain their
existing control row and footer.

Custom prayer content uses active reserved regions and native split arrangements. Artwork
and beads occupy one pane; reading, progress and audio controls occupy the other. Camera
regions use physical coordinates independently of the interface direction. The same session
and reading anchor survive layout changes. `ReservedRegionAvoidingContent` is the shared
camera-avoidance owner for custom content and arrangement panes. Region frames already include
the system's interactive margins; do not add those margins a second time.

The iOS root uses a native tab view and navigation stacks. The explicit navigation split view
is Mac-only, so the prayer's arrangement is not nested inside a navigation split view. Each
arrangement pane owns its bounded scrolling content rather than placing the arrangement inside
a scroll view. Home uses the same pane-local camera avoidance and measures its card grid from
the available pane width.

The remaining device matrix includes:

1. Build with the Duo SDK and run both displays, inner portrait/landscape, partial-fold poses,
   Split View and changing camera reserved regions.
2. Check camera and partial-fold reserved regions for custom artwork, beads and reading
   content, Home cards and native Scripture readers.
3. Check action reachability and tab visibility in vertical bars and native overflow, retaining
   grouped items, localized titles and symbols.
4. Verify live prayer, narration, scroll position and open editors/sheets during transitions,
   including all mystery groups, long content, large text, Hebrew and Arabic.
5. Follow simulator verification with physical-device testing before claiming full Duo readiness.

## Windows

Window resizing follows the same fitting and reading-continuity contract. The Windows tests
need a Windows host; Apple or Android success is not evidence that WinUI interaction passed.
The fitting helper measures the content row, including artwork, bead groups and a readable
text column. The reader retains a text-symbol and line anchor across both layout modes.

## Verification on October 17, 2026

| Platform | Verified | Remaining |
| --- | --- | --- |
| Apple | 591 XCTest and 2 Swift Testing cases pass in the isolated release tree; Mac builds. The prayer fold audit follows Apple's current iPhone Duo overview and reserved-region API. Geometry coverage includes offset vertical panes, rotated short panes, camera margins and physical placement independent of text direction. Earlier Duo UI checks covered live Rosary progress/navigation, counter prayer actions and an open mystery picker across rotation. | Full open/closed/partial-fold matrix, narration, large text and RTL prayer transitions; physical Duo testing. Rotation and geometry checks do not certify actual fold transitions. |
| Android | 569 unit tests pass, including eight safe-pane geometry cases. The native interaction test APK assembles, including preset selection over existing custom and wallpaper overrides. Home has source-backed separating/occluding-fold observation and pure safe-pane geometry tests. | Execute native interaction tests on a provisioned emulator; actual partial-fold transitions, safe-pane placement and native dialogs require device verification. |
| Windows | Actual WinUI API source checks and eight native palette/contrast calculations pass. Existing portable layout/reading helper coverage remains applicable. | Native Windows build, XAML rendering and interaction tests on Windows. |

The installed `simctl` exposes orientation and screen geometry controls but no public fold-pose
operation. Device Hub posture inspection was unavailable during this audit. Actual partially
folded operation is therefore unverified; geometry and rotation are recorded separately. No
simulator device or clone was created for this audit.

## Historical verification on September 10, 2026

| Platform | Verified | Remaining |
| --- | --- | --- |
| Android | 346 unit tests and 19 instrumented tests passed on an API 36 Pixel 9 Pro Fold emulator, including open–closed–open, recreation, narration, background timer, drafts, reading anchors, 200% text and RTL. | Physical foldables and dedicated hinge/tabletop layouts. |
| Apple | 385 iPhone simulator unit tests, 441 Mac unit tests, 13 focused UIKit checks and a live iPhone portrait/landscape rotation test passed with the installed SDK. | Duo SDK and device verification after Xcode 27.1 becomes available. |
| Windows | Portable layout/reading helper checks and WinUI source typechecking passed. | Native Windows build, XAML rendering and interaction tests. |

Android reading tests include the end of a long prayer: the temporary viewport before system
insets arrive must not overwrite its saved position. A subsequent user scroll establishes a
new position, and a genuine step change starts at the top. Counter repetitions keep their
unchanged prayer and action button in place.

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

The current change does not introduce a separate tabletop interface or hinge-aware pane layout.
Those require a distinct design pass using Android WindowManager folding features, including
dialog placement on devices with an occluding hinge.

## Apple and iPhone Duo

[Apple's iPhone Duo HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)
was published on September 9, 2026. It calls for continuous state, compact/regular layouts,
system-managed bar placement, and avoidance of reserved camera/folding regions. Duo uses vertical
system controls on its outer display and inner landscape display. That placement follows the
hardware and does not mirror for right-to-left languages. Native alerts, sheets, menus and split
views adapt to reserved regions automatically; custom prayer content needs explicit review.

The current Apple reader keeps a position relative to the prayer text when columns or wrapping
change. It does not promise restoration to the exact same character after reflow.

The user identified Xcode 27.1 as the Duo SDK delivery target and confirmed that it is not yet
available. Duo SDK implementation and simulator verification remain pending. The current
compatibility changes must build with the installed SDK; do not add guessed future APIs or
claim Duo verification from iPad/Mac results. Once Xcode 27.1 is available:

1. Build with the Duo SDK and run both displays, inner portrait/landscape, partial-fold poses,
   Split View and changing camera reserved regions.
2. Adopt the documented reserved-region/arrangement APIs for custom artwork, beads and reading
   content where native adaptation is insufficient.
3. Check the existing compact action row, prayer footer and tab visibility against the native
   vertical bars. Preserve system overflow and item groupings, with titles and symbols.
4. Verify live prayer, narration, scroll position and open editors/sheets during transitions,
   including all mystery groups, long content, large text, Hebrew and Arabic.
5. Follow simulator verification with physical-device testing before claiming full Duo readiness.

## Windows

Window resizing follows the same fitting and reading-continuity contract. The Windows tests
need a Windows host; Apple or Android success is not evidence that WinUI interaction passed.
The fitting helper measures the content row, including artwork, bead groups and a readable
text column. The reader retains a text-symbol and line anchor across both layout modes.

## Verification on September 10, 2026

| Platform | Verified | Remaining |
| --- | --- | --- |
| Android | 346 unit tests and 19 instrumented tests passed on an API 36 Pixel 9 Pro Fold emulator, including open–closed–open, recreation, narration, background timer, drafts, reading anchors, 200% text and RTL. | Physical foldables and dedicated hinge/tabletop layouts. |
| Apple | 385 iPhone simulator unit tests, 441 Mac unit tests, 13 focused UIKit checks and a live iPhone portrait/landscape rotation test passed with the installed SDK. | Duo SDK and device verification after Xcode 27.1 becomes available. |
| Windows | Portable layout/reading helper checks and WinUI source typechecking passed. | Native Windows build, XAML rendering and interaction tests. |

Android reading tests include the end of a long prayer: the temporary viewport before system
insets arrive must not overwrite its saved position. A subsequent user scroll establishes a
new position, and a genuine step change starts at the top. Counter repetitions keep their
unchanged prayer and action button in place.

# Prosary on Mac

Prosary's Mac interface centers on a prayer library and separate prayer windows. Shared prayer
engines, content, presets and settings do not require the Mac to imitate a phone. SwiftUI and
AppKit provide native selection, sidebars, controls, scenes, window routing, geometry restoration,
and importing when no library window is open. Choose the framework that produces the correct
platform behavior for each surface.

Mac is not required to match the phones feature for feature. Choose functionality and workflows
for how people use a Mac; shared content correctness and localization still apply. A feature's
presence on a phone is not, by itself, a reason to include it on Mac.

## Conventions

- **Library and Gallery:** a fresh Library starts empty when there are no saved prayers or
  explicitly chosen templates. The Prayer Gallery offers bundled and downloaded prayers without removing their
  source files or automatically filling the Library. A native AppKit collection presents large
  artwork/symbol previews with Finder-style multiple selection: Command-click toggles individual
  items, Shift extends selection, and dragging a selection rectangle selects a group. Search and
  authored-category filters retain only visible selected IDs. Arrow keys move through the grid;
  Return applies the bottom-trailing action to the selection, while double-click acts only on the
  clicked prayer. Add to Library adds only missing prayers in one local membership write and one
  library update; already-included prayers stay intact. When all selected prayers are included,
  Show in Library selects the first one in visible gallery order. A localized count describes
  multiple selection; download removal remains a single-item action. These actions do not open
  prayer windows or create cloud
  preset. Existing saved prayers stay visible; imports and repository downloads go straight to
  Gallery without adding library membership. A saved prayer remains
  visible even if its pack is temporarily absent. The Library presents the chosen prayers and
  named copies in icon or list view, with search and named-tag filters. The community catalog
  remains accessible beside the Gallery and Today. Opening or editing an unsaved entry creates
  its durable named copy through the existing preset store; later edits retain that identity
  and settings. Browsing, Gallery additions and tag changes never create saved configurations.
  Language labels describe the language the saved prayer actually opens in, using the same
  bundle fallback as the engine. A Hebrew-only download must not claim Latin because Latin is
  the app default. Show only the language name in the library; keep the Default indication in
  settings, preserve the saved choice, and refresh labels when the default language or fallback
  order changes.
- **Gallery artwork:** all eleven built-in prayers have separately curated covers, sourced from
  public-domain or CC0 artwork. Preserve the source proportions and use soft layered shadows on
  the image itself; keep labels and selection outlines crisp. A neutral loading placeholder
  avoids briefly showing the Rosary fallback cover. Credits and source links live in the Mac
  About window and [the canonical image credits](Images/CREDITS.markdown). Covers ship only in
  the portable packs. Imported devotions can use their own declared illustrations.
- **Copies:** Duplicate creates another named copy with a new UUID, independent progress, and
  the same prayer configuration and tags. The name starts with the localized equivalent of
  “Name Copy,” adding a number on collision. The copy is not the default, and copied reminder
  definitions receive fresh identities and start disabled. Prayer Settings edits the selected
  copy; it does not rewrite a source pack or another copy's settings.
- **Removal:** Remove from Library removes a template that has not yet become a saved copy.
  Delete Saved Prayer deletes the selected copy and its reminders after confirmation, preserving
  other copies. File and context menus expose the action; Command-Delete applies only outside
  native text editing. Deleting the last copy also clears its template membership and tags.
  Built-in prayers remain in Gallery. The final saved copy of a custom download removes the
  download from this device too; unused downloads can also be removed in Gallery or Downloads.
  Used downloads remain protected until their saved copies are deleted. An iCloud-backed pack
  is evicted locally and excluded from automatic redownload, leaving the cloud source intact.
  A failed saved-copy deletion keeps the pack and reminders. A subsequent cleanup failure
  reports the partial result and can be retried in Downloads. Deleted prayer windows close,
  and stale editors cannot recreate a deleted saved copy.
- **Tags:** a new library starts without tags. Names and colors are independent, and new names
  receive stable UUIDs. A tag can use any palette color or no color. Tags… opens an AppKit token field with
  existing-name completion and selectable suggestions; commit a token to apply it, and Return
  finishes entry. Icon and list context menus share one native Finder-style row: clear and the
  actual stored tags in saved order, selected rings, Add/Remove hover captions naming each tag,
  and Tags… with its tag symbol beneath. Tags with the same color remain separate controls;
  uncolored tags use an outlined dot distinct from the clear control's slash. Controls wrap after
  eight targets, with the editor beneath the final row and arrow-key access across rows.
  Opening the menu and toggling a tag never create tags. Tags… creates new names.
  Clear removes the prayer's assignments while retaining its named tags.
  Typed names reuse existing tags case-insensitively and replace that prayer's complete tag set
  together. Sidebar tag commands rename, recolor or delete the tag. Empty names and rename
  collisions fail without merging unrelated assignments. Deleting a tag removes its assignments,
  never its prayers; changing a name or color preserves the current filter and identity.
  Migration removes only untouched, unassigned automatically seeded colors. Assigned, renamed,
  recolored and explicitly named tags keep their identities, and removed defaults never reappear.
  When old tags share a name, editing another token keeps the original assigned identities;
  suggestion checkboxes address the individual tags rather than merging by displayed name.
  Tag organization belongs to this Mac; shared prayer configurations retain their existing sync
  behavior. Source-pack categories remain separate from these personal tags.
- **Windows:** the library and prayer sessions are separate windows. Open activates an already
  open window for the same saved copy.
  Duplicating a prayer creates a saved library object as well as a distinct window target.
  Prayer windows have content titles and independent bookmarks. Their remembered size and
  position belong to the stable library identity, with separate numbered geometry slots for
  simultaneous windows. Recover unreachable title bars after a display change. Closing a window
  keeps other windows, including minimized ones, alive. Command-Q quits.
- **Recents:** the Dock menu and File → Recently Prayed show up to eight recent playable prayers.
  Opening one activates its prayer. Recents survive relaunch and prune unavailable
  presets/devotions. Setup screens, category lists and About do not enter prayer history.
- **Menu bar:** preserve the system Edit, View and Window menus. Settings uses Command-comma;
  File → Show Library uses Command-N and Import uses Command-O. Duplicate uses Command-D and
  Prayer Settings uses Command-I.
  Library and prayer actions use focused scene state and disable when irrelevant.
  Help opens the Prosary website. English menu and button labels use title case; ellipses denote
  required additional input, not simple navigation or completion. Locales use their own conventions.
- **Toolbars:** Library and prayer windows use `Prosary.Library.Toolbar` and
  `Prosary.Prayer.Toolbar`, stable native item identities, and the standard customization
  palette. People can rearrange or remove optional items; Library also offers Today and Gallery
  shortcuts in its palette. View → Toolbar Appearance offers Icon and Text, Icon Only, and
  Text Only; Customize Toolbar opens AppKit's palette. AppKit saves the chosen configuration and
  display mode. Reopening or redrawing a window must
  preserve those choices. Keep menu and keyboard routes available when a toolbar item is hidden,
  and do not replace SwiftUI's toolbar delegate or draw a separate imitation toolbar.
- **Materials:** let native sidebars, toolbars, menus and popovers provide their system
  appearance. Reserve explicit Liquid Glass for the small, persistent controls that navigate
  dates or prayer steps. Keep library artwork, prayer text, Scripture, calendar metadata and
  other reference content on standard surfaces; do not turn them into glass cards. Inline
  content actions use ordinary native buttons. Standard material remains appropriate for a
  transient progress overlay and is distinct from Liquid Glass. Avoid adding a second glass
  background around controls that already supply one.
- **Files:** register `.prosaryprayer` as an owned, ZIP-conforming document type with Viewer role.
  Finder/Files opening, file drops and Import share bundle validation and security-scoped reading.
  Never claim ordinary ZIP archives as Prosary documents. On Mac, Finder opening, library drops
  and Import add packs to the Gallery; they do not launch prayer windows or create saved copies.
- **Selection:** icon and list views preserve system selection, inactive-window appearance and
  context targets. Return or a double-click opens the selected prayer. A secondary click targets
  that prayer for Open, Duplicate, Prayer Settings and tags. In icon view, titles, language labels,
  symbols and tile padding share the same target; labels do not intercept secondary clicks.
  Control-click opens the same menu without replacing the current selection.
- **Prayer controls:** size layouts from the actual window width. Use native Mac push buttons,
  tooltips for icon actions, selectable/copyable prayer text, and Return for the primary
  prayer action. Preserve ordinary Space scrolling. Menus and progress never operate on a sibling.
- **Presenter Mode:** every prayer uses the same optional large reading surface, entered from its
  toolbar or View menu. Preserve the selected original/transliterated wording, source-script
  direction, and Scripture/prayer typefaces. Size text explicitly from 24 to 96 points (44 by
  default); long prayers scroll without shrinking or clipping and show continuation cues.
  Left/Right move between steps according to interface direction, Return performs the primary
  action, and Escape exits the mode. Page Up/Page Down and Space remain reading controls.
  The native full-screen button is separate from Presenter Mode. A sheet pauses prayer actions
  and auto-advance. Rosary's older combined-decade option is labelled Combine Repeated Prayers.
- **Basic Prayers:** The Library sidebar and Go menu expose the standalone prayer directory,
  including the four Marian antiphons. Each opens in an independent prayer window and supports
  Presenter Mode. A click or Return opens once; ordinary repeated opening activates that prayer's
  existing window. Activation uses a direct
  callback, never a navigation binding whose setter opens windows. Existing sourced text,
  language selection, and reading aids are reused.
- **Today:** Today returns as a reference view in the Library sidebar, separate from the prayer
  collection. Its date navigation stays above scrollable, selectable content; the native date
  popover and Today action browse a civil day without changing any prayer session. The selected
  calendar supplies its own feast and ordered reading citations, and the selected month supplies
  the Pope's intention. Readings and the optional Eretz Israel Torah portion show full book names
  and verse references directly, without a shorthand toggle. Their Bible passages start expanded
  when opening Today or changing the date/calendar, and can be collapsed independently. Ordinary
  refreshes and edition changes preserve those collapses. Compact date controls use native
  Liquid Glass where supported, with standard bordered controls on older systems. The selected
  calendar is plain metadata below those controls, and readings use an opaque text background.
  The date bar uses the system scroll-edge treatment as content passes underneath. The Today options
  popover owns its calendar, Byzantine Pascha choice and row toggles;
  Julian/Gregorian Pascha switches both Byzantine datasets. Missing data hides only that row.
  Interface language controls the complete view, including Hebrew/Arabic RTL; prayer-language
  settings do not change it. Sunday omits the supplemental day heading; other rites never inherit
  the modern Roman season heading. The view follows today across day/foreground changes until
  the user browses another date, and returns to following after Today. Calendar Data opens About
  with the required source credits. Keep data, localization and citation contracts shared with
  the other platforms while using a desktop reading layout.
- **Settings:** use a standard Settings scene with four native panes: Prayer Language, Praying,
  Typography, and Downloads. Preferences apply immediately; Today options live in the Today
  reference view rather than adding a Settings pane.
  Pane selection is local Mac presentation state. Native controls expose meaningful
  accessibility labels and values. App settings control defaults; each named prayer copy retains
  its own saved prayer settings. Auto-advance freezes the current app default on a copy's first
  prayer-window opening. Later changes belong to that copy. Presenter Mode and its text size also
  persist per copy. Duplicate copies both effective pace and presentation preferences. These
  playback/presentation preferences are local to this Mac and do not change source packs.
- **Sheets and alerts:** constrain sheet size, place Cancel before Save/Done at the trailing bottom
  edge, give Cancel Escape and the primary action Return, and use native alert button roles.
  Use compact native Mac form controls in one scroll area. Keep the opaque action footer as a
  separate layout row outside that scroll area; never let fields scroll underneath its buttons.
  Informational errors acknowledge with OK. Failed saves leave the editor and its input intact.
  Destructive actions remain explicit and never become the default Return action.
  Parent navigation commands disable while a sheet is attached. Importing a pack updates the
  Gallery without replacing an active prayer or dismissing an editor.
- **About:** use a dedicated About window with application identity, version and selectable credits.

## Review scope and evidence

The Mac prayer database lives at
`Application Support/com.dkaluta.prosary/PrayerLibrary/Prosary.store`, within the current
app's sandbox or development root. A recognized legacy `default.store` is copied with Core
Data's WAL-aware store API into a staging directory, validated, then adopted as a complete
directory. Its original files remain available for recovery. Existing named stores take
precedence; unknown schemas, missing preset tables, corruption, and incomplete migration stop
startup without resetting the library. The failure view replaces normal library/prayer content,
and all preset operations fail explicitly until the app is reopened successfully. The fallback
in-memory container is only for displaying the error. Opening the Dock menu while storage is
unavailable must not erase recent-prayer history.

The 2026-09 review covers the empty-library/Gallery workflow, Today reference view, customizable
toolbars, icon/list selection, search and named-tag filters, duplication,
saved prayer settings, menus, window lifecycle and geometry, file entry points, the community
catalog, ordinary and presenter prayer flows, Settings, language ordering, favorite/reminder editors and About. Shared
phone views retain their mobile responsibilities; the library replaces the four-section phone
navigation model on Mac. The old Presets view files contain retired code only.

Automated checks should cover empty initial membership, idempotent single and batch Gallery additions
without presets, mixtures of existing and new membership, one change notification per batch,
filtered selection, deterministic Show targets, preservation of existing saved prayers,
discovery-only imports, first-use configuration creation,
duplication and fresh progress, old tag-state migration, independent name/color changes, no-color
tags, duplicate-name handling, typed membership replacement and deletion across assignments.
Removal checks cover templates, built-ins, sibling references, unused downloads, storage failures,
last-copy cleanup and the absence of a replacement ghost template.
Also cover focused-window routing, independent/restorable window identities,
independent resume bookmarks, geometry slots, per-copy pace/presentation preferences, source-text
fidelity in Presenter Mode, document declarations and all eight file-kind
localizations. Mac UI regressions should cover Gallery multiple selection, filtered selection,
batch Add and Show in Library, single-item double-click and download removal, icon/list
selection, native tag-token entry/suggestions, filtering after rename/recolor/delete, repeated
right-click openings, retaining a copy's edited settings, and keyboard actions targeting one
window. Run them with `-useInMemoryStore`. Test hosts are also detected before store creation;
they use an in-memory container, disabled CloudKit, and disposable preferences. Cloud preference
reads, writes and resets never acquire the real ubiquitous store in test mode. The old
`-resetStore` flag now selects this isolation rather than deleting persistent data. Tests that
exercise disk persistence use explicit temporary stores. Never point a test fixture at the
person's library or copy a signed container into an unsigned test app.

Storage bootstrap checks cover WAL-backed migration, retained source data/settings/reminders,
foreign-store rejection, existing-store precedence, partial-copy failure, orphan journals, and
recognized metadata whose preset table is missing. Startup tests require every unavailable-store
operation to throw and the hosted app's container to stay in memory. These new safeguards require
their own verification; the earlier removal results below do not establish migration coverage.

Live review is also required: inspect menus, Return/Escape and button ordering, library selection
and filters, duplicate names/settings/tags, two prayer windows, close/reopen geometry, narrow and
wide windows, long presenter text, RTL, full screen, Today navigation/options/disclosures,
toolbar customization/persistence, Settings panes, file opening and error handling. Build
success alone is not proof of interaction quality. Run on the minimum supported macOS and the
shipping target OS before release; do not describe an untested OS or VoiceOver flow as verified.
The 2026-09-09 removal change passes 391 Mac unit tests and an iPhone/iPad build; Android's
matching change passes 339 unit tests. These cover reference checks, failures, empty-store
reopening, conditional updates and installed-pack identity/exclusion rules. Interactive Mac
removal verification remains pending: the temporary-library check was stopped at the user's
request, and the normal library was reopened with its saved prayer intact. Windows execution
requires a Windows host, and iCloud eviction has not been exercised against a live account.
On 2026-09-08, the running isolated Mac build was checked with the Rosary settings sheet open
and scrolled to its final Add Reminder control. The form stayed above the fixed Save/Cancel row,
native checkboxes and popup controls rendered correctly, and Escape dismissed the sheet.
The Angelus settings sheet, Today reference view/options and main Prayer Language settings pane
were also inspected. Fresh Library was confirmed empty. Gallery initially expanded the split
view beyond the window; constraining the chooser to the window's proposed size fixed it. The
rebuilt Gallery kept its sidebar, category header, scrolling canvas and Add footer inside a
1000 by 750 window. Angelus selection, Add to Library and Show in Library succeeded without
opening a prayer session. Gallery controls retain their individual accessibility identifiers.
The replacement artwork pass was then reviewed at both ends of the gallery scroll area: all
eleven covers loaded, original proportions and picture shadows were visible, and the fixed
header/footer remained intact. The same 358 Mac unit tests, generic iOS build, devotion
validation and pack deduplication checks passed with the new images.
OmniOutliner's template chooser and real toolbar customization palette, plus OpenEmu's library
and context menu, were inspected for interaction references. No user documents were changed.
Full Gallery keyboard/resize, Finder-style tag, Today date/RTL and toolbar persistence checks
remain pending in this pass. The Mac unit suite passed 358 tests; Mac and generic iOS builds passed.
The updated UI tests are authored but have not been executed. Live presenter and geometry checks
also remain unverified: Mac automation was blocked
by an operating-system authentication prompt, and the user asked to continue without that
interactive check. Automated tests and build results do not replace it.

On 2026-09-12, Mac UI tests on macOS 26.6.2 verified repeated secondary clicks on icon titles,
Control-click, and correct context targets for unselected and filtered table rows. Both library
representations showed the native tag palette, started without default tags, opened Tags…
without creating a tag, and added/cleared color assignments while retaining the named tag.
The named-tag flow also passed: duplicate a prayer, create a typed tag, apply a color, filter,
rename and recolor through the sidebar, then delete that tag while preserving the prayer and
its independent tag. Rename uses the native sheet with Cancel before Rename.
Native tests cover the tag migration, name/color collisions, disabled controls, item hit targets,
and keyboard-selection menu routing. The table intercepts contextual events only when the native
hit target belongs to that table; sidebar and toolbar menus keep their own event handling.
Finder's current tag palette and token editor were inspected read-only as the reference.

The saved-tag revision passes the named-tag edit flow and the empty/create/clear/reassign
flow in both icon and list views. Each stored tag has its own control, including uncolored
tags and multiple tags sharing a color; 25-tag layout and keyboard traversal have native unit
coverage. A startup check also found that the list menu originally required an ordinary
selection before its first right-click. The adapter now installs its window-scoped event
monitor before the native table exists and resolves that table on the first contextual
gesture. Native regressions cover delayed creation, replacement, window scope and teardown.
The rebuilt app was also launched normally and its first right-click opened the menu before
any prayer selection, confirming the startup fix outside the test library.

## References

- [Apple: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)
- [Apple: Windows](https://developer.apple.com/design/human-interface-guidelines/windows)
- [Apple: Menus](https://developer.apple.com/design/human-interface-guidelines/menus)
- [Apple: Context menus](https://developer.apple.com/design/human-interface-guidelines/context-menus)
- [Apple: Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)
- [Apple: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Apple: Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts)
- [Apple: Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)
- [Apple: Settings](https://developer.apple.com/design/human-interface-guidelines/settings)
- [Apple: File management](https://developer.apple.com/design/human-interface-guidelines/file-management)
- [Apple: Building and customizing the menu bar with SwiftUI](https://developer.apple.com/documentation/swiftui/building-and-customizing-the-menu-bar-with-swiftui)
- [Daring Fireball: Mac-Assed Mac Apps](https://daringfireball.net/linked/2020/03/20/mac-assed-mac-apps)
- [Paulo Andrade: Using SwiftUI to Build a Mac-assed App in 2026](https://pfandrade.me/blog/mac-assed-swiftui-app/)

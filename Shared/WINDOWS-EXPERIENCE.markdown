# Prosary on Windows

Windows uses a shared prayer library and separate native prayer windows. The library window
starts on Home, with Library, Today, Readings, Gallery, Basic Prayers and Search destinations,
and Settings and About in the sidebar footer. Search has a visible Community Prayers action
for discovery and installation. Existing saved prayers remain in the same SQLite store.

## Home

Home is a customizable arrangement of readings, Pope's intention, calendar, photo, reminders,
Holy Scripture, reflection and feast cards. Customize Home adds and removes cards immediately;
its native list supports drag reordering and accessible Move Up and Move Down buttons. Card
order persists in the shared `homeWidgetOrder` newline-separated identifier list. Missing
storage uses readings, Pope's intention, calendar, reminders, Scripture and feast; an explicitly
empty list stays empty. Adding a card appends it without restoring removed cards. Unknown and
duplicate identifiers are discarded.

Readings and Pope's intention use the offline providers for the library window's selected
date. Calendar opens Feasts and Solemnities; Holy Scripture opens Bible mode. Feast details
show only sourced explanations in the exact interface language, with credit and source links,
or an explicit unavailable message. The reflection card stays empty until the mission text
is supplied. Home card visibility is independent of the existing Today visibility settings.

Reminder rows use enabled saved-prayer and Today reminders. A saved-prayer row opens its exact
reminder editor; Today reminder rows open Settings. Manage Reminders offers all saved prayers,
including prayers with no reminder yet, and Settings for Today reminders.

Choose Photo uses a native picture picker and validates a private copy before selecting it
for Home. The copy stays in the app's `HomePhotos` folder. `homePhotoPath` persists that private
copy; replacing or removing it, or removing the Photo card, deletes the previous private file.
Picker cancellation preserves the photo, and
asynchronous continuations stop if the originating window or page closes. Photos remain on
the local device. A cleanup failure inside Customize Home appears in that dialog and keeps the
card selected; other Home errors wait until any active Home dialog closes.

## Library and gallery

The Library offers searchable list and grid views of saved prayers. Open, double-click, or
Enter activates the selected prayer's window. Prayer Settings edits that saved copy;
Duplicate creates a new UUID, independent progress, a distinct name, and disabled copies
of reminder definitions. Rename preserves identity. Deletion uses the existing confirmation
and removal service, preserves siblings, and closes the deleted copy's window.

The Gallery displays built-in and installed devotion templates with artwork from the prayer
packs. Add to Library creates a saved configuration without modifying the template. Repeated
additions produce distinct named copies. Import and Community downloads make templates
available in the Gallery; adding a saved copy remains explicit. Existing installation and
first-run migration behavior remains intact.

The selected item determines toolbar and context-menu actions. F2 renames; Delete invokes
the same confirmation as the menu. Search and selection stay local to their library page.
Failed persistence operations display an error and do not publish a successful library change.

Search is a separate destination for built-in and installed prayers, with Community Prayers
opening the catalog browser for discovery and installation. Its category picker derives choices from local manifests, with All Categories
and Other for untagged prayers. Selecting a category and entering text applies both filters;
leaving the query empty browses that category. Unknown downloaded tags remain discoverable.
Search works offline without requesting the community catalog. Opening a result uses the normal
independent prayer-window route. Installing in Community refreshes local discovery and the
Gallery without creating a saved library copy. View → Search (Ctrl+F) opens the library's
Search destination and focuses its query field.

## Windows commands

Each window has an in-window WinUI `MenuBar`, native caption buttons, and a draggable title
bar. Page `CommandBar` controls keep frequent library actions visible. The menu is part of
the window, following Windows conventions rather than depending on a system-wide menu bar.
The row uses WinUI's native template, rounded interaction states, flyouts,
keyboard focus and contrast behavior, with a compact height and semantic background
that blends with Mica; frequent actions remain in icon CommandBars.
See Microsoft's [menu guidance](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/menus).

Settings includes independent **Use arrow keys to navigate** and **Press Space to advance**
switches, both enabled by default. Plain Left/Right use the current prayer's previous/next
actions according to interface direction; Space uses its primary advance/count/Finish action.
Only the active window's loaded prayer handles them. Dialogs, flyouts, text editing/selection
and focused controls retain native key behavior. Up/Down and Page Up/Page Down keep scrolling;
modified and repeated key presses do not advance the prayer.

Prayer readers keep a centered column capped at 640 logical pixels, with common margins
for short and long prayers. Body text aligns to the start of its actual language; headings
and alphabet switches stay centered. The column sits inside uncapped scroll content so
WinUI measures the viewport independently of the current text. Language menus refresh
before opening, preserving native dismissal and focus when a language is selected.

| Menu | Commands |
| --- | --- |
| File | Import Prayer Packs… (Ctrl+O), Close Window (Ctrl+W) |
| View | Home, Show Library (Ctrl+L), Today, Readings, Gallery, Basic Prayers, Search (Ctrl+F), Full Screen (F11) |
| Prayer | Previous Step (Ctrl+Left), Next Step (Ctrl+Right), Prayer Settings… |
| Help | Settings, About |

Prayer commands apply to their own window and disable when its current page cannot perform
the action. Ordinary Open already opens or activates a separate prayer window, so the
desktop does not offer a duplicate “Open in New Window” action. All new labels ship in the
eight supported interface languages; Hebrew and Arabic use right-to-left content layout.

## Window and progress ownership

`DesktopWindowManager` retains one library window and each live prayer window. A saved
prayer's UUID identifies its window; a basic prayer's stable ID identifies its window;
an unsaved launch receives a new session identity. Reopening a saved UUID activates that
window. Distinct saved copies of the same devotion remain independent. Saving an unsaved
session adopts the new saved UUID in place, so later Open, Settings and Delete target that
same window. Its current checkpoint and series state move with the session.

`Router` associates each `Frame` with its owning window through a weak registry. Pages and
ViewModels use a `WindowNavigation` obtained from that frame. No command relies on whichever
window happens to be active. File pickers and dialogs retain the initiating owner, and
asynchronous continuations check that owner is still open.

Returning from an editor uses that window's stack. Finishing or backing out from a root prayer
closes that prayer window. Closing the library leaves prayer windows alive; Show Library
recreates it when needed. Closing a prayer releases its audio and auto-advance activity.

Saved generic devotions scope series state and bookmarks by `desktop:<Prayer UUID>:<bundle ID>`.
An explicit missing UUID must never fall back to another saved copy of the same devotion.
Unsaved native custom and Jesus Prayer sessions use a window-local UUID, keeping their
progress isolated before saving. Saved Rosary and Jesus Prayer progress uses the saved UUID.
The underlying prayer/content contracts remain shared across platforms; this desktop
ownership does not change phone progress keys. Basic Prayers opens through its directory
and stable prayer identity; the former desktop Pin to Pray controls are removed.

Existing Windows generic-devotion checkpoints and series were shared by bundle ID. These
legacy values are retained, but are not assigned to an arbitrary saved copy. Saved custom
copies therefore begin their new UUID-scoped history separately; their saved options,
language and `dayIndex` remain intact. Rosary and Jesus Prayer saved checkpoints retain
their existing UUID keys. This migration boundary needs explicit release-note coverage.

## Today and readings

Today is a dedicated library destination. Its date picker sits above the content and controls
the feast, full reading citations, Pope's intention, and optional Torah portion. Today offers
the same calendar, Pascha, and visibility preferences as Settings. It follows the next local
day when displaying today, while a deliberately browsed date remains selected. Complete book
names and chapter/verse citations are displayed directly, without a shorthand toggle.
Readings occupy their own tinted card, with an independent Today Card Color setting.
The feast/saints and sourced biographies have a separate card; the Pope's monthly intention
has its own card marked by crossed keys. Readings also exposes the selected calendar's
complete chronological Feasts and Solemnities list. Clicking an entry sets the shared date
and opens Daily Readings.

Each daily or Torah citation can expand independently to selectable Bible text with chapter
and verse numbers. The displayed edition name, attribution and source link distinguish this
Bible passage from the exact local Mass lectionary wording. The original citation remains
visible when text is unavailable. Arabic and Hebrew text uses RTL and the existing Scripture
fonts; source marks are retained.

The edition picker reads the small `readings-editions.json` metadata file. The verse corpus
in `readings-texts.json` is loaded only when a passage opens. Existing datasets use `daily|`
or `torah|` plus the original unlocalized `ReadingCitation.Full` and the selected edition ID.
New reading datasets use `daily|<dataset ID>|<raw citation>` without falling back to the Roman
key. Each citation captures the actual reading filename suffix when its table is loaded,
including LPJ's Roman table and the selected UGCC Pascha table, and retains that identity
through deferred expansion and alternative-edition selection. Native code
does not parse references or infer verse-number conversions. `readingsEditionId` is shared
with the other native clients. Empty follows the interface language when a matching edition
exists, including Hebrew and Filipino aliases; an explicit choice uses only that ID. Missing
editions, passages and invalid verse lists show unavailable without an English or other-edition
fallback. Changing the edition never changes the calendar's appointments. See
[DAILY-READINGS.markdown](DAILY-READINGS.markdown) for source coverage and mapping limits.

## Verification

Local verification on 2026-09-10 executed seven platform-neutral Windows model/store/identity
tests successfully. All app and test C# passed semantic compilation against the installed
WinUI/WinRT references and CommunityToolkit source generator; 168 C# and 23 XAML files also
passed syntax/XML checks. All 37 new desktop labels resolve in each of the eight locales.

Model/store tests cover fresh identities, defaults, duplicate reminder/options isolation,
unique names, successful-write notifications, and update-only behavior after deletion.
Desktop identity tests cover saved-copy progress scoping. A local semantic compilation against
cached WinUI and WinRT references can check C# APIs and source generators, but generated XAML
stubs do not validate real XAML compilation or runtime bindings.

Before shipping, run the Windows test project and a native Windows build, then exercise:

- Add, open, edit, duplicate, rename, and delete saved prayers, including multiple copies of
  one multi-day devotion and stale editors after deletion.
- Multiple windows, close/finish/back behavior, independent progress/audio, and reopening
  the library after closing it.
- Every menu and keyboard shortcut in its own window, file-picker cancellation, and owner
  closure during an asynchronous operation.
- Search category/query combinations, offline availability, installed-prayer refresh, and Ctrl+F.
- Home add/remove/reorder persistence, an intentionally empty Home, every card destination,
  private-photo cancellation/replacement/removal and owner closure, exact reminder editing,
  unavailable feast descriptions, and the empty reflection card.
- Today date/edition/settings changes, lazy passage expansion and unavailable cases,
  Arabic/Hebrew layout, all eight locales, high DPI, resizing,
  keyboard focus, and Narrator.

The workflow contract is also recorded in [schema/windows-library.json](schema/windows-library.json).

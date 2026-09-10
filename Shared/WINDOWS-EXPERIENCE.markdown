# Prosary on Windows

Windows uses a shared prayer library and separate native prayer windows. The library has
Library, Today, Gallery, Basic Prayers, Search, and Community destinations, with Settings and About
in the sidebar footer. Existing saved prayers remain in the same SQLite store.

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

Search is a separate destination for local and community prayers. Its category picker derives
choices from the available manifests, with All Categories and Other for untagged prayers.
Selecting a category and entering text applies both filters to both result lists; leaving
the query empty browses that category. Unknown downloaded tags remain discoverable. Local
search works when the community catalog is offline. Opening a local result uses the normal
independent prayer-window route; installing a community result refreshes discovery and the
Gallery without creating a saved library copy. View → Search (Ctrl+F) opens the library's
Search destination and focuses its query field.

## Windows commands

Each window has an in-window WinUI `MenuBar`, native caption buttons, and a draggable title
bar. Page `CommandBar` controls keep frequent library actions visible. The menu is part of
the window, following Windows conventions rather than depending on a system-wide menu bar.
The shared `DesktopMenuBarStyle` keeps the row compact and blends its semantic background
with Mica. It inherits WinUI's standard template, rounded interaction states, flyouts,
keyboard focus and contrast behavior; frequent actions remain in icon CommandBars.
See Microsoft's [menu guidance](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/menus).

| Menu | Commands |
| --- | --- |
| File | Import Prayer Packs… (Ctrl+O), Close Window (Ctrl+W) |
| View | Show Library (Ctrl+L), Today, Gallery, Basic Prayers, Search (Ctrl+F), Community, Full Screen (F11) |
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

Each daily or Torah citation can expand independently to selectable Bible text with chapter
and verse numbers. The displayed edition name, attribution and source link distinguish this
Bible passage from the exact local Mass lectionary wording. The original citation remains
visible when text is unavailable. Arabic and Hebrew text uses RTL and the existing Scripture
fonts; source marks are retained.

The edition picker reads the small `readings-editions.json` metadata file. The verse corpus
in `readings-texts.json` is loaded only when a passage opens. Lookup uses `daily|` or `torah|`
plus the original unlocalized `ReadingCitation.Full` and the selected edition ID; native code
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
- Search category/query combinations, remote-catalog failure, installation refresh, and Ctrl+F.
- Today date/edition/settings changes, lazy passage expansion and unavailable cases,
  Arabic/Hebrew layout, all eight locales, high DPI, resizing,
  keyboard focus, and Narrator.

The workflow contract is also recorded in [schema/windows-library.json](schema/windows-library.json).

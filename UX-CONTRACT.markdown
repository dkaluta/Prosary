# Native workflow contract

Tablet window resizing uses available content dimensions. Date-picker calendar bodies scroll
within short windows while Today/Done remain reachable. Pointer feedback belongs to actionable
controls; Scripture retains native text selection. Mouse drags do not trigger touch page turns.

Authoritative business and data sources are [AGENTS.md](AGENTS.md),
[Shared/ARCHITECTURE.markdown](Shared/ARCHITECTURE.markdown),
[Shared/schema/domain-model.json](Shared/schema/domain-model.json),
[Shared/schema/home-widgets.json](Shared/schema/home-widgets.json), and the canonical
`Shared/content` / `Shared/data` records. [DESIGN.md](DESIGN.md) documents visual intent.
This contract covers the touched native workflows; existing architecture continues to govern other flows.

| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
|---|---|---|---|---|
| Select/Listbox | Native Appearance color pickers and existing edition/language pickers | Native settings and domain schema | Platform-native picker/menu | Native build, settings and fallback tests |
| Date | Window TodayDateSelection and source-aware event month-grid owners | Canonical calendar date records | Native CalendarView / shared SwiftUI or Compose month grid | Event counts, missing dates, RTL and shared-date tests |
| Form | AppSettings and private HomePhotoStore/HomePhotos owners | Shared preference keys and private-photo contract | Custom accent / card image | Validation, persistence, failed import preservation |
| Scrollbar | Native ScrollView, Compose scroll containers, WinUI scrolling controls | Platform conventions | Page / bounded native sheet body | Build and reachable-action inspection |
| CRUD | Home widget preferences and app-private photo store | Shared home-widgets schema | Add/change/remove image; add/remove/reorder card | Existing photo tests and new card-state tests |
| Toast | Existing native inline error/alert owners | Platform sibling flows | Recoverable import or passage error | Focused failure-path tests |
| Bible pagination | Shared offline edition document and native controls | Shared/BIBLE-VIEWER.markdown and source block order | Justified continuous prose; global pages and slider; cached turns, direct verse lookup, tap-to-hide mobile chrome and compact desktop buttons | Pagination, typography, canonical verse jump, resize, focus and RTL checks |
| Bible and daily readings navigation | Native tab/sidebar shell and existing reference sheet/dialog owners | Shared/schema/screens.json and Shared/schema/home-widgets.json | Bible primary destination; Daily Readings sheet from Home, calendar events and reading reminders/widgets; Mac native Bible/Today | Primary-destination, shared-date, dismissal and deep-link tests |
| Prayer labels | Existing pack title resolvers and native Rosary label helpers | Shared/ARCHITECTURE.markdown and canonical prayer title provenance | Selected Hebrew rite for Hebrew options and spoken bead progress; descriptive Hebrew labels for other prayer languages; established non-Hebrew interface labels | Both rites, reversed global fallback/default, live selection changes and accessible progress tests |

Home expansion changes only that card's size. It preserves widget order, the selected civil
date, images, settings and the prayer session. Removing a card is independent of hiding its
content. Image replacement installs a validated private copy before discarding the previous
copy; failure keeps the old image. It never modifies the user's original photo.

Calendar grids follow the system calendar and regional first weekday, independently of the interface language and selected liturgical dataset. Event lookup retains Gregorian civil identity. Calendar markers count individual supplied observances, falling back to one parent event when
no components are supplied. No recurrence or ranked-event filter fabricates or hides published
dates. Details show exact normalized interface-language source prose, a short source excerpt
where available, and matching credits. Missing descriptions remain explicit. Choosing Readings
for this Date uses the same window date state as Home and Readings.

Scripture of the Day uses the first Gospel appointment in canonical source order, or the first
appointment when there is no Gospel. Presentation reversal never changes this choice. The
existing edition, mapped citation and passage-unavailable rules remain authoritative.

The old includeFilioque preference is ignored. Optional `$creedPolicy` metadata determines
Filioque presentation and Apostles' Creed availability after authored-source resolution.
Unavailable Apostles shortcuts do not fall through to Latin or hang in loading; they offer a
localized explanation and an existing language selection route. Imported untagged text stays
unchanged. Legacy devotion Creed keys resolve the tagged Nicene body/title where appropriate.

All controls and empty/error/accessibility strings ship in eight interface locales. Hebrew and
Arabic use actual RTL; prayer language, interface language, Bible edition and calendar remain
independent. Device-specific photos and paths never synchronize. Preset, cloud and downloaded
prayer deletion retain their existing architecture contracts, including exact-ID retirement.

Home Torah and haftarot reuse TodayInfoStore and the canonical Hebcal table. Bible replaces the
Readings tab and is also a Windows sidebar destination. The Scripture card selects that
destination. The existing Home readings card opens daily appointments and enabled Torah/haftarah
passages in a native sheet/dialog, preserving the window's selected date and offering Done/Close.
Dismissal restores the underlying destination. Calendar remains a separate native sheet/dialog
on phones/tablets and a reference window on Windows; Readings for this Date replaces its content
or closes that window before opening daily readings, without stacking modals.
Reading reminders and operating-system widgets still open daily readings for today. Mac retains
its native Bible sidebar and Today workflow. Feast explanations reuse source section owners
and exclude reflection sections only after complete prose coverage is verified and the separate
exact-language reflection copy matches all combined reflection-section text after whitespace
normalization. Otherwise the complete source explanation remains visible. The feast card has
no image picker. Explicit Android palette selection removes accent overrides so the chosen color
is visible.

Per-card colors use homeWidgetColors and the existing Today palette, independently of app accent and source liturgical colors. Home uses independent vertical columns selected from actual safe pane width. Cards fill the shortest column in saved order, with ties resolved from the logical leading edge. Adding a card preserves earlier placements and minimizes its added page height. Expansion or resizing may reflow later cards. Each safe pane has one outer scroll, stable card identity and saved accessibility order within its native accessibility container; native RTL mirrors the leading column. Side-by-side Apple fold panes each host one column with alternating cards, while vertically stacked panes retain contiguous top-to-bottom groups. Apple HomeLayoutCloud reuses CloudSyncedList for an atomic versioned layout snapshot; initial defaults and migrations never publish over an incoming account layout.

Appearance has separate persisted Display Mode and Color Palette controls. System follows
the OS; Light/Dark override it immediately. Global palettes supply defaults without overwriting
individual Home colors, source colors or installed icons. Mac retains its desktop appearance.
Home card size and color actions live in long-press/right-click context menus, accessible by
native assistive actions; the Home editor remains the visible route for card management.
Source hymn/tradition cards preserve exact-language prose, provenance and missing-text states.

App-wide Hebrew → Mission selects exact Hebrew Mission prose for Home's hymn, tradition,
feast explanation and reflection. Source content renders RTL independently of the interface.
Switching back restores selected-calendar source behavior immediately. Calendar preference,
date, readings and Bible remain independent. Missing Mission text never borrows another rite,
language or year. Mac uses its existing Today explanation area.

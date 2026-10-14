# Native workflow contract

Authoritative business and data sources are [AGENTS.md](AGENTS.md),
[Shared/ARCHITECTURE.markdown](Shared/ARCHITECTURE.markdown),
[Shared/schema/domain-model.json](Shared/schema/domain-model.json),
[Shared/schema/home-widgets.json](Shared/schema/home-widgets.json), and the canonical
`Shared/content` / `Shared/data` records. [DESIGN.md](DESIGN.md) documents visual intent.
This contract covers the 0.21 native changes; existing architecture continues to govern other flows.

| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
|---|---|---|---|---|
| Select/Listbox | Native Appearance color pickers and existing edition/language pickers | Native settings and domain schema | Platform-native picker/menu | Native build, settings and fallback tests |
| Date | Window TodayDateSelection and source-aware event month-grid owners | Canonical calendar date records | Native CalendarView / shared SwiftUI or Compose month grid | Event counts, missing dates, RTL and shared-date tests |
| Form | AppSettings and private HomePhotoStore/HomePhotos owners | Shared preference keys and private-photo contract | Custom accent / card image | Validation, persistence, failed import preservation |
| Scrollbar | Native ScrollView, Compose scroll containers, WinUI scrolling controls | Platform conventions | Page / bounded native sheet body | Build and reachable-action inspection |
| CRUD | Home widget preferences and app-private photo store | Shared home-widgets schema | Add/change/remove image; add/remove/reorder card | Existing photo tests and new card-state tests |
| Toast | Existing native inline error/alert owners | Platform sibling flows | Recoverable import or passage error | Focused failure-path tests |

Home expansion changes only that card's size. It preserves widget order, the selected civil
date, images, settings and the prayer session. Removing a card is independent of hiding its
content. Image replacement installs a validated private copy before discarding the previous
copy; failure keeps the old image. It never modifies the user's original photo.

Calendar markers count individual supplied observances, falling back to one parent event when
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

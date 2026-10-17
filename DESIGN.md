---
version: alpha
name: Prosary native design
description: A quiet multilingual prayer library with native controls and source-faithful devotional artwork.
colors:
  primary: "#1768AC"
typography:
  sans:
    fontFamily: "system-ui, sans-serif"
  mono:
    fontFamily: "ui-monospace, monospace"
omitted:
  - section: spacing
    reason: Native adaptive layout owners define platform-specific spacing.
  - section: rounded
    reason: Native card and control components define platform-specific shape.
components:
  card: {}
  button: {}
  dialog: {}
---

# Prosary native design

## Overview

Prosary is a prayer library and daily Catholic calendar for recurring personal use on phones,
tablets and desktop computers. Its visual reference is a well-organized personal prayer book:
quiet controls, readable sourced text and meaningful devotional pictures. The signature is
authored prayer artwork alongside multilingual prayer names, with expandable daily cards.
This is a product interface; legibility and familiar native behavior govern each platform.
It does not adopt a marketing-page composition or decorative motion.

English, Hebrew, Arabic, Russian, Filipino, French, Italian and Ukrainian share the same
behavior. Hebrew and Arabic use actual RTL layout. Prayer-language text and interface-language
controls remain independent. Sourced prayer and Scripture wording is never generated to fill
an empty interface state.

`DESIGN.md` is the conventional filename required by the design auditor. Other new prose
documents use `.markdown`. [Shared/ARCHITECTURE.markdown](Shared/ARCHITECTURE.markdown) and
[Shared/MAC-EXPERIENCE.markdown](Shared/MAC-EXPERIENCE.markdown) own native product behavior.
[UX-CONTRACT.markdown](UX-CONTRACT.markdown) records the touched workflow owners.

## Colors

The canonical preset palette remains [Shared/Branding/app-colors.json](Shared/Branding/app-colors.json).
The values above mirror that runtime source; this document does not generate another palette.
`appColor` chooses the app icon and preset accent. `customAccentColorHex` is an optional
device preference containing uppercase `#RRGGBB`, or empty to use the preset. It changes
control/link accents independently of icons, authored artwork, prayer tags and liturgical colors.
Native theme adapters preserve the selected hue while adjusting lightness for readable contrast.
Foreground accents target at least 4.5:1 against their corresponding native content surface.
Android preset selection clears a custom accent and turns off wallpaper colors; custom selection also turns off wallpaper colors. Users may explicitly re-enable them.
Mac controls retain the live system accent and the existing coherent desktop experience.

| Runtime source | Adapter | Consumers |
|---|---|---|
| Shared preset palette + customAccentColorHex | Apple AppColor, Android AppColor/Theme, Windows AppColor/theme resources | Native controls, links, focus/selection |
| System/native semantic surfaces | ContentCardBackground, Material surfaces, WinUI theme resources | Daily cards, readers, dialogs |
| Calendar source rank/season | Platform liturgical-color adapters | Event indicators and prayer status |
| .prosaryprayer gallery artwork | Platform pack image resolvers | Pray/library cards |

## Typography

Controls use the platform system family and native text hierarchy. Prayer bodies retain the
existing user-configurable typography and script-specific fonts. Calendar dates and small
captions use native utility text. Long translations wrap; a card's compact form limits its
summary but never removes access to the full text. Hebrew niqqud, Syriac scripts, Bible verse
labels and source punctuation keep the existing content typography contracts.

## Layout

Home includes the weekly Torah portion and haftarot as a default card and uses an adaptive one-to-three-column grid with readable 340-point/dp minimum cards and native desktop/tablet navigation.
Apple retains its 20-point page / 18-point card rhythm; Android retains 16-dp card padding
and 12-dp card gaps; Windows keeps its existing native resource spacing. Small and large cards
use the same heading and controls, changing the visible content rather than the navigation.
Each visible card supports expansion independently of its order. The event month grid is
Monday-first civil Gregorian, mirrors naturally in RTL, and marks every published date.

## Elevation & Depth

Scrolling content uses opaque semantic card surfaces. System bars, toolbars, sheets, menus
and date popovers own their appearance. Existing Apple navigation glass remains navigation
material; it is not added behind Scripture or biographies. Images have bounded geometry;
missing images cannot displace their card's controls.

## Shapes

Reuse native button, menu, disclosure, picker and dialog shapes. Card pictures use the existing
rounded image treatment and preserve proportions. Event markers are small dots below the
date, capped visually at three; accessible date labels retain the full event count.

## Components

### Foundational visual states

Native controls retain keyboard focus, hover, pressed, selected and disabled states. Expanded
and collapsed headers have localized action names. Missing dates, missing descriptions and
unavailable Scripture remain explicit localized states. Native error feedback uses the same
owner as sibling import/read flows; no new toast or loading system is introduced.

### Buttons and actions

Expansion is a button separate from the card's open action. Image add/change/remove on cards other than feast explanations uses
the existing native photo picker and private image-store recovery path. Changing or resetting
the accent applies immediately in Appearance. Standard palette choices and custom colors
remain visibly distinguishable from semantic liturgical status colors.

### Navigation and data display

The Event Calendar shows every published date for the selected calendar, and each supplied
observance is independently clickable. A detail view carries the exact-language source prose
and attribution. Readings for this Date updates the window's shared date and opens the existing
Daily Readings flow. Holy Scripture offers the appointed Gospel (or first source appointment)
as Scripture of the Day, reusing the existing offline passage reader and edition selection.

### Forms and overlays

Color and image selection use maintained native pickers. Events use native sheets/dialogs,
with standard dismissal, scrolling and focus behavior. Small screens retain reachable actions.
The shared month-grid owner supplies source-aware dates and event markers to its consumers.

### Iconography

Apple uses SF Symbols, Android its existing Material vector icons, and Windows its native
symbol/icon resources. Pictures come from the owning pack or an app-private user-selected
copy. Private image paths are device-local and do not enter portable prayer packs or cloud state.

### Motion

Expansion only communicates a content state change. Respect platform reduced-motion settings;
no decorative, mandatory or automatically repeating animation is added.

### Content and data visualization

Use plain action names and source paragraphs. No synthesized event biographies, prayer
translations or daily Scripture substitutes. Creed availability and Filioque presentation
belong to the effective authored content's internal metadata, with no user toggle.

## Do's and Don'ts

- Keep source identity, Scripture numbering and attribution visible where applicable.
- Reuse native shared owners and persist compact/large state independently of card order.
- Keep icons, custom accent, liturgical colors and authored images as separate choices.
- Preserve the Mac library/Today workflow instead of adding a phone dashboard for parity.

Home cards offer Set Accent Color… with Blue, Green, Gold and Rose through native palette menus. Remove Accent Color appears only when a card has an override and restores its native appearance independently of other cards. Tints composite over opaque native surfaces and retain readable semantic foregrounds in light, dark and high contrast. Available pane width chooses columns; active fold and camera regions constrain the safe content pane. Apple’s existing iCloud preferences sync an atomic card arrangement, size and color snapshot after explicit edits. Photos, dates and responsive columns stay device-local.

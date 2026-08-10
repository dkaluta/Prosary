# Shared/schema

Machine-readable, non-prose description of Prosary's app structure — a companion to
[`../ARCHITECTURE.md`](../ARCHITECTURE.md), which covers the same ground in prose. Where
`ARCHITECTURE.md` explains *why*, these files pin down the exact *shape*: type/field names,
defaults, enum cases, screen parameters, and content keys, cross-referenced against all three
platforms (iOS is canonical; Android and Windows are ports verified against it).

| File | Covers |
|---|---|
| `domain-model.json` | `Prayer` and every type it's built from — `PrayerKind`, `RosaryOptions`, `MysterySelectionMode`, `MysteryGroup`, `EternalRestPlacement`, `MarianAntiphonOption`, `JesusPrayerOptions`/`Target`/`Progress`, `PrayerReminder`, `LanguageOption`, `RosaryStep`, `CustomDevotionStep`, `DevotionHour`/`DevotionProper` — field names, types, defaults. |
| `content-keys.json` | The full `PrayerKey` catalog — every stable, language-independent identifier for a fixed prayer text, translated into the shipped prayer languages. |
| `mysteries.json` | The 20 Rosary mysteries (group/order/imageKey) plus the fixed override-image keys used by steps not tied to a specific mystery. |
| `stations.json` | The 14 Stations of the Cross (order/imageKey/title) and image-sourcing/language-coverage status. |
| `seven-sorrows.json` | The 7 Sorrows of Mary (order/imageKey/title/isScripture), the 7-per-decade override, and image-sourcing/language-coverage status. |
| `screens.json` | Every screen/page, its parameters, and how navigation reaches it on each platform — including the one deliberate structural divergence (Windows skips iOS/Android's generic id-based prayer-dispatch indirection). |

## Why this exists alongside prose docs

A prose doc can drift without anyone noticing — a sentence describing a field that no longer
exists still *reads* fine. A JSON file with a name/type/default is either right or wrong, and a
person (or a future AI session) diffing it against the actual source files will catch the drift
immediately. That's the whole value of these files: they're small enough to audit at a glance,
structured enough that a mismatch is obvious, and language-agnostic so no one platform's syntax
leaks into the "canonical" description.

## Keep these in sync — this is not optional

**Every major change to the domain model, content keys, mystery catalog, or screen/navigation
structure — on *any* platform (iOS, Android, or Windows) — must be reflected in the relevant file
here in the same change, not as a follow-up.** This includes:

- Adding, removing, or renaming a field, type, or enum case in the domain model.
- Adding, removing, or renaming a `PrayerKey`.
- Adding, removing, or reordering a mystery or an override-image key.
- Adding, removing, or changing the parameters of a screen, or changing how navigation reaches it.

If a change to one platform reveals that these files were already out of sync with the *other*
two platforms, fix the drift as part of that same change rather than leaving a note for later.

These files have no independent test or CI check enforcing this (`Shared/` is not itself a git
repository — see the note in `../ARCHITECTURE.md`), so the discipline is manual. Treat a PR/commit
that changes shape covered by one of these files but doesn't touch the matching JSON as incomplete.

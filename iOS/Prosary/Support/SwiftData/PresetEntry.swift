//
//  PresetEntry.swift
//  Prosary
//

import SwiftData
import Foundation

// CloudKit-backed SwiftData stores (see AppServices.modelContainer) impose two constraints on
// every @Model this schema declares, neither of which held before this file was made syncable:
// no unique constraints (CloudKit records have no equivalent) — id is no longer @Attribute(.unique),
// with the store's own application-level id-matching in SwiftDataPresetStore doing the same job the
// database-level constraint used to — and every property needs an inline default value (a value
// only ever assigned inside a custom init doesn't count towards CloudKit's schema validation).
@Model
final class PresetEntry {
  var id: UUID = UUID()
  var name: String = ""
  var isDefault: Bool = false
  var languageCode: String = ""

  // Discriminant — "rosary" / "jesusPrayer" / "custom", plus legacy per-devotion strings
  // ("angelus", "stationsOfTheCross", ...) on rows written before the generic-devotion
  // migration — see `resolvedKind`. Default "rosary" handles existing rows when the schema is
  // extended with this field.
  var kind: String = "rosary"

  // Bundle id for a generic (kind == "custom") devotion, e.g. "trisagion". Nil for every other
  // kind. Optional handles existing rows predating this field.
  var customDevotionId: String? = nil

  // Which bundle variant (alternate step-set) this favorite prays; nil = the bundle's default.
  // Optional handles existing rows predating this field (SwiftData lightweight migration).
  var variantId: String? = nil

  // JSON-encoded [String: String] of the favorite's options.json choices (see
  // Prayer.customOptions). Default empty Data handles existing rows.
  var customOptionsJSON: Data = Data()

  // Rosary-specific fields (populated when kind == "rosary")
  var mysterySelectionMode: MysterySelectionMode = MysterySelectionMode.todaysMysteries
  var specificMysteryGroup: MysteryGroup = MysteryGroup.joyful
  // 1-based index into MysteryCatalog.forGroup(specificMysteryGroup); used only when
  // mysterySelectionMode is .singleMystery. Default 1 handles existing rows.
  var specificMysteryOrder: Int = 1
  var includeApostlesCreed: Bool = true
  var includeOpeningPrayers: Bool = true
  var includeFatimaPrayers: Bool = true
  var eternalRestForDeceased: EternalRestPlacement = EternalRestPlacement.none
  var marianAntiphon: MarianAntiphonOption = MarianAntiphonOption.seasonal
  // Default false handles existing rows.
  var includeClosingIntentions: Bool = false
  var includeStMichaelPrayer: Bool = false
  var includeFinalSignOfCross: Bool = true
  // Raw String for safe lightweight migration of existing SwiftData rows.
  var aramaicSignOfCrossForm: String = AramaicSignOfCrossForm.formA
  // Default false handles existing rows.
  var presenterMode: Bool = false
  // Default "classic" handles existing rows. Stored as the raw string, not the enum type:
  // SwiftData lightweight-migrates a missing String column to its default, but a column of an
  // enum type added to an existing store trips a swift_dynamicCastFailure abort in the
  // generated getter the first time an old row is read (observed 2026-08-13; the older enum
  // columns above predate every shipped store, so they never hit this).
  var mysteryImageStyleRaw: String = MysteryImageStyle.classic.rawValue

  // Jesus Prayer-specific fields (populated when kind == "jesusPrayer")
  var jesusPrayerIsUnbounded: Bool = false
  var jesusPrayerCount: Int = 33

  // Reminders — JSON-encoded [PrayerReminder]. Default empty Data handles existing rows.
  var remindersJSON: Data = Data()

  init(prayer: Prayer) {
    id = prayer.id
    name = prayer.name
    isDefault = prayer.isDefault
    languageCode = prayer.languageCode
    kind = prayer.kind.rawValue
    customDevotionId = prayer.customDevotionId
    variantId = prayer.variantId
    customOptionsJSON = (try? JSONEncoder().encode(prayer.customOptions)) ?? Data()

    mysterySelectionMode = prayer.rosary.mysterySelectionMode
    specificMysteryGroup = prayer.rosary.specificMysteryGroup
    specificMysteryOrder = prayer.rosary.specificMysteryOrder
    includeApostlesCreed = prayer.rosary.includeApostlesCreed
    includeOpeningPrayers = prayer.rosary.includeOpeningPrayers
    includeFatimaPrayers = prayer.rosary.includeFatimaPrayer
    eternalRestForDeceased = prayer.rosary.eternalRestForDeceased
    marianAntiphon = prayer.rosary.marianAntiphon
    includeClosingIntentions = prayer.rosary.includeClosingIntentions
    includeStMichaelPrayer = prayer.rosary.includeStMichaelPrayer
    includeFinalSignOfCross = prayer.rosary.includeFinalSignOfCross
    aramaicSignOfCrossForm = prayer.rosary.aramaicSignOfCrossForm
    presenterMode = prayer.rosary.presenterMode
    mysteryImageStyleRaw = prayer.rosary.mysteryImageStyle.rawValue

    if case .count(let n) = prayer.jesusPrayer.target {
      jesusPrayerIsUnbounded = false
      jesusPrayerCount = n
    } else {
      jesusPrayerIsUnbounded = true
      jesusPrayerCount = 33
    }

    remindersJSON = (try? JSONEncoder().encode(prayer.reminders)) ?? Data()
  }

  func update(from prayer: Prayer) {
    name = prayer.name
    isDefault = prayer.isDefault
    languageCode = prayer.languageCode
    kind = prayer.kind.rawValue
    customDevotionId = prayer.customDevotionId
    variantId = prayer.variantId
    customOptionsJSON = (try? JSONEncoder().encode(prayer.customOptions)) ?? Data()

    mysterySelectionMode = prayer.rosary.mysterySelectionMode
    specificMysteryGroup = prayer.rosary.specificMysteryGroup
    specificMysteryOrder = prayer.rosary.specificMysteryOrder
    includeApostlesCreed = prayer.rosary.includeApostlesCreed
    includeOpeningPrayers = prayer.rosary.includeOpeningPrayers
    includeFatimaPrayers = prayer.rosary.includeFatimaPrayer
    eternalRestForDeceased = prayer.rosary.eternalRestForDeceased
    marianAntiphon = prayer.rosary.marianAntiphon
    includeClosingIntentions = prayer.rosary.includeClosingIntentions
    includeStMichaelPrayer = prayer.rosary.includeStMichaelPrayer
    includeFinalSignOfCross = prayer.rosary.includeFinalSignOfCross
    aramaicSignOfCrossForm = prayer.rosary.aramaicSignOfCrossForm
    presenterMode = prayer.rosary.presenterMode
    mysteryImageStyleRaw = prayer.rosary.mysteryImageStyle.rawValue

    if case .count(let n) = prayer.jesusPrayer.target {
      jesusPrayerIsUnbounded = false
      jesusPrayerCount = n
    } else {
      jesusPrayerIsUnbounded = true
      jesusPrayerCount = 33
    }

    remindersJSON = (try? JSONEncoder().encode(prayer.reminders)) ?? Data()
  }

  /// Maps this row's stored kind to the post-generic-devotions model: an unknown raw kind
  /// string is a legacy per-devotion kind ("angelus", "stationsOfTheCross", ...) whose rawValue
  /// deliberately doubles as its bundle id. Permanent read-time behavior, NOT a one-shot
  /// migration — CloudKit can sync rows written by old app versions in at any time.
  var resolvedKind: (kind: PrayerKind, customDevotionId: String?) {
    if let known = PrayerKind(rawValue: kind) {
      return (known, customDevotionId)
    }
    return (.custom, customDevotionId ?? kind)
  }

  func toPrayer() -> Prayer {
    let jpTarget: JesusPrayerTarget = jesusPrayerIsUnbounded
      ? .unbounded
      : .count(jesusPrayerCount)

    let resolved = resolvedKind
    return Prayer(
      id: id,
      name: name,
      kind: resolved.kind,
      isDefault: isDefault,
      languageCode: languageCode,
      rosary: RosaryOptions(
        mysterySelectionMode: mysterySelectionMode,
        specificMysteryGroup: specificMysteryGroup,
        specificMysteryOrder: specificMysteryOrder,
        includeApostlesCreed: includeApostlesCreed,
        includeOpeningPrayers: includeOpeningPrayers,
        includeFatimaPrayer: includeFatimaPrayers,
        eternalRestForDeceased: eternalRestForDeceased,
        marianAntiphon: marianAntiphon,
        includeClosingIntentions: includeClosingIntentions,
        includeStMichaelPrayer: includeStMichaelPrayer,
        includeFinalSignOfCross: includeFinalSignOfCross,
        aramaicSignOfCrossForm: aramaicSignOfCrossForm,
        presenterMode: presenterMode,
        mysteryImageStyle: MysteryImageStyle(rawValue: mysteryImageStyleRaw) ?? .classic
      ),
      jesusPrayer: JesusPrayerOptions(target: jpTarget),
      customDevotionId: resolved.customDevotionId,
      variantId: variantId,
      customOptions: (try? JSONDecoder().decode([String: String].self, from: customOptionsJSON)) ?? [:],
      reminders: (try? JSONDecoder().decode([PrayerReminder].self, from: remindersJSON)) ?? []
    )
  }
}

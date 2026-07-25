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

  // Discriminant — "rosary" / "angelus" / "jesusPrayer". Default "rosary" handles
  // existing rows when the schema is extended with this field.
  var kind: String = "rosary"

  // Rosary-specific fields (populated when kind == "rosary")
  var mysterySelectionMode: MysterySelectionMode = MysterySelectionMode.todaysMysteries
  var specificMysteryGroup: MysteryGroup = MysteryGroup.joyful
  var includeApostlesCreed: Bool = true
  var includeOpeningPrayers: Bool = true
  var includeFatimaPrayers: Bool = true
  var eternalRestForDeceased: EternalRestPlacement = EternalRestPlacement.none
  var marianAntiphon: MarianAntiphonOption = MarianAntiphonOption.seasonal
  var includeStMichaelPrayer: Bool = false
  var includeFinalSignOfCross: Bool = true

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

    mysterySelectionMode = prayer.rosary.mysterySelectionMode
    specificMysteryGroup = prayer.rosary.specificMysteryGroup
    includeApostlesCreed = prayer.rosary.includeApostlesCreed
    includeOpeningPrayers = prayer.rosary.includeOpeningPrayers
    includeFatimaPrayers = prayer.rosary.includeFatimaPrayer
    eternalRestForDeceased = prayer.rosary.eternalRestForDeceased
    marianAntiphon = prayer.rosary.marianAntiphon
    includeStMichaelPrayer = prayer.rosary.includeStMichaelPrayer
    includeFinalSignOfCross = prayer.rosary.includeFinalSignOfCross

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

    mysterySelectionMode = prayer.rosary.mysterySelectionMode
    specificMysteryGroup = prayer.rosary.specificMysteryGroup
    includeApostlesCreed = prayer.rosary.includeApostlesCreed
    includeOpeningPrayers = prayer.rosary.includeOpeningPrayers
    includeFatimaPrayers = prayer.rosary.includeFatimaPrayer
    eternalRestForDeceased = prayer.rosary.eternalRestForDeceased
    marianAntiphon = prayer.rosary.marianAntiphon
    includeStMichaelPrayer = prayer.rosary.includeStMichaelPrayer
    includeFinalSignOfCross = prayer.rosary.includeFinalSignOfCross

    if case .count(let n) = prayer.jesusPrayer.target {
      jesusPrayerIsUnbounded = false
      jesusPrayerCount = n
    } else {
      jesusPrayerIsUnbounded = true
      jesusPrayerCount = 33
    }

    remindersJSON = (try? JSONEncoder().encode(prayer.reminders)) ?? Data()
  }

  func toPrayer() -> Prayer {
    let jpTarget: JesusPrayerTarget = jesusPrayerIsUnbounded
      ? .unbounded
      : .count(jesusPrayerCount)

    return Prayer(
      id: id,
      name: name,
      kind: PrayerKind(rawValue: kind) ?? .rosary,
      isDefault: isDefault,
      languageCode: languageCode,
      rosary: RosaryOptions(
        mysterySelectionMode: mysterySelectionMode,
        specificMysteryGroup: specificMysteryGroup,
        includeApostlesCreed: includeApostlesCreed,
        includeOpeningPrayers: includeOpeningPrayers,
        includeFatimaPrayer: includeFatimaPrayers,
        eternalRestForDeceased: eternalRestForDeceased,
        marianAntiphon: marianAntiphon,
        includeStMichaelPrayer: includeStMichaelPrayer,
        includeFinalSignOfCross: includeFinalSignOfCross
      ),
      jesusPrayer: JesusPrayerOptions(target: jpTarget),
      reminders: (try? JSONDecoder().decode([PrayerReminder].self, from: remindersJSON)) ?? []
    )
  }
}

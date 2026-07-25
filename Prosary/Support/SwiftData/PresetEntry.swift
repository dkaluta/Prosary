//
//  PresetEntry.swift
//  Prosary
//

import SwiftData
import Foundation

@Model
final class PresetEntry {
  @Attribute(.unique) var id: UUID
  var name: String
  var isDefault: Bool
  var languageCode: String

  // Discriminant — "rosary" / "angelus" / "jesusPrayer". Default "rosary" handles
  // existing rows when the schema is extended with this field.
  var kind: String = "rosary"

  // Rosary-specific fields (populated when kind == "rosary")
  var mysterySelectionMode: MysterySelectionMode
  var specificMysteryGroup: MysteryGroup
  var includeApostlesCreed: Bool
  var includeOpeningPrayers: Bool
  var includeFatimaPrayers: Bool
  var eternalRestForDeceased: EternalRestPlacement
  var marianAntiphon: MarianAntiphonOption
  var includeStMichaelPrayer: Bool
  var includeFinalSignOfCross: Bool

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


//
//  RosaryOptions.swift
//  Prosary
//
//  Configuration options specific to the Rosary. Lives inside a Prayer when kind == .rosary.
//

import Foundation

struct RosaryOptions: Hashable, Codable {
  var mysterySelectionMode: MysterySelectionMode = .todaysMysteries

  /// Used only when `mysterySelectionMode` is `.specific`.
  var specificMysteryGroup: MysteryGroup = .joyful

  var includeApostlesCreed: Bool = true

  /// The opening Our Father + 3 Hail Marys (for faith, hope, and charity) + Glory Be.
  var includeOpeningPrayers: Bool = true

  /// The Fatima Prayer ("O my Jesus...") recited after the Glory Be of each decade.
  var includeFatimaPrayer: Bool = true

  var eternalRestForDeceased: EternalRestPlacement = .none

  var marianAntiphon: MarianAntiphonOption = .seasonal

  var includeStMichaelPrayer: Bool = false

  var includeFinalSignOfCross: Bool = true

  var mysterySelectionSummary: String {
    switch mysterySelectionMode {
    case .specific:
      return String(localized: "rosaryOptions.summary.always", defaultValue: "Always \(specificMysteryGroup.displayName)")
    case .fifteenMystery:
      return String(localized: "rosaryOptions.summary.fifteenMystery", defaultValue: "The 15 Mysteries")
    case .twentyMystery:
      return String(localized: "rosaryOptions.summary.twentyMystery", defaultValue: "The 20 Mysteries")
    case .todaysMysteries:
      return String(localized: "mysterySelectionMode.todaysMysteries", defaultValue: "Today's Mysteries")
    }
  }
}

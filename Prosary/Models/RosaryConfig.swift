//
//  RosaryConfig.swift
//  Prosary
//
//  A saved, user-configurable Rosary preset. Persisted via a PresetStore implementation.
//

import Foundation

struct RosaryConfig: Identifiable, Hashable, Codable {
    var id = UUID()

    var name: String = "My Rosary"

    /// The one preset used when the user just taps "Pray" without picking one explicitly.
    var isDefault: Bool = false

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

    /// Prayer language for this preset. See `LanguageCatalog`.
    var languageCode: String = LanguageCatalog.defaultCode

    var isNotDefault: Bool { !isDefault }

    var languageNativeName: String { LanguageCatalog.resolve(languageCode).nativeName }

    var mysterySelectionSummary: String {
        switch mysterySelectionMode {
        case .specific: return "Always \(specificMysteryGroup.displayName)"
        case .fifteenMystery: return "The 15 Mysteries"
        case .twentyMystery: return "The 20 Mysteries"
        case .todaysMysteries: return "Today's Mysteries"
        }
    }
}

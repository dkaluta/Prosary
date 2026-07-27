//
//  MarianAntiphonOption.swift
//  Prosary
//

import Foundation

/// Which closing Marian antiphon (if any) follows the Rosary.
enum MarianAntiphonOption: String, Codable, CaseIterable, Identifiable {
  case none
  /// Pick the antiphon proper to the current liturgical season automatically.
  case seasonal
  case salveRegina
  case almaRedemptorisMater
  case aveReginaCaelorum
  case reginaCaeli
  case subTuumPraesidium

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .none:                 return String(localized: "marianAntiphon.none", defaultValue: "None")
    case .seasonal:             return String(localized: "marianAntiphon.seasonal", defaultValue: "Automatic (Seasonal)")
    case .salveRegina:          return String(localized: "marianAntiphon.salveRegina", defaultValue: "Salve Regina")
    case .almaRedemptorisMater: return String(localized: "marianAntiphon.almaRedemptorisMater", defaultValue: "Alma Redemptoris Mater")
    case .aveReginaCaelorum:    return String(localized: "marianAntiphon.aveReginaCaelorum", defaultValue: "Ave Regina Caelorum")
    case .reginaCaeli:          return String(localized: "marianAntiphon.reginaCaeli", defaultValue: "Regina Caeli")
    case .subTuumPraesidium:    return String(localized: "marianAntiphon.subTuumPraesidium", defaultValue: "Sub Tuum Praesidium")
    }
  }
}

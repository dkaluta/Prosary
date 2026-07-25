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
    case .none:                 return String(localized: "None")
    case .seasonal:             return String(localized: "Automatic (Seasonal)")
    case .salveRegina:          return String(localized: "Salve Regina")
    case .almaRedemptorisMater: return String(localized: "Alma Redemptoris Mater")
    case .aveReginaCaelorum:    return String(localized: "Ave Regina Caelorum")
    case .reginaCaeli:          return String(localized: "Regina Caeli")
    case .subTuumPraesidium:    return String(localized: "Sub Tuum Praesidium")
    }
  }
}

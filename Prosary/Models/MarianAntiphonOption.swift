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
        case .none: return "None"
        case .seasonal: return "Automatic (Seasonal)"
        case .salveRegina: return "Salve Regina"
        case .almaRedemptorisMater: return "Alma Redemptoris Mater"
        case .aveReginaCaelorum: return "Ave Regina Caelorum"
        case .reginaCaeli: return "Regina Caeli"
        case .subTuumPraesidium: return "Sub Tuum Praesidium"
        }
    }
}

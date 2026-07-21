//
//  MysteryGroup.swift
//  Prosary
//

import Foundation

/// One of the four traditional sets of Rosary mysteries.
enum MysteryGroup: String, Codable, CaseIterable, Identifiable {
    case joyful
    case sorrowful
    case glorious
    case luminous

    var id: String { rawValue }

    /// Display name in English, used as a fallback when no localized name is supplied by the
    /// content layer (e.g. in preset summaries before the real backend is wired up).
    var displayName: String {
        switch self {
        case .joyful: return "Joyful"
        case .sorrowful: return "Sorrowful"
        case .glorious: return "Glorious"
        case .luminous: return "Luminous"
        }
    }
}

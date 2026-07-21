//
//  EternalRestPlacement.swift
//  Prosary
//

import Foundation

/// Where (if at all) "Eternal rest grant unto them, O Lord" is prayed for the faithful departed.
enum EternalRestPlacement: String, Codable, CaseIterable, Identifiable {
    case none
    /// Pray it after the Glory Be of every decade.
    case afterEachDecade
    /// Pray it once, near the end, before the closing prayers.
    case atEndOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Don't Include"
        case .afterEachDecade: return "After Each Decade"
        case .atEndOnly: return "Once, Near the End"
        }
    }
}

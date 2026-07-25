
//
//  PrayerKind.swift
//  Prosary
//

import Foundation

/// Discriminant for the type of a saved prayer session.
/// Add new cases here (and a matching options struct) to expand into new devotions.
enum PrayerKind: String, CaseIterable, Codable, Hashable {
  case rosary
  case angelus
  case jesusPrayer

  var displayName: String {
    switch self {
    case .rosary:      return String(localized: "Rosary")
    case .angelus:     return String(localized: "Angelus")
    case .jesusPrayer: return String(localized: "Jesus Prayer")
    }
  }

  /// Default name suggested when the user creates a new favorite of this kind.
  var defaultName: String {
    switch self {
    case .rosary:      return String(localized: "My Rosary")
    case .angelus:     return String(localized: "Angelus")
    case .jesusPrayer: return String(localized: "Jesus Prayer")
    }
  }

  var systemImage: String {
    switch self {
    case .rosary:      return "circle.grid.cross"
    case .angelus:     return "bell"
    case .jesusPrayer: return "heart"
    }
  }
}

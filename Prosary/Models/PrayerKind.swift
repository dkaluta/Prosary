
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
  case stationsOfTheCross
  case franciscanCrown
  case sevenSorrows
  case divineMercyChaplet

  var displayName: String {
    switch self {
    case .rosary:             return String(localized: "prayerKind.rosary", defaultValue: "Rosary")
    case .angelus:            return String(localized: "prayerKind.angelus", defaultValue: "Angelus")
    case .jesusPrayer:        return String(localized: "prayerKind.jesusPrayer", defaultValue: "Jesus Prayer")
    case .stationsOfTheCross: return String(localized: "prayerKind.stationsOfTheCross", defaultValue: "Stations of the Cross")
    case .franciscanCrown:    return String(localized: "prayerKind.franciscanCrown", defaultValue: "Franciscan Crown")
    case .sevenSorrows:       return String(localized: "prayerKind.sevenSorrows", defaultValue: "Seven Sorrows")
    case .divineMercyChaplet: return String(localized: "prayerKind.divineMercyChaplet", defaultValue: "Divine Mercy Chaplet")
    }
  }

  /// Default name suggested when the user creates a new favorite of this kind.
  var defaultName: String {
    switch self {
    case .rosary:             return String(localized: "prayerKind.defaultName.rosary", defaultValue: "My Rosary")
    case .angelus:            return String(localized: "prayerKind.angelus", defaultValue: "Angelus")
    case .jesusPrayer:        return String(localized: "prayerKind.jesusPrayer", defaultValue: "Jesus Prayer")
    case .stationsOfTheCross: return String(localized: "prayerKind.stationsOfTheCross", defaultValue: "Stations of the Cross")
    case .franciscanCrown:    return String(localized: "prayerKind.franciscanCrown", defaultValue: "Franciscan Crown")
    case .sevenSorrows:       return String(localized: "prayerKind.sevenSorrows", defaultValue: "Seven Sorrows")
    case .divineMercyChaplet: return String(localized: "prayerKind.divineMercyChaplet", defaultValue: "Divine Mercy Chaplet")
    }
  }

  var systemImage: String {
    switch self {
    case .rosary:             return "circle.grid.cross"
    case .angelus:            return "bell"
    case .jesusPrayer:        return "heart"
    case .stationsOfTheCross: return "figure.walk"
    case .franciscanCrown:    return "crown"
    case .sevenSorrows:       return "drop"
    case .divineMercyChaplet: return "sun.max"
    }
  }
}

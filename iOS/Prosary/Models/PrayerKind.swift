
//
//  PrayerKind.swift
//  Prosary
//
//  Discriminant for the type of a saved prayer session. Only structurally unique sessions get a
//  case: the Rosary (deeply configurable, calendar-driven), the Jesus Prayer (a repetition
//  counter, no steps), and `custom` — the single case covering every bundle-driven devotion
//  (Angelus, Stations of the Cross, Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet,
//  Trisagion, and any future .prosaryprayer with a devotion.json). Adding a devotion means
//  authoring a bundle, never a new case here.
//

import Foundation

enum PrayerKind: String, CaseIterable, Codable, Hashable {
  case rosary
  case jesusPrayer

  /// Any devotion whose entire step sequence comes from a bundle's `devotion.json` — see
  /// `PrayerEngine.buildCustomDevotionSteps` and `Prayer.customDevotionId`. `displayName`/
  /// `systemImage`/`defaultName` below return a generic fallback for this case — real call sites
  /// (Home, Favorites) read the actual devotion's name/icon from `PrayerPackStore.info(for:)`,
  /// since a single `PrayerKind` value can't carry per-bundle data.
  case custom

  var displayName: String {
    switch self {
    case .rosary:      return String(localized: "prayerKind.rosary", defaultValue: "Rosary")
    case .jesusPrayer: return String(localized: "prayerKind.jesusPrayer", defaultValue: "Jesus Prayer")
    case .custom:      return String(localized: "prayerKind.custom", defaultValue: "Devotion")
    }
  }

  /// Default name suggested when the user creates a new favorite of this kind.
  var defaultName: String {
    switch self {
    case .rosary:      return String(localized: "prayerKind.defaultName.rosary", defaultValue: "My Rosary")
    case .jesusPrayer: return String(localized: "prayerKind.jesusPrayer", defaultValue: "Jesus Prayer")
    case .custom:      return String(localized: "prayerKind.custom", defaultValue: "Devotion")
    }
  }

  var systemImage: String {
    switch self {
    case .rosary:      return "circle.grid.cross"
    case .jesusPrayer: return "heart"
    case .custom:      return "sparkles"
    }
  }
}

//
//  MysterySelectionMode.swift
//  Prosary
//

import Foundation

/// How a `RosaryConfig` decides which mystery group(s) to pray in a given session.
enum MysterySelectionMode: String, Codable, CaseIterable, Identifiable {
  /// Follow the traditional weekday assignment (with liturgical-season overrides on Sundays).
  case todaysMysteries

  /// Always pray a specific, user-chosen set regardless of the day.
  case specific

  /// The traditional 15 mysteries: Joyful, Sorrowful, and Glorious (no Luminous), prayed in one session.
  case fifteenMystery

  /// All 20 mysteries in one session, in the chronological order of Christ's life: Joyful, Luminous, Sorrowful, Glorious.
  case twentyMystery

  /// Pray exactly one specific mystery (one decade) — see `RosaryOptions.specificMysteryOrder`.
  /// Added last, not grouped with `.specific` above: Windows persists this enum by raw integer
  /// ordinal (not name), so inserting a case earlier would silently reassign the stored values of
  /// every case after it for existing saved favorites. Keep new cases appended here even though
  /// iOS/Android's own storage (string-keyed) wouldn't require it.
  case singleMystery

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .todaysMysteries: return String(localized: "mysterySelectionMode.todaysMysteries", defaultValue: "Today's Mysteries")
    case .specific:        return String(localized: "mysterySelectionMode.specific", defaultValue: "Always a Specific Set")
    case .fifteenMystery:  return String(localized: "mysterySelectionMode.fifteenMystery", defaultValue: "The 15 Mysteries (Joyful, Sorrowful, Glorious)")
    case .twentyMystery:   return String(localized: "mysterySelectionMode.twentyMystery", defaultValue: "The 20 Mysteries (All Four Sets)")
    case .singleMystery:   return String(localized: "mysterySelectionMode.singleMystery", defaultValue: "One Mystery Only")
    }
  }
}

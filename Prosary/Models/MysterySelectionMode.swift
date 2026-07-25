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

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .todaysMysteries: return String(localized: "Today's Mysteries")
    case .specific:        return String(localized: "Always a Specific Set")
    case .fifteenMystery:  return String(localized: "The 15 Mysteries (Joyful, Sorrowful, Glorious)")
    case .twentyMystery:   return String(localized: "The 20 Mysteries (All Four Sets)")
    }
  }
}

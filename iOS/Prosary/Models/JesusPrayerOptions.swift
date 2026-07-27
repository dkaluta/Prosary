
//
//  JesusPrayerOptions.swift
//  Prosary
//
//  Configuration options specific to the Jesus Prayer. Lives inside a Prayer when kind == .jesusPrayer.
//

import Foundation

struct JesusPrayerOptions: Hashable, Codable {
  var target: JesusPrayerTarget = .count(33)

  var targetDisplayName: String {
    switch target {
    case .count(let n): return "\(n)×"
    case .unbounded:    return String(localized: "jesusPrayerOptions.unbounded", defaultValue: "Unbounded")
    }
  }
}

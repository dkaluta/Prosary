//
//  MysteryGroup.swift
//  Prosary
//

import Foundation
import SwiftUI

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
    case .joyful:    return String(localized: "mysteryGroup.joyful", defaultValue: "Joyful")
    case .sorrowful: return String(localized: "mysteryGroup.sorrowful", defaultValue: "Sorrowful")
    case .glorious:  return String(localized: "mysteryGroup.glorious", defaultValue: "Glorious")
    case .luminous:  return String(localized: "mysteryGroup.luminous", defaultValue: "Luminous")
    }
  }

  var color: Color {
    switch self {
    case .joyful:    return .adaptive(light: "#1565C0", dark: "#1976D2") // blue
    case .sorrowful: return .adaptive(light: "#6A1B9A", dark: "#7B1FA2") // purple
    case .glorious:  return .adaptive(light: "#C62828", dark: "#D32F2F") // red
    case .luminous:  return .adaptive(light: "#2E7D32", dark: "#388E3C") // green
    }
  }
}

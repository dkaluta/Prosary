//
//  MysteryImageStyle.swift
//  Prosary
//
//  Which artwork set illustrates the Rosary's mysteries during a session. The classical
//  paintings are the default; the eastern set is the same 20 mysteries in an
//  Eastern/illuminated-manuscript style (the "eastern_"-prefixed image keys). Windows persists
//  this enum as a raw integer ordinal, so new cases must only ever be appended.
//

import Foundation

enum MysteryImageStyle: String, Codable, CaseIterable, Identifiable {
  case classic
  case eastern

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .classic: return String(localized: "mysteryImageStyle.classic", defaultValue: "Classical paintings")
    case .eastern: return String(localized: "mysteryImageStyle.eastern", defaultValue: "Eastern icons")
    }
  }
}

//
//  StationsTranslations.swift
//  Prosary
//
//  Looks up a Station's display text by imageKey and language code, falling back to Latin (and
//  then a bare placeholder) when a translation is missing. See StationsTranslations+*.swift for
//  the actual per-language tables. Only `la`/`en` are populated for now — `ar`/`he`/`ru`/`tl`
//  fall back to Latin until dedicated translations are added. Mirrors MysteryTranslations.swift.
//

import Foundation

enum StationsTranslations {
  static func get(languageCode: String?, imageKey: String) -> StationText {
    if let languageCode, let table = byLanguage[languageCode], let text = table[imageKey] {
      return text
    }

    return latin[imageKey] ?? StationText(title: imageKey, meditation: "")
  }

  static let byLanguage: [String: [String: StationText]] = [
    "la": latin,
    "en": english,
  ]
}

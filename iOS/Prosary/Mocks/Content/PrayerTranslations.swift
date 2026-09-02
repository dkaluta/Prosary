//
//  PrayerTranslations.swift
//  Prosary
//
//  Looks up fixed prayer text by PrayerKey and language code, falling back to Latin (and then
//  the raw key) when a translation is missing. See PrayerTranslations+*.swift for the actual
//  per-language tables.
//

import Foundation

enum PrayerTranslations {
  @MainActor
  static func get(languageCode: String?, key: PrayerKey) -> String {
    for code in LanguageCatalog.fallbackChain(for: languageCode) {
      if let override = PrayerPackStore.prayerOverride(languageCode: code, key: key) { return override }
      if let text = byLanguage[code]?[key] { return text }
    }

    return latin[key] ?? key.rawValue
  }

  static let byLanguage: [String: [PrayerKey: String]] = [
    "la": latin,
    "en": english,
    "ar": arabic,
    "he": hebrew,
    // The Mission of St. Gamaliel's wording, overlaying plain Hebrew key by key.
    "he-x-gamliel": hebrewGamaliel,
    "el": greek,
    "es": spanish,
    "ru": russian,
    "tl": tagalog,
  ]
}

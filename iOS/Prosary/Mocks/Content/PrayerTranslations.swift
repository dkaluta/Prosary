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
    if let languageCode, let override = PrayerPackStore.prayerOverride(languageCode: languageCode, key: key) {
      return override
    }

    if let languageCode, let table = byLanguage[languageCode], let text = table[key] {
      return text
    }

    // Community variants ("he-x-gamliel") overlay their base language: anything the variant
    // doesn't override reads from plain "he" before falling to Latin.
    if let languageCode, let base = LanguageCatalog.baseLanguage(of: languageCode) {
      if let override = PrayerPackStore.prayerOverride(languageCode: base, key: key) {
        return override
      }
      if let table = byLanguage[base], let text = table[key] {
        return text
      }
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
    "ru": russian,
    "tl": tagalog,
  ]
}

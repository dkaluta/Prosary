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
  static func get(languageCode: String?, key: PrayerKey) -> String {
    if let languageCode, let table = byLanguage[languageCode], let text = table[key] {
      return text
    }

    return latin[key] ?? key.rawValue
  }

  static let byLanguage: [String: [PrayerKey: String]] = [
    "la": latin,
    "en": english,
    "ar": arabic,
    "he": hebrew,
    "ru": russian,
    "tl": tagalog,
  ]
}

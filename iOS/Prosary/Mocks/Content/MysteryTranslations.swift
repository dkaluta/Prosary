//
//  MysteryTranslations.swift
//  Prosary
//
//  Looks up the title/fruit/description of a mystery by imageKey and language code, falling
//  back to Latin when a translation is missing — including bundle-provided Latin, since some
//  mystery texts (the Seven Sorrows, the Franciscan Crown's Adoration of the Magi) live only in
//  their bundle's content, not the hardcoded tables. See MysteryTranslations+*.swift for the
//  actual per-language tables.
//

import Foundation

enum MysteryTranslations {
  @MainActor
  static func get(languageCode: String?, imageKey: String) -> MysteryText {
    for code in LanguageCatalog.fallbackChain(for: languageCode) {
      if let override = PrayerPackStore.mysteryOverride(languageCode: code, imageKey: imageKey) { return override }
      if let text = byLanguage[code]?[imageKey] { return text }
    }

    return PrayerPackStore.mysteryOverride(languageCode: "la", imageKey: imageKey)
      ?? latin[imageKey]
      ?? MysteryText(title: imageKey, fruit: "", description: "")
  }

  static let byLanguage: [String: [String: MysteryText]] = [
    "la": latin,
    "en": english,
    "ar": arabic,
    "he": hebrew,
    "ru": russian,
    "tl": tagalog,
  ]
}

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
    let chain = LanguageCatalog.contentFallbackChain(for: languageCode)

    func resolvedField(_ overrideValue: (MysteryTextOverride) -> String?,
                       _ builtInValue: (MysteryText) -> String,
                       _ overrideAid: (MysteryTextOverride) -> String?,
                       _ builtInAid: (MysteryText) -> String?) -> (text: String, alternate: String?)? {
      for code in chain {
        if let override = PrayerPackStore.mysteryOverride(
          languageCode: code, imageKey: imageKey),
           let value = overrideValue(override) {
          return (value, overrideAid(override))
        }
        if let text = byLanguage[code]?[imageKey] { return (builtInValue(text), builtInAid(text)) }
      }
      return nil
    }

    // Description and its transliteration resolve as one sourced pair. A transliteration from
    // another language/override must never be attached to a description it did not accompany.
    var resolvedDescription: (text: String, transliteration: String?)?
    for code in chain {
      if let override = PrayerPackStore.mysteryOverride(
        languageCode: code, imageKey: imageKey),
         let description = override.description {
        resolvedDescription = (description, override.transliteratedDescription)
        break
      }
      if let text = byLanguage[code]?[imageKey] {
        resolvedDescription = (text.description, text.transliteratedDescription)
        break
      }
    }

    let title = resolvedField(\.title, \.title, \.transliteratedTitle, \.transliteratedTitle)
    let fruit = resolvedField(\.fruit, \.fruit, \.transliteratedFruit, \.transliteratedFruit)
    return MysteryText(
      title: title?.text ?? imageKey,
      fruit: fruit?.text ?? "",
      description: resolvedDescription?.text ?? "",
      transliteratedDescription: resolvedDescription?.transliteration,
      transliteratedTitle: title?.alternate,
      transliteratedFruit: fruit?.alternate)
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

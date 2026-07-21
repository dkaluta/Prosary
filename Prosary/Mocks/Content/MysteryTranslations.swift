//
//  MysteryTranslations.swift
//  Prosary
//
//  Looks up the title/fruit/description of a mystery by imageKey and language code, falling
//  back to Latin when a translation is missing. See MysteryTranslations+*.swift for the actual
//  per-language tables.
//

import Foundation

enum MysteryTranslations {
    static func get(languageCode: String?, imageKey: String) -> MysteryText {
        if let languageCode, let table = byLanguage[languageCode], let text = table[imageKey] {
            return text
        }

        return latin[imageKey] ?? MysteryText(title: imageKey, fruit: "", description: "")
    }

    static let byLanguage: [String: [String: MysteryText]] = [
        "la": latin,
        "en": english,
        "ar": arabic,
        "he": hebrew,
    ]
}

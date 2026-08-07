//
//  LanguageOption.swift
//  Prosary
//

import Foundation

/// A prayer language the app can display, independent of the device's own UI/system language.
struct LanguageOption: Identifiable, Hashable, Codable {
  /// ISO 639-1 code used as the key into the content layer's prayer/mystery translations.
  var code: String
  /// The language's own name, in its own script (shown in pickers).
  var nativeName: String
  /// Whether prayer text in this language should be displayed right-to-left.
  var isRightToLeft: Bool

  var id: String { code }
}

/// Languages available for prayer text. Latin is the default — it's the neutral fallback every
/// lookup falls back to if a translation is missing in the chosen language.
enum LanguageCatalog {
  /// "he-x-gamliel" → "he": regional/community variants overlay their base language — the
  /// resolve chains try the exact code first, then this.
  static func baseLanguage(of code: String) -> String? {
    guard let dash = code.firstIndex(of: "-") else { return nil }
    return String(code[..<dash])
  }

  static let defaultCode = "la"
  /// Sentinel stored in a preset's `languageCode` meaning "follow the app-level default setting".
  static let defaultSentinel = ""

  static let all: [LanguageOption] = [
    LanguageOption(code: "la", nativeName: "Latina", isRightToLeft: false),
    LanguageOption(code: "en", nativeName: "English", isRightToLeft: false),
    LanguageOption(code: "ar", nativeName: "العربية", isRightToLeft: true),
    LanguageOption(code: "he", nativeName: "עברית", isRightToLeft: true),
    // Aramaic in Hebrew script — the Aramaic-rite Hebrew Catholic communities' liturgical
    // language (requested by the Mission of St. Gamaliel for v0.7).
    LanguageOption(code: "arc", nativeName: "ארמית", isRightToLeft: true),
    // Greek: the language a great deal of the app's own Scripture and prayer was first
    // written in — the Creed, the Sub Tuum, the Jesus Prayer.
    LanguageOption(code: "el", nativeName: "Ἑλληνικά", isRightToLeft: false),
    LanguageOption(code: "ru", nativeName: "Русский", isRightToLeft: false),
    LanguageOption(code: "tl", nativeName: "Tagalog", isRightToLeft: false),
  ]

  /// Rites (community uses) of one language: the same tongue, a different wording. Listed
  /// under the language rather than beside it, because choosing "Hebrew" and choosing *whose*
  /// Hebrew are two different questions — and because a rite that lacks a prayer falls back to
  /// the language's own, so they are never truly separate languages.
  ///
  /// The first entry of each list is the language's own (base) use; the rest overlay it.
  static let rites: [String: [LanguageOption]] = [
    "he": [
      LanguageOption(code: "he", nativeName: "נוסח הנציגות", isRightToLeft: true),
      // The Mission of St. Gamaliel's wording, sent by Erez 2026-08-05.
      LanguageOption(code: "he-x-gamliel", nativeName: "נוסח השליחות", isRightToLeft: true),
    ],
  ]

  /// The rites offered for a code's language — empty when there is only one way to pray it.
  static func rites(of code: String) -> [LanguageOption] {
    rites[baseLanguage(of: code) ?? code] ?? []
  }

  static func resolve(_ code: String?) -> LanguageOption {
    if code == nil || code == defaultSentinel {
      let stored = UserDefaults.standard.string(forKey: "defaultLanguageCode") ?? defaultCode
      return option(for: stored)
    }
    return option(for: code)
  }

  /// Resolves a stored code, which may name a rite ("he-x-gamliel") rather than a plain
  /// language — the rite keeps its own code so every lookup can overlay it on the base.
  private static func option(for code: String?) -> LanguageOption {
    if let code, let rite = rites(of: code).first(where: { $0.code == code }) {
      // A rite carries its language's name in pickers; its own name belongs to the rite row.
      let base = baseLanguage(of: code) ?? code
      if let language = all.first(where: { $0.code == base }) {
        return LanguageOption(code: code, nativeName: language.nativeName, isRightToLeft: rite.isRightToLeft)
      }
    }
    return all.first { $0.code == code } ?? all.first { $0.code == defaultCode }!
  }
}

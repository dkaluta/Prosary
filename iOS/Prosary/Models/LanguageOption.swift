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
    // The Mission of St. Gamaliel's own wording, sent by Erez 2026-08-05: an overlay on "he",
    // so the prayers they have not sent still read in the app's Hebrew.
    LanguageOption(code: "he-x-gamliel", nativeName: "עברית — נוסח השליחות", isRightToLeft: true),
    LanguageOption(code: "ru", nativeName: "Русский", isRightToLeft: false),
    LanguageOption(code: "tl", nativeName: "Tagalog", isRightToLeft: false),
  ]

  static func resolve(_ code: String?) -> LanguageOption {
    if code == nil || code == defaultSentinel {
      let stored = UserDefaults.standard.string(forKey: "defaultLanguageCode") ?? defaultCode
      return all.first { $0.code == stored } ?? all.first { $0.code == defaultCode }!
    }
    return all.first { $0.code == code } ?? all.first { $0.code == defaultCode }!
  }
}

//
//  LanguageOption.swift
//  Prosary
//

import Foundation

/// One app-wide preference selects which sourced Aramaic Sign of the Cross Prosary uses. The
/// value is surfaced in Settings when Aramaic is the default and in an explicitly-Aramaic Rosary
/// editor when the app default is another language.
enum AramaicSignOfCrossForm {
  static let defaultsKey = "aramaicSignOfCrossForm"
  static let formA = "formA"
  static let formB = "formB"

  static var current: String {
    UserDefaults.standard.string(forKey: defaultsKey) == formB ? formB : formA
  }

  /// The app-wide form governs Aramaic only while Aramaic is itself the app default. An
  /// explicitly-Aramaic Rosary under another default uses its own saved form instead.
  static var isSystemWideActive: Bool {
    let code = UserDefaults.standard.string(forKey: "defaultLanguageCode") ?? LanguageCatalog.defaultCode
    return (LanguageCatalog.baseLanguage(of: code) ?? code) == "arc"
  }
}

/// A prayer language the app can display, independent of the device's own UI/system language.
struct LanguageOption: Identifiable, Hashable, Codable {
  /// Prayer-language identifier used as the key into the content layer's translations.
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
  static let fallbackOrderKey = "languageFallbackOrder"
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
    LanguageOption(code: "he", nativeName: "עברית — נוסח הנציגות", isRightToLeft: true),
    LanguageOption(code: "he-x-gamliel", nativeName: "עברית — נוסח השליחות", isRightToLeft: true),
    // Aramaic in Hebrew script — the Aramaic-rite Hebrew Catholic communities' liturgical
    // language (requested by the Mission of St. Gamaliel for v0.7).
    LanguageOption(code: "arc", nativeName: "ארמית", isRightToLeft: true),
    // Greek: the language a great deal of the app's own Scripture and prayer was first
    // written in — the Creed, the Sub Tuum, the Jesus Prayer.
    LanguageOption(code: "el", nativeName: "Ἑλληνικά", isRightToLeft: false),
    LanguageOption(code: "es", nativeName: "Español", isRightToLeft: false),
    LanguageOption(code: "ru", nativeName: "Русский", isRightToLeft: false),
    LanguageOption(code: "tl", nativeName: "Tagalog", isRightToLeft: false),
  ]

  /// Picker choices for a bundle's declared languages. The Mission is a sparse overlay rather
  /// than a manifest language of its own, so every bundle offering Hebrew must expose both
  /// sourced Hebrew uses as adjacent, independent choices.
  static func availableOptions(for declaredCodes: [String]) -> [LanguageOption] {
    let available = Set(declaredCodes.flatMap { code in
      code == "he" ? ["he", "he-x-gamliel"] : [code]
    })
    return all.filter { available.contains($0.code) }
  }

  static var fallbackOrder: [String] {
    let known = Set(all.map(\.code))
    let stored = UserDefaults.standard.stringArray(forKey: fallbackOrderKey) ?? []
    let sanitized = stored.filter { known.contains($0) }
    let defaults = all.map(\.code).filter { $0 != defaultCode } + [defaultCode]
    return (sanitized + defaults.filter { !sanitized.contains($0) }).unique()
  }

  static func setFallbackOrder(_ codes: [String]) {
    UserDefaults.standard.set(codes, forKey: fallbackOrderKey)
  }

  static func fallbackChain(for requested: String?) -> [String] {
    var result: [String] = []
    func append(_ code: String?) {
      guard let code, !result.contains(code) else { return }
      result.append(code)
      if let base = baseLanguage(of: code), !result.contains(base) { result.append(base) }
    }
    let effectiveRequested = requested.flatMap { $0.isEmpty ? nil : $0 }
      ?? UserDefaults.standard.string(forKey: "defaultLanguageCode")
      ?? defaultCode
    append(effectiveRequested)
    fallbackOrder.forEach { append($0) }
    append(defaultCode)
    return result
  }

  /// Legacy grouping metadata for the two Hebrew community uses. Pickers expose them beside one
  /// another as independent prayer languages; the relationship remains useful when resolving
  /// older stored codes and documenting the base-language fallback.
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
    if let exact = all.first(where: { $0.code == code }) { return exact }
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

private extension Array where Element: Hashable {
  func unique() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}

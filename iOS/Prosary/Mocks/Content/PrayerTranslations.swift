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
  /// Aramaic's two writing systems share one prayer language and one saved preference.
  static let aramaicDefaultScriptKey = "aramaicDefaultScript"

  @MainActor
  static func initialTransliteration(languageCode: String?, body: String, alternate: String?,
                                     script: String? = nil) -> Bool? {
    guard LanguageCatalog.fallbackChain(for: languageCode).first == "arc" else { return nil }
    let desired: PrayerTypography.Script = (script ?? UserDefaults.standard.string(forKey: aramaicDefaultScriptKey)) == "Syrc"
      ? .syriac : .hebrew
    guard PrayerTypography.script(of: body) != desired, let alternate else { return false }
    return PrayerTypography.script(of: alternate) == desired
  }

  @MainActor
  static func aramaicProgress(_ index: Int, total: Int, languageCode: String?, sourceScript: Bool) -> String? {
    guard LanguageCatalog.fallbackChain(for: languageCode).first == "arc" else { return nil }
    let connector = sourceScript
      ? PrayerPackStore.transliteration(bundleId: "rosary", languageCode: "arc", key: PrayerKey.repetitionCounterConnector.rawValue)
      : nil
    return "\(index) \(connector ?? get(languageCode: "arc", key: .repetitionCounterConnector)) \(total)"
  }

  @MainActor
  static func flowTitle(_ title: String, languageCode: String?, sourceScript: Bool) -> String {
    let title = HebrewDisplayText.unpointed(title)
    guard sourceScript, LanguageCatalog.fallbackChain(for: languageCode).first == "arc",
          let connector = PrayerPackStore.transliteration(bundleId: "rosary", languageCode: "arc", key: PrayerKey.repetitionCounterConnector.rawValue)
    else { return title }
    let original = HebrewDisplayText.unpointed(get(languageCode: "arc", key: .repetitionCounterConnector))
    let pattern = #"(\(\d+) "# + NSRegularExpression.escapedPattern(for: original) + #" (\d+\))$"#
    return title.replacingOccurrences(of: pattern, with: "$1 \(connector) $2", options: .regularExpression)
  }

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

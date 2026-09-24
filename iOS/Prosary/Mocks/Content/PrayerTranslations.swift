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
  static func flowTitle(_ title: String, languageCode: String?, sourceScript: Bool,
                        bundleId: String = "rosary") -> String {
    let title = HebrewDisplayText.unpointed(title)
    guard LanguageCatalog.fallbackChain(for: languageCode).first == "arc" else { return title }
    let pairs = PrayerPackStore.aramaicHeadingPairs(bundleId: bundleId)
    let definition = PrayerPackStore.definition(for: bundleId)
    let ordinalKeys = ([definition?.decades?.ordinalNounKey]
      + (definition?.variants ?? []).map { $0.decades?.ordinalNounKey }).compactMap { $0 }
    let ordinalNouns = Set(ordinalKeys.flatMap { key in
      [PrayerPackStore.resolveBodyText(bundleId: bundleId, languageCode: "arc", key: key),
       PrayerPackStore.transliteration(bundleId: bundleId, languageCode: "arc", key: key)]
        .compactMap { $0 }.map(HebrewDisplayText.unpointed)
    })
    // Decade context is composed from independently authored labels and a mystery title.
    // Only recognize that authored shape; personal titles containing a dash stay untouched.
    if title.contains(" — ") {
      let parts = title.components(separatedBy: " — ")
      func isPaired(_ value: String) -> Bool {
        pairs.contains { HebrewDisplayText.unpointed($0.original) == value || HebrewDisplayText.unpointed($0.alternate) == value }
      }
      func isOrdinal(_ value: String) -> Bool {
        guard let suffix = value.range(of: #" \d+$"#, options: .regularExpression) else { return false }
        return ordinalNouns.contains(String(value[..<suffix.lowerBound]))
      }
      guard (2...3).contains(parts.count) else { return title }
      let ordinalIndex = isOrdinal(parts[parts.count - 1]) ? parts.count - 1 : parts.count - 2
      guard isOrdinal(parts[ordinalIndex]), ordinalIndex == parts.count - 1 || isPaired(parts[parts.count - 1]) else { return title }
      return parts.map { part in
        flowTitle(part, languageCode: languageCode, sourceScript: sourceScript, bundleId: bundleId)
      }.joined(separator: " — ")
    }
    let hebrewConnector = HebrewDisplayText.unpointed(get(languageCode: "arc", key: .repetitionCounterConnector))
    let syriacConnector = PrayerPackStore.transliteration(
      bundleId: "rosary", languageCode: "arc", key: PrayerKey.repetitionCounterConnector.rawValue)
    let connectors = [hebrewConnector, syriacConnector].compactMap { $0 }
    let pattern = #" \(\d+ (?:"# + connectors.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|") + #") \d+\)$"#
    let ordinalSuffix = title.range(of: #" \d+$"#, options: .regularExpression).flatMap {
      ordinalNouns.contains(String(title[..<$0.lowerBound])) ? $0 : nil
    }
    let suffixRange = title.range(of: pattern, options: .regularExpression) ?? ordinalSuffix
    let heading = suffixRange.map { String(title[..<$0.lowerBound]) } ?? title
    var suffix = suffixRange.map { String(title[$0]) } ?? ""
    let desired: PrayerTypography.Script = sourceScript ? .syriac : .hebrew
    var displayed = heading
    for pair in pairs {
      let original = HebrewDisplayText.unpointed(pair.original)
      let alternate = HebrewDisplayText.unpointed(pair.alternate)
      guard heading == original || heading == alternate else { continue }
      if PrayerTypography.script(of: original) == desired { displayed = original }
      else if PrayerTypography.script(of: alternate) == desired { displayed = alternate }
      break
    }
    if let desiredConnector = sourceScript ? syriacConnector : hebrewConnector {
      for connector in connectors {
        suffix = suffix.replacingOccurrences(of: " \(connector) ", with: " \(desiredConnector) ")
      }
    }
    return displayed + suffix
  }

  @MainActor
  static func get(languageCode: String?, key: PrayerKey) -> String {
    PrayerPackStore.resolveSharedPrayer(languageCode: languageCode, key: key)
      ?? latin[key] ?? key.rawValue
  }

  /// Editorial vocabulary is shared Hebrew. Every other native Hebrew entry is the
  /// Vicariate's sourced prayer wording or its liturgical incipit/response.
  static let genericHebrewKeys: Set<PrayerKey> = [
    .decadeOrdinalFormat, .repetitionCounterConnector, .fructusMysteriiLabel,
  ]

  static func nativeText(contentCode: String, key: PrayerKey) -> String? {
    if contentCode == LanguageCatalog.vicariateContentCode {
      return genericHebrewKeys.contains(key) ? nil : hebrew[key]
    }
    if contentCode == "he" {
      return genericHebrewKeys.contains(key) ? hebrew[key] : nil
    }
    return byLanguage[contentCode]?[key]
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

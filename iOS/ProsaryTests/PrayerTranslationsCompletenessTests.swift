//
//  PrayerTranslationsCompletenessTests.swift
//  ProsaryTests
//
//  Guards against a missed cell in the per-language content tables — PrayerTranslations.get
//  silently falls back to Latin (then the raw key) when a translation is missing, so a gap here
//  wouldn't otherwise surface until someone actually reads that language in the app.
//

import XCTest
@testable import Prosary

final class PrayerTranslationsCompletenessTests: XCTestCase {
  private let supportedLanguages = ["la", "en", "ar", "he", "ru", "tl"]

  private let angelusAndJesusPrayerKeys: [PrayerKey] = [
    .versiculumAngelusPrimus, .responsiumAngelusPrimus,
    .versiculumAngelusSecundus, .responsiumAngelusSecundus,
    .versiculumAngelusTertius, .responsiumAngelusTertius,
    .collectaAngelus, .oratioIesu,
  ]

  func testEveryNewKeyIsPresentInEverySupportedLanguage() {
    for key in angelusAndJesusPrayerKeys {
      for language in supportedLanguages {
        let text = PrayerTranslations.byLanguage[language]?[key]
        XCTAssertNotNil(text, "\(key) missing a \(language) translation")
        XCTAssertFalse(text?.isEmpty ?? true, "\(key) has an empty \(language) translation")
      }
    }
  }
}

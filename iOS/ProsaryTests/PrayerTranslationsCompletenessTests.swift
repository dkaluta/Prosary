//
//  PrayerTranslationsCompletenessTests.swift
//  ProsaryTests
//
//  Guards against a missed cell in the per-language content tables — PrayerTranslations.get/
//  MysteryTranslations.get silently fall back to Latin (then the raw key) when a translation is
//  missing, so a gap here wouldn't otherwise surface until someone actually reads that language
//  in the app.
//

import XCTest
@testable import Prosary

final class PrayerTranslationsCompletenessTests: XCTestCase {
  private let fullyTranslatedLanguages = ["ar", "he", "ru", "tl"]

  /// `PrayerKey`s added during the 4-devotion rollout (Stations of the Cross, Seven Sorrows,
  /// Divine Mercy Chaplet) that are still missing one or more of the 4 non-Latin/English
  /// languages, mapped to exactly which of those 4 they're still missing — silently falls back
  /// to Latin for those via the normal fallback chain, not a bug. Kept explicit here so a *new*,
  /// unintentional gap still fails `testEveryPrayerKeyExceptTheKnownAllowlistHasAllSixLanguages`,
  /// and so this list itself goes stale (rather than silently wrong) once a language is filled
  /// in — see `testAllowlistedPrayerKeysAreStillMissingFromTheExpectedLanguages`.
  private let prayerKeysMissingLanguages: [PrayerKey: Set<String>] = [
    .stationsOpeningPrayer: ["ar", "he", "ru", "tl"],
    .stationsVersicle: ["ar", "he", "ru", "tl"],
    .stationsResponse: ["ar", "he", "ru", "tl"],
    .stationsClosingPrayer: ["ar", "he", "ru", "tl"],
    .sevenSorrowsVersicle: ["ar", "he", "ru", "tl"],
    .sevenSorrowsResponse: ["ar", "he", "ru", "tl"],
    .sevenSorrowsCollect: ["ar", "he", "ru", "tl"],
    .divineMercyOffering: ["ar", "he", "ru", "tl"],
    .divineMercyPetition: ["ar", "he", "ru", "tl"],
    // Hebrew added by the user directly — see PrayerTranslations+Hebrew.swift.
    .divineMercyClosingAcclamation: ["ar", "ru", "tl"],
  ]

  /// Same idea as `prayerKeysMissingLanguages`, for `MysteryTranslations` — the Seven Sorrows'
  /// 7 imageKeys and the Franciscan Crown's one new mystery (Adoration of the Magi; the other 6
  /// Joys reuse existing, fully-translated Rosary mystery content).
  private let latinAndEnglishOnlyMysteryImageKeys: Set<String> =
    Set(SevenSorrowsCatalog.sevenSorrows).union(["franciscan_04_adoration_of_the_magi"])

  /// `.doxologiaMinor` is explicitly documented ("kept for future use") as reserved but not
  /// wired into any devotion's engine code yet — it has no Latin/English content at all (only a
  /// Hebrew entry, added manually), so it can't satisfy even the baseline
  /// `testEveryPrayerKeyHasLatinAndEnglishTranslations` check. Excluded here rather than
  /// fabricating placeholder Latin/English text for a key nothing reads yet.
  private let notYetUsedByAnyDevotion: Set<PrayerKey> = [.doxologiaMinor]

  private var allMysteryImageKeys: Set<String> {
    Set(MysteryGroup.allCases.flatMap { MysteryCatalog.forGroup($0) }.map(\.imageKey))
      .union(SevenSorrowsCatalog.sevenSorrows)
      .union(FranciscanCrownCatalog.sevenJoys)
  }

  func testEveryPrayerKeyHasLatinAndEnglishTranslations() {
    for key in PrayerKey.allCases where !notYetUsedByAnyDevotion.contains(key) {
      for language in ["la", "en"] {
        let text = PrayerTranslations.byLanguage[language]?[key]
        XCTAssertNotNil(text, "\(key) missing a \(language) translation")
        XCTAssertFalse(text?.isEmpty ?? true, "\(key) has an empty \(language) translation")
      }
    }
  }

  func testEveryPrayerKeyExceptTheKnownAllowlistHasAllSixLanguages() {
    for key in PrayerKey.allCases where !notYetUsedByAnyDevotion.contains(key) {
      let missing = prayerKeysMissingLanguages[key] ?? []
      for language in fullyTranslatedLanguages where !missing.contains(language) {
        let text = PrayerTranslations.byLanguage[language]?[key]
        XCTAssertNotNil(
          text,
          "\(key) missing a \(language) translation — if intentional, add it to prayerKeysMissingLanguages")
      }
    }
  }

  /// Guards the allowlist itself from going stale: if a key gets translated into a language
  /// still listed as missing for it, this should start failing as a reminder to narrow that
  /// key's entry in `prayerKeysMissingLanguages` (or remove it entirely) rather than leaving a
  /// passing-but-inaccurate entry.
  func testAllowlistedPrayerKeysAreStillMissingFromTheExpectedLanguages() {
    for (key, missing) in prayerKeysMissingLanguages {
      for language in missing {
        XCTAssertNil(
          PrayerTranslations.byLanguage[language]?[key],
          "\(key) now has a \(language) translation — narrow or remove its entry in prayerKeysMissingLanguages")
      }
    }
  }

  func testEveryMysteryImageKeyHasLatinAndEnglishTranslations() {
    for imageKey in allMysteryImageKeys {
      for language in ["la", "en"] {
        let text = MysteryTranslations.byLanguage[language]?[imageKey]
        XCTAssertNotNil(text, "\(imageKey) missing a \(language) translation")
      }
    }
  }

  func testEveryMysteryImageKeyExceptTheKnownAllowlistHasAllSixLanguages() {
    for imageKey in allMysteryImageKeys where !latinAndEnglishOnlyMysteryImageKeys.contains(imageKey) {
      for language in fullyTranslatedLanguages {
        let text = MysteryTranslations.byLanguage[language]?[imageKey]
        XCTAssertNotNil(
          text,
          "\(imageKey) missing a \(language) translation — if intentional, add it to latinAndEnglishOnlyMysteryImageKeys")
      }
    }
  }

  func testAllowlistedMysteryImageKeysAreStillMissingFromTheExpectedLanguages() {
    for imageKey in latinAndEnglishOnlyMysteryImageKeys {
      for language in fullyTranslatedLanguages {
        XCTAssertNil(
          MysteryTranslations.byLanguage[language]?[imageKey],
          "\(imageKey) now has a \(language) translation — remove it from latinAndEnglishOnlyMysteryImageKeys")
      }
    }
  }
}

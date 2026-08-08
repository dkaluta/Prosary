//
//  PrayerTranslationsCompletenessTests.swift
//  ProsaryTests
//
//  Guards against silent content gaps. Two layers:
//  1. The hardcoded tables (main prayers, Rosary keys, antiphons, Jesus Prayer) — every
//     surviving PrayerKey must have Latin + English, and all six languages except a small
//     explicit allowlist; `PrayerTranslations.get` silently falls back to Latin, so a gap
//     wouldn't otherwise surface until someone prays in that language.
//  2. Every shipped devotion bundle — each key its devotion.json references must resolve to real
//     text (never the raw key) in every language the bundle's manifest declares, with each
//     bundle's known gaps listed explicitly so they go stale loudly instead of silently wrong.
//     Mirrors Shared/tools/validate-devotion.py, but against the actually-shipped packs and the
//     runtime merge (e.g. the Franciscan Crown's shared Joys resolving cross-bundle from the
//     rosary pack).
//

import XCTest
@testable import Prosary

@MainActor
final class PrayerTranslationsCompletenessTests: XCTestCase {
  private let fullyTranslatedLanguages = ["ar", "he", "ru", "tl"]

  /// `.doxologiaMinor` is explicitly documented ("kept for future use") as reserved but not
  /// wired into any devotion's engine code yet — it has no Latin/English content at all (only a
  /// Hebrew entry, added manually), so it can't satisfy even the baseline check. Excluded here
  /// rather than fabricating placeholder Latin/English text for a key nothing reads yet.
  private let notYetUsedByAnyDevotion: Set<PrayerKey> = [.doxologiaMinor]

  /// Known per-bundle translation gaps: bundleId -> language -> keys awaiting a verified
  /// translation. The self-guard test below fails once a listed key gains its translation, so
  /// this map can never go silently stale.
  private let bundleKeysMissingLanguages: [String: [String: Set<String>]] = [
    // Veronica's station quotes Judith, and the Arabic/Tagalog scripture sources carry no
    // deuterocanon — those two fall back to the bundle's Latin text.
    // The Kyrie's Hebrew heading waits for the Vicariate's prayer book; its body arrived
    // 2026-08-08 (the threefold ישוע שמענו line), so only the title still falls to Latin.
    "trisagion": [
      "he": ["trisagionKyrieTitle"],
    ],
    "stationsOfTheCross": [
      "ar": ["station06Body"],
      "tl": ["station06Body"],
    ],
  ]

  private var allMysteryImageKeys: Set<String> {
    Set(MysteryGroup.allCases.flatMap { MysteryCatalog.forGroup($0) }.map(\.imageKey))
  }

  // MARK: - Hardcoded tables

  func testEveryPrayerKeyHasLatinAndEnglishTranslations() {
    for key in PrayerKey.allCases where !notYetUsedByAnyDevotion.contains(key) {
      for language in ["la", "en"] {
        let text = PrayerTranslations.byLanguage[language]?[key]
        XCTAssertNotNil(text, "\(key) missing a \(language) translation")
        XCTAssertFalse(text?.isEmpty ?? true, "\(key) has an empty \(language) translation")
      }
    }
  }

  func testEveryPrayerKeyHasAllSixLanguages() {
    for key in PrayerKey.allCases where !notYetUsedByAnyDevotion.contains(key) {
      for language in fullyTranslatedLanguages {
        XCTAssertNotNil(
          PrayerTranslations.byLanguage[language]?[key],
          "\(key) missing a \(language) translation")
      }
    }
  }

  /// The cross mark shows where the sign of the cross is made. It has to be in every language's
  /// Sign of the Cross — a reader who prays in Tagalog needs it as much as one who prays in
  /// Hebrew — and it belongs immediately after the word for "Father", where the gesture begins,
  /// which is where the Mission of St. Gamaliel's own texts put it. Dropping it is the kind of
  /// thing that happens silently when someone re-types a prayer.
  func testEverySignOfTheCrossCarriesTheCrossMark() {
    for (language, table) in PrayerTranslations.byLanguage {
      guard let text = table[.signumCrucis] else { continue }
      XCTAssertTrue(text.contains("✠"), "\(language)'s Sign of the Cross has no ✠")
      // Never at the very start or the very end: it marks a point inside the formula.
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      XCTAssertFalse(trimmed.hasPrefix("✠"), "\(language): the ✠ should sit inside the formula")
      XCTAssertFalse(trimmed.hasSuffix("✠"), "\(language): the ✠ should sit inside the formula")
    }
  }

  /// ...and nowhere else outside the Mission's own rite. Signing at the Glory Be is their use,
  /// not the Latin rite's, and quietly spreading it would be inventing practice.
  func testTheCrossMarkStaysOutOfOtherRitesPrayers() {
    for (language, table) in PrayerTranslations.byLanguage where language != "he-x-gamliel" {
      for (key, text) in table where key != .signumCrucis {
        XCTAssertFalse(text.contains("✠"), "\(language)'s \(key) should not carry a ✠")
      }
    }
  }

  func testEveryRosaryMysteryImageKeyHasAllSixLanguages() {
    for imageKey in allMysteryImageKeys {
      for language in ["la", "en"] + fullyTranslatedLanguages {
        XCTAssertNotNil(
          MysteryTranslations.byLanguage[language]?[imageKey],
          "\(imageKey) missing a \(language) translation")
      }
    }
  }

  // MARK: - Shipped bundles

  /// Collects every bodyKey/titleKey a definition references, and the mystery imageKeys whose
  /// text an announced decade needs.
  private func referencedKeys(of definition: CustomDevotionDefinition) -> (text: Set<String>, mysteries: Set<String>) {
    var text = Set<String>()
    var mysteries = Set<String>()
    var allEntries = (definition.steps ?? []) + (definition.eastertideSteps ?? [])
      + (definition.opening ?? []) + (definition.closing ?? [])

    // Every decade block in the bundle: the single-form one, and one per rosary-type variant.
    // Missing a variant's block here would quietly stop checking the keys only that form uses,
    // which is the whole thing this test exists to catch.
    var allDecades = [definition.decades].compactMap { $0 }
    for variant in definition.variants ?? [] {
      allEntries += (variant.steps ?? []) + (variant.eastertideSteps ?? [])
        + (variant.opening ?? []) + (variant.closing ?? [])
      if let decades = variant.decades { allDecades.append(decades) }
    }
    for decades in allDecades {
      allEntries += (decades.preAnnouncement ?? []) + (decades.postMinor ?? [])
    }

    for entry in allEntries where entry.kind == nil {
      entry.bodyKey.map { text.insert($0) }
      entry.titleKey.map { text.insert($0) }
      entry.acclamationKey.map { text.insert($0) }
      entry.subtitleKey.map { text.insert($0) }
    }
    for decades in allDecades {
      text.insert(decades.majorStep.bodyKey)
      text.insert(decades.minorStep.bodyKey)
      decades.majorStep.titleKey.map { text.insert($0) }
      decades.minorStep.titleKey.map { text.insert($0) }
      decades.ordinalNounKey.map { text.insert($0) }
      if decades.announceMystery {
        for entry in decades.entries ?? [] { mysteries.insert(entry.imageKey) }
      }
    }
    return (text, mysteries)
  }

  func testEveryBundleKeyResolvesInEveryDeclaredLanguage() {
    for bundleId in PrayerPackStore.customDevotionIds() {
      guard let definition = PrayerPackStore.definition(for: bundleId),
            let info = PrayerPackStore.info(for: bundleId) else {
        XCTFail("\(bundleId): missing definition or info")
        continue
      }
      let refs = referencedKeys(of: definition)
      for language in info.languages {
        let allowedMissing = bundleKeysMissingLanguages[bundleId]?[language] ?? []
        for key in refs.text where !allowedMissing.contains(key) {
          let resolved = PrayerPackStore.resolveBodyText(bundleId: bundleId, languageCode: language, key: key)
          XCTAssertNotEqual(
            resolved, key,
            "\(bundleId)/\(language): \(key) resolves to its raw key — missing translation")
        }
        for imageKey in refs.mysteries {
          let mystery = MysteryTranslations.get(languageCode: language, imageKey: imageKey)
          XCTAssertNotEqual(
            mystery.title, imageKey,
            "\(bundleId)/\(language): no mystery text for \(imageKey)")
        }
      }
    }
  }

  /// Guards the gap allowlist itself from going stale: once a listed key gains a translation,
  /// this fails as a reminder to narrow the allowlist rather than leaving it inaccurate.
  func testAllowlistedBundleKeysAreStillMissingFromTheExpectedLanguages() {
    for (bundleId, languages) in bundleKeysMissingLanguages {
      for (language, keys) in languages {
        for key in keys {
          let resolved = PrayerPackStore.resolveBodyText(bundleId: bundleId, languageCode: language, key: key)
          // A missing bundle-local translation falls back to the bundle's Latin text (or the
          // hardcoded chain) — "still missing" means it doesn't resolve to language-specific
          // bundle content, i.e. it equals the Latin resolution.
          let latin = PrayerPackStore.resolveBodyText(bundleId: bundleId, languageCode: "la", key: key)
          XCTAssertEqual(
            resolved, latin,
            "\(bundleId)/\(language): \(key) now has its own translation — narrow bundleKeysMissingLanguages")
        }
      }
    }
  }
}

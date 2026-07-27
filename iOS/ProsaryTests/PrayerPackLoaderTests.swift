//
//  PrayerPackLoaderTests.swift
//  ProsaryTests
//
//  Proves the whole .prosaryprayer pipeline end-to-end: the actual bundled rosary.prosaryprayer/
//  angelus.prosaryprayer resources (produced by Shared/tools/make-prosaryprayer.sh from
//  Shared/content/) parse correctly and their content overrides PrayerTranslations/
//  MysteryTranslations as designed.
//

import XCTest
@testable import Prosary

@MainActor
final class PrayerPackLoaderTests: XCTestCase {
  func testBundledPacksExist() {
    XCTAssertNotNil(Bundle.main.url(forResource: "rosary", withExtension: "prosaryprayer"))
    XCTAssertNotNil(Bundle.main.url(forResource: "angelus", withExtension: "prosaryprayer"))
  }

  func testRosaryPackProvidedKeyOverridesEnglishText() {
    let text = PrayerTranslations.get(languageCode: "en", key: .oratioFatimae)
    XCTAssertEqual(text, "O my Jesus, forgive us our sins, save us from the fires of hell, lead all souls to Heaven, especially those who are in most need of Thy mercy.")
  }

  func testRosaryPackProvidedMysteryOverridesLatinTitle() {
    let text = MysteryTranslations.get(languageCode: "la", imageKey: "joyful_01_annunciation")
    XCTAssertEqual(text.title, "Nuntiatio")
    XCTAssertEqual(text.fruit, "Humilitas")
  }

  func testAngelusPackProvidedKeyOverridesHebrewText() {
    let text = PrayerTranslations.get(languageCode: "he", key: .collectaAngelus)
    XCTAssertFalse(text.isEmpty)
    XCTAssertTrue(text.hasPrefix("נִתְפַּלְּלָה"))
  }

  /// The "main" prayers (Sign of the Cross, Creed, Our Father, Hail Mary, Glory Be) are
  /// deliberately absent from every bundle (see Shared/ARCHITECTURE.md) and must keep resolving
  /// from the hardcoded table even with both packs loaded.
  func testMainPrayerKeyStillResolvesFromHardcodedTableNotFromAPack() {
    let text = PrayerTranslations.get(languageCode: "en", key: .aveMaria)
    XCTAssertEqual(text, PrayerTranslations.english[.aveMaria])
  }

  /// A devotion with no shipped pack at all (Stations) must be completely unaffected.
  func testUnmigratedDevotionKeyStillResolvesFromHardcodedTable() {
    let text = PrayerTranslations.get(languageCode: "en", key: .stationsOpeningPrayer)
    XCTAssertEqual(text, PrayerTranslations.english[.stationsOpeningPrayer])
  }

  func testRosaryPackProvidesImageDataForAMysteryKey() {
    let data = PrayerPackStore.imageData(for: "joyful_01_annunciation")
    XCTAssertNotNil(data)
    XCTAssertGreaterThan(data?.count ?? 0, 0)
  }

  func testPackProvidesNoImageDataForAnUnrelatedKey() {
    XCTAssertNil(PrayerPackStore.imageData(for: "station_01_condemned_to_death"))
  }
}

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
    XCTAssertNotNil(Bundle.main.url(forResource: "trisagion", withExtension: "prosaryprayer"))
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

  // MARK: - Generic (bundle-driven) devotions

  func testTrisagionIsDiscoveredAsACustomDevotion() {
    XCTAssertTrue(PrayerPackStore.customDevotionIds().contains("trisagion"))
  }

  /// A devotion with no devotion.json at all (Rosary/Angelus while they remain override-only
  /// bundles) is never mistaken for a generic one.
  func testPacksWithNoDevotionDefinitionAreNotCustomDevotions() {
    XCTAssertFalse(PrayerPackStore.customDevotionIds().contains("rosary"))
    XCTAssertFalse(PrayerPackStore.customDevotionIds().contains("angelus"))
  }

  func testTrisagionInfoReadsFromItsManifest() {
    let info = PrayerPackStore.info(for: "trisagion")
    XCTAssertEqual(info?.displayName, "Trisagion")
    XCTAssertEqual(info?.accentColorHex, "#00796B")
    XCTAssertEqual(info?.iconSystemName, "triangle")
  }

  func testTrisagionDefinitionMatchesTheAuthoredSixStepSequence() {
    let definition = PrayerPackStore.definition(for: "trisagion")
    XCTAssertEqual(definition?.type, .steps)
    let steps = definition?.steps ?? []
    XCTAssertEqual(steps.map(\.title), [
      "Holy God", "Holy God", "Holy God", "Glory Be", "Holy God", "Holy God",
    ])
    XCTAssertEqual(steps.map(\.bodyKey), [
      "trisagionAcclamation", "trisagionAcclamation", "trisagionAcclamation",
      "gloriaPatri", "trisagionShortAcclamation", "trisagionAcclamation",
    ])
  }

  /// `resolveBodyText` step 1 — a bundle-local-only key (never a `PrayerKey` case) resolves from
  /// the bundle's own raw content.
  func testResolveBodyTextResolvesABundleLocalKey() {
    let text = PrayerPackStore.resolveBodyText(bundleId: "trisagion", languageCode: "en", key: "trisagionAcclamation")
    XCTAssertEqual(text, "Holy God, Holy Mighty One, Holy Immortal One, have mercy on us.")
  }

  /// `resolveBodyText` step 2 — a key matching an existing `PrayerKey` case (here, "gloriaPatri",
  /// a "main" prayer deliberately absent from every bundle) falls through to the ordinary
  /// hardcoded table.
  func testResolveBodyTextFallsThroughToASharedPrayerKey() {
    let text = PrayerPackStore.resolveBodyText(bundleId: "trisagion", languageCode: "en", key: "gloriaPatri")
    XCTAssertEqual(text, PrayerTranslations.get(languageCode: "en", key: .gloriaPatri))
  }

  /// `resolveBodyText` step 3 — an unresolvable key returns itself, matching
  /// `PrayerTranslations.get`'s own last-resort fallback.
  func testResolveBodyTextFallsBackToTheRawKey() {
    let text = PrayerPackStore.resolveBodyText(bundleId: "trisagion", languageCode: "en", key: "notARealKey")
    XCTAssertEqual(text, "notARealKey")
  }
}

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
    for pack in ["rosary", "angelus", "stationsOfTheCross", "franciscanCrown", "sevenSorrows",
                 "divineMercyChaplet", "trisagion"] {
      XCTAssertNotNil(
        Bundle.main.url(forResource: pack, withExtension: "prosaryprayer"),
        "missing \(pack).prosaryprayer")
    }
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

  func testAngelusPackProvidesHebrewComposedBody() {
    let text = PrayerPackStore.resolveBodyText(
      bundleId: "angelus", languageCode: "he", key: "angelusCollectBody")
    XCTAssertFalse(text.isEmpty)
    XCTAssertTrue(text.contains("נִתְפַּלְּלָה"))
  }

  /// The "main" prayers (Sign of the Cross, Creed, Our Father, Hail Mary, Glory Be) are
  /// deliberately absent from every bundle (see Shared/ARCHITECTURE.md) and must keep resolving
  /// from the hardcoded table even with both packs loaded.
  func testMainPrayerKeyStillResolvesFromHardcodedTableNotFromAPack() {
    let text = PrayerTranslations.get(languageCode: "en", key: .aveMaria)
    XCTAssertEqual(text, PrayerTranslations.english[.aveMaria])
  }

  /// A devotion converted to a bundle resolves entirely bundle-locally — its keys no longer
  /// exist in the hardcoded tables at all.
  func testConvertedDevotionKeyResolvesFromItsBundle() {
    let text = PrayerPackStore.resolveBodyText(
      bundleId: "stationsOfTheCross", languageCode: "en", key: "stationsOpeningPrayer")
    XCTAssertTrue(text.hasPrefix("My Lord Jesus Christ, You made this journey"))
  }

  func testRosaryPackProvidesImageDataForAMysteryKey() {
    let data = PrayerPackStore.imageData(for: "joyful_01_annunciation")
    XCTAssertNotNil(data)
    XCTAssertGreaterThan(data?.count ?? 0, 0)
  }

  func testStationsPackProvidesItsImageData() {
    let data = PrayerPackStore.imageData(for: "station_01_condemned_to_death")
    XCTAssertGreaterThan(data?.count ?? 0, 0)
  }

  func testPackProvidesNoImageDataForAnUnknownKey() {
    XCTAssertNil(PrayerPackStore.imageData(for: "no_such_image_key"))
  }

  // MARK: - Generic (bundle-driven) devotions

  func testTrisagionIsDiscoveredAsACustomDevotion() {
    XCTAssertTrue(PrayerPackStore.customDevotionIds().contains("trisagion"))
  }

  /// The Rosary's pack has no devotion.json (override-only) and must never be mistaken for a
  /// generic devotion; the six generic devotions appear in pack-load order.
  func testCustomDevotionIdsAreTheSixGenericDevotionsInLoadOrder() {
    XCTAssertEqual(PrayerPackStore.customDevotionIds(), [
      "angelus", "stationsOfTheCross", "franciscanCrown", "sevenSorrows",
      "divineMercyChaplet", "trisagion",
    ])
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

import XCTest
@testable import Prosary

@MainActor
final class RosaryClosingTests: XCTestCase {
  private let engine = PrayerEngine(calendar: MockLiturgicalCalendar())

  func testLitanyForcesExactlyOneSeparateCollectInEverySupportedLanguage() throws {
    for language in LanguageCatalog.all.map(\.code) {
      for antiphon in [MarianAntiphonOption.salveRegina, .reginaCaeli, .none] {
        var prayer = Prayer(languageCode: language)
        prayer.rosary.marianAntiphon = antiphon
        prayer.rosary.includeLitanyOfLoreto = true
        prayer.rosary.includeRosaryCollect = false
        prayer.rosary.includeStMichaelPrayer = true
        let steps = engine.buildSteps(for: prayer)
        let collect = PrayerPackStore.resolveBodyText(bundleId: "rosary", languageCode: language, key: "rosaryCollect")
        let title = PrayerPackStore.resolveBodyText(bundleId: "rosary", languageCode: language, key: "rosaryCollectTitle")
        XCTAssertFalse(collect.isEmpty, language)
        XCTAssertNotEqual(collect, "rosaryCollect", language)
        XCTAssertEqual(steps.filter { $0.body == collect }.count, 1, language)
        XCTAssertEqual(steps.dropLast().last?.body, collect, language)
        XCTAssertEqual(steps.dropLast().last?.title, title, language)
        XCTAssertFalse(steps.first(where: \.isAntiphon)?.body.contains(collect) ?? false, language)
        let effective = PrayerPackStore.effectiveLanguage(for: "litanyOfLoreto", chosen: language)
        let litany = engine.buildCustomDevotionSteps(bundleId: "litanyOfLoreto", languageCode: effective, variantId: "afterRosary")
        XCTAssertEqual(Array(steps.suffix(17).prefix(15)).map(\.body), litany.dropLast().map(\.body), language)
        XCTAssertEqual(steps.last?.imageOverrideKey, "crucifix")
      }
    }
  }

  func testCollectIsIndependentOfAntiphonAndOptionalWithoutLitany() {
    for antiphon in [MarianAntiphonOption.salveRegina, .reginaCaeli, .none] {
      var prayer = Prayer(languageCode: "en")
      prayer.rosary.marianAntiphon = antiphon
      prayer.rosary.includeRosaryCollect = false
      let without = engine.buildSteps(for: prayer)
      prayer.rosary.includeRosaryCollect = true
      let with = engine.buildSteps(for: prayer)
      let collect = PrayerPackStore.resolveBodyText(bundleId: "rosary", languageCode: "en", key: "rosaryCollect")
      XCTAssertFalse(without.contains { $0.body.contains(collect) })
      XCTAssertEqual(with.count, without.count + 1)
      XCTAssertEqual(with.dropLast().last?.body, collect)
      for key in [PrayerKey.collectaStandard, .collectaPaschale] {
        let oldEmbedded = PrayerTranslations.get(languageCode: "en", key: key)
        XCTAssertFalse(with.first(where: \.isAntiphon)?.body.contains(oldEmbedded) ?? false)
      }
    }
  }

  func testSavedAndGenericOptionsForceCollectWithoutDiscardingTheUsersIndependentChoice() throws {
    var prayer = Prayer(languageCode: "he")
    prayer.rosary.includeLitanyOfLoreto = true
    prayer.rosary.includeRosaryCollect = false
    let entry = PresetEntry(prayer: prayer)
    XCTAssertEqual(entry.toPrayer().rosary, prayer.rosary)
    XCTAssertTrue(entry.toPrayer().rosary.effectiveRosaryCollect)
    let restored = try JSONDecoder().decode(RosaryOptions.self, from: JSONEncoder().encode(prayer.rosary))
    XCTAssertEqual(restored, prayer.rosary)
    let old = try JSONDecoder().decode(RosaryOptions.self, from: Data("{}".utf8))
    XCTAssertFalse(old.includeLitanyOfLoreto)
    XCTAssertTrue(old.includeRosaryCollect)
    let signature = PrayerRunSignature.rosary(prayer.rosary)
    prayer.rosary.includeLitanyOfLoreto = false
    XCTAssertNotEqual(signature, PrayerRunSignature.rosary(prayer.rosary))
    XCTAssertFalse(prayer.rosary.effectiveRosaryCollect)
    entry.update(from: prayer)
    XCTAssertFalse(entry.toPrayer().rosary.includeLitanyOfLoreto)
    XCTAssertFalse(entry.toPrayer().rosary.includeRosaryCollect)
    let generic = engine.buildSteps(for: Prayer(kind: .custom, languageCode: "he", customDevotionId: "rosary",
                                              customOptions: ["litanyOfLoreto": "true", "rosaryCollect": "false"]))
    let collect = PrayerPackStore.resolveBodyText(bundleId: "rosary", languageCode: "he", key: "rosaryCollect")
    XCTAssertEqual(generic.filter { $0.body == collect }.count, 1)
    XCTAssertEqual(generic.dropLast().last?.title, "נתפללה")
  }

  func testStandaloneAntiphonAndFranciscanCrownKeepTheirExistingBodies() throws {
    let basic = try XCTUnwrap(BasicPrayerCatalog.prayer(id: "salveRegina"))
    XCTAssertEqual(BasicPrayerCatalog.step(for: basic, languageCode: "en").body,
                   PrayerTranslations.get(languageCode: "en", key: .salveRegina))
    let crown = engine.buildSteps(for: Prayer(kind: .custom, languageCode: "en", customDevotionId: "franciscanCrown"))
    let antiphon = try XCTUnwrap(crown.first(where: \.isAntiphon))
    XCTAssertTrue(antiphon.body.contains(PrayerTranslations.get(languageCode: "en", key: .collectaStandard)))
  }
}

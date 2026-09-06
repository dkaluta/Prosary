import XCTest
@testable import Prosary

@MainActor
final class PrayerNamePresentationTests: XCTestCase {
  func testInterfaceLanguageIsTheDefaultAndTranslationIsOptIn() {
    let normal = PrayerNamePresentation(interfaceTitle: "Before a meal", prayerTitle: "צלותא", showPrayerLanguage: false)
    XCTAssertEqual(normal.title, "Before a meal")
    XCTAssertNil(normal.translation)
    let bilingual = PrayerNamePresentation(interfaceTitle: "Before a meal", prayerTitle: "צלותא", showPrayerLanguage: true)
    XCTAssertEqual(bilingual.title, "צלותא")
    XCTAssertEqual(bilingual.translation, "Before a meal")
  }

  func testSameDisplayNameDoesNotAddADuplicateSubtitle() {
    let name = PrayerNamePresentation(interfaceTitle: "שבועות", prayerTitle: "שָׁבוּעוֹת", showPrayerLanguage: true)
    XCTAssertEqual(name.title, "שבועות")
    XCTAssertNil(name.translation)
  }

  func testCatalogUsesInterfaceNamesUnlessExplicitlyEnabled() throws {
    let info = try XCTUnwrap(PrayerPackStore.info(for: "trisagion"))
    let interfaceTitle = info.displayNameByLanguage[UILanguage.current] ?? info.displayName
    let normal = info.namePresentation(prayerCode: "he-x-gamliel", showPrayerLanguage: false)
    XCTAssertEqual(normal.title, HebrewDisplayText.unpointed(interfaceTitle))
    XCTAssertNil(normal.translation)
    let bilingual = info.namePresentation(prayerCode: "he-x-gamliel", showPrayerLanguage: true)
    XCTAssertEqual(bilingual.title, "קדישת")
    XCTAssertEqual(bilingual.translation, interfaceTitle == "קדישת" ? nil : HebrewDisplayText.unpointed(interfaceTitle))
  }

  func testBasicPrayerShelfAndFlowHaveIndependentNameLanguages() throws {
    let prayer = try XCTUnwrap(BasicPrayerCatalog.all.first { $0.bodyKey == "paterNoster" })
    let normal = PrayerNamePresentation.basicPrayer(prayer, languageCode: "arc", showPrayerLanguage: false)
    XCTAssertEqual(normal.title, HebrewDisplayText.unpointed(PrayerPackStore.resolveBodyText(
      bundleId: prayer.bundleId, languageCode: UILanguage.current, key: prayer.titleKey)))
    let bilingual = PrayerNamePresentation.basicPrayer(prayer, languageCode: "arc", showPrayerLanguage: true)
    XCTAssertEqual(bilingual.title, "צלותא מרניתא")
    XCTAssertEqual(bilingual.translation, normal.title == bilingual.title ? nil : normal.title)
    XCTAssertEqual(BasicPrayerCatalog.step(for: prayer, languageCode: "arc").title, "צלותא מרניתא")
  }
}

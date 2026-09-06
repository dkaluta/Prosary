import XCTest
@testable import Prosary

@MainActor
final class PrayerLanguageControlsTests: XCTestCase {
  func testHebrewLanguageAndTraditionKeepTheStoredTextCode() {
    XCTAssertEqual(LanguageCatalog.pickerLanguageCode("he-x-gamliel"), "he")
    XCTAssertEqual(LanguageCatalog.selectingLanguage("he", current: "he-x-gamliel"), "he-x-gamliel")
    XCTAssertEqual(LanguageCatalog.selectingLanguage("ru", current: "he-x-gamliel"), "ru")
    XCTAssertEqual(LanguageCatalog.selectingLanguage("", current: "he-x-gamliel"), "")
    XCTAssertEqual(LanguageCatalog.resolve("he-x-gamliel").code, "he-x-gamliel")
    XCTAssertEqual(LanguageCatalog.resolve("arc").nativeName, "ܐܪܡܐܝܬ / ארמית")
  }

  func testFallbackPickerGroupsHebrewWithoutLosingTheTraditionsOrder() {
    let original = UserDefaults.standard.object(forKey: LanguageCatalog.fallbackOrderKey)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: LanguageCatalog.fallbackOrderKey) }
      else { LanguageCatalog.resetFallbackOrder() }
    }
    LanguageCatalog.setFallbackOrder(["he-x-gamliel", "he", "en", "la"])
    XCTAssertEqual(LanguageCatalog.fallbackLanguageOrder.filter { $0 == "he" }.count, 1)
    LanguageCatalog.setFallbackLanguageOrder(["en", "he", "la"])
    XCTAssertEqual(Array(LanguageCatalog.fallbackOrder.prefix(3)), ["en", "he-x-gamliel", "he"])
  }

  func testBasicPrayerHomeIDsAreDistinctAndValidateThePrayer() {
    XCTAssertEqual(BasicPrayerFavorites.homeRowID("ourFather"), "basic:ourFather")
    XCTAssertEqual(BasicPrayerFavorites.prayerID(homeRowID: "basic:ourFather"), "ourFather")
    XCTAssertNil(BasicPrayerFavorites.prayerID(homeRowID: "basic:unknown"))
    XCTAssertNil(BasicPrayerFavorites.prayerID(homeRowID: "rosary"))
  }

  func testClosingRunSignatureInvalidatesShiftedStepsButPreservesOrdinaryRuns() {
    var options = RosaryOptions()
    let baseline = PrayerRunSignature.rosary(options)
    XCTAssertFalse(baseline.contains("closing-v2"))
    options.includeClosingPopeIntention = false
    XCTAssertEqual(PrayerRunSignature.rosary(options), baseline)
    options.includeClosingPopeIntention = true
    XCTAssertTrue(PrayerRunSignature.rosary(options).hasSuffix("closing-v2:1,0,0"))
    options.includeClosingIntentions = true
    options.includeClosingPopeIntention = false
    options.includeClosingBishopIntention = false
    options.includeClosingDepartedIntention = false
    XCTAssertTrue(PrayerRunSignature.rosary(options).hasSuffix("closing-v2:0,0,0"))
  }
}

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

  func testFallbackPickerPreservesIndependentlyOrderedHebrewTraditionsAcrossSave() {
    let original = UserDefaults.standard.object(forKey: LanguageCatalog.fallbackOrderKey)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: LanguageCatalog.fallbackOrderKey) }
      else { LanguageCatalog.resetFallbackOrder() }
    }
    let preferred = ["he-x-gamliel", "arc", "he"]
    let order = preferred + LanguageCatalog.defaultFallbackOrder.filter { !preferred.contains($0) }
    LanguageCatalog.setFallbackOrder(order)
    var displayedOrder = LanguageCatalog.fallbackLanguageOrder
    XCTAssertEqual(displayedOrder, order, "Opening the editor must not collapse the Hebrew rows")
    displayedOrder.swapAt(0, 2)
    LanguageCatalog.setFallbackLanguageOrder(displayedOrder)
    XCTAssertEqual(UserDefaults.standard.stringArray(forKey: LanguageCatalog.fallbackOrderKey), displayedOrder)
    XCTAssertEqual(Array(LanguageCatalog.fallbackLanguageOrder.prefix(3)), ["he", "arc", "he-x-gamliel"])
    LanguageCatalog.setFallbackLanguageOrder(order)
    XCTAssertEqual(LanguageCatalog.fallbackLanguageOrder, order, "Mission, Aramaic and Vicariate keep their exact saved positions")
    XCTAssertEqual(Set(LanguageCatalog.fallbackLanguageOrder), Set(LanguageCatalog.all.map(\.code)))
  }

  func testFallbackLabelsDistinguishHebrewTraditionsWithoutChangingTheLanguagePicker() {
    XCTAssertEqual(LanguageCatalog.fallbackDisplayName("he"), "עברית — \(LanguageCatalog.traditionName("he"))")
    XCTAssertEqual(LanguageCatalog.fallbackDisplayName("he-x-gamliel"), "עברית — \(LanguageCatalog.traditionName("he-x-gamliel"))")
    XCTAssertNotEqual(LanguageCatalog.fallbackDisplayName("he"), LanguageCatalog.fallbackDisplayName("he-x-gamliel"))
    XCTAssertEqual(LanguageCatalog.fallbackDisplayName("arc"), LanguageCatalog.resolve("arc").nativeName)
    XCTAssertEqual(LanguageCatalog.languages.filter { $0.code.hasPrefix("he") }.map(\.code), ["he"])
  }

  func testContentFallbackUsesSharedHebrewOnceAtTheFirstTraditionPosition() {
    let original = UserDefaults.standard.object(forKey: LanguageCatalog.fallbackOrderKey)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: LanguageCatalog.fallbackOrderKey) }
      else { LanguageCatalog.resetFallbackOrder() }
    }
    LanguageCatalog.setFallbackOrder(["he-x-gamliel", "arc", "he", "en", "la"])
    XCTAssertEqual(Array(LanguageCatalog.fallbackChain(for: "he-x-gamliel").prefix(3)), ["he-x-gamliel", "arc", "he"])
    let missionFirst = LanguageCatalog.contentFallbackChain(for: "he-x-gamliel")
    XCTAssertEqual(Array(missionFirst.prefix(4)), ["he-x-gamliel", "he", "arc", LanguageCatalog.vicariateContentCode])
    XCTAssertEqual(missionFirst.filter { $0 == "he" }.count, 1)
    XCTAssertEqual(LanguageCatalog.selection(forContentCode: "he", requested: "he-x-gamliel"), "he-x-gamliel")

    LanguageCatalog.setFallbackOrder(["he", "arc", "he-x-gamliel", "en", "la"])
    XCTAssertEqual(Array(LanguageCatalog.contentFallbackChain(for: "he").prefix(4)), [LanguageCatalog.vicariateContentCode, "he", "arc", "he-x-gamliel"])
    XCTAssertEqual(LanguageCatalog.selection(forContentCode: LanguageCatalog.vicariateContentCode, requested: "he-x-gamliel"), "he")
    XCTAssertFalse(LanguageCatalog.all.contains { $0.code == LanguageCatalog.vicariateContentCode })
    XCTAssertEqual(Array(LanguageCatalog.fallbackChain(for: "fr-CA").prefix(2)), ["fr-CA", "fr"])
  }

  func testNativeHebrewSeparatesSharedVocabularyFromVicariatePrayerText() {
    for (key, value) in PrayerTranslations.hebrew {
      let generic = PrayerTranslations.genericHebrewKeys.contains(key)
      XCTAssertEqual(PrayerTranslations.nativeText(contentCode: "he", key: key), generic ? value : nil, key.rawValue)
      XCTAssertEqual(PrayerTranslations.nativeText(contentCode: LanguageCatalog.vicariateContentCode, key: key), generic ? nil : value, key.rawValue)
    }
    XCTAssertEqual(PrayerTranslations.genericHebrewKeys, [.decadeOrdinalFormat, .repetitionCounterConnector, .fructusMysteriiLabel])
    XCTAssertEqual(PrayerTranslations.nativeText(contentCode: "he-x-gamliel", key: .paterNoster), PrayerTranslations.hebrewGamaliel[.paterNoster])
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

import XCTest
@testable import Prosary

@MainActor
final class PrayerLanguageControlsTests: XCTestCase {
  func testInheritedPrayerLanguageTracksEveryInterfaceLocaleWithoutAValidPrayerOverride() {
    let originalInterface = InterfaceLanguageStore.shared.selection
    let defaults = UserDefaults.standard
    let originalDefault = defaults.object(forKey: "defaultLanguageCode")
    defer {
      InterfaceLanguageStore.shared.selection = originalInterface
      if let originalDefault { defaults.set(originalDefault, forKey: "defaultLanguageCode") }
      else { defaults.removeObject(forKey: "defaultLanguageCode") }
    }
    let inherited = Prayer(languageCode: "")
    let prayerDefaults: [String?] = [nil, "", "unknown"]
    for prayerDefault in prayerDefaults {
      if let prayerDefault { defaults.set(prayerDefault, forKey: "defaultLanguageCode") }
      else { defaults.removeObject(forKey: "defaultLanguageCode") }
      for language in ["en", "he", "ar", "ru", "tl", "fr", "it", "uk"] {
        InterfaceLanguageStore.shared.selection = language
        XCTAssertEqual(LanguageCatalog.resolve(nil).code, language)
        XCTAssertEqual(LanguageCatalog.resolve("").code, language)
        XCTAssertEqual(LanguageCatalog.fallbackChain(for: nil).first, language)
        XCTAssertEqual(LanguageCatalog.fallbackChain(for: "").first, language)
        XCTAssertEqual(inherited.resolvedLanguageCode, language)
        XCTAssertEqual(inherited.languageCode, "", "Following the interface must not rewrite a saved choice")
        XCTAssertFalse(AramaicSignOfCrossForm.isSystemWideActive)
      }
    }
    defaults.set("", forKey: "defaultLanguageCode")
    InterfaceLanguageStore.shared.selection = ""
    XCTAssertEqual(LanguageCatalog.resolve(nil).code, UILanguage.current)
    XCTAssertEqual(LanguageCatalog.fallbackChain(for: "").first, UILanguage.current)
  }

  func testGlobalPrayerOverrideSurvivesInterfaceChangesIncludingPrayerOnlyLanguages() {
    let originalInterface = InterfaceLanguageStore.shared.selection
    let defaults = UserDefaults.standard
    let originalDefault = defaults.object(forKey: "defaultLanguageCode")
    defer {
      InterfaceLanguageStore.shared.selection = originalInterface
      if let originalDefault { defaults.set(originalDefault, forKey: "defaultLanguageCode") }
      else { defaults.removeObject(forKey: "defaultLanguageCode") }
    }
    for language in LanguageCatalog.all.map(\.code) {
      defaults.set(language, forKey: "defaultLanguageCode")
      for interface in ["en", "he", "uk"] {
        InterfaceLanguageStore.shared.selection = interface
        XCTAssertEqual(UILanguage.current, interface)
        XCTAssertEqual(LanguageCatalog.resolve(nil).code, language)
        XCTAssertEqual(LanguageCatalog.resolve("").code, language)
        XCTAssertEqual(LanguageCatalog.fallbackChain(for: nil).first, language)
        XCTAssertEqual(LanguageCatalog.fallbackChain(for: "").first, language)
        XCTAssertEqual(Prayer(languageCode: "").resolvedLanguageCode, language)
        XCTAssertEqual(defaults.string(forKey: "defaultLanguageCode"), language)
        XCTAssertEqual(AramaicSignOfCrossForm.isSystemWideActive, language == "arc")
      }
    }
  }

  func testExplicitSavedPrayerLanguagesAndEditionsSurviveBothLanguageSettings() throws {
    let originalInterface = InterfaceLanguageStore.shared.selection
    let defaults = UserDefaults.standard
    let originalDefault = defaults.object(forKey: "defaultLanguageCode")
    defer {
      InterfaceLanguageStore.shared.selection = originalInterface
      if let originalDefault { defaults.set(originalDefault, forKey: "defaultLanguageCode") }
      else { defaults.removeObject(forKey: "defaultLanguageCode") }
    }
    for language in ["la", "arc", "he-x-gamliel", "he", "en"] {
      let prayer = Prayer(languageCode: language)
      let saved = try JSONEncoder().encode(prayer)
      for prayerDefault in ["", "arc", "la", "he-x-gamliel"] {
        defaults.set(prayerDefault, forKey: "defaultLanguageCode")
        for interface in ["en", "he", "uk"] {
          InterfaceLanguageStore.shared.selection = interface
          let restored = try JSONDecoder().decode(Prayer.self, from: saved)
          XCTAssertEqual(restored, prayer)
          XCTAssertEqual(restored.languageCode, language)
          XCTAssertEqual(restored.resolvedLanguageCode, language)
          XCTAssertEqual(LanguageCatalog.fallbackChain(for: language).first, language)
        }
      }
    }
  }

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

  func testRepositoryLanguageNamesKeepGenericHebrewSeparateFromTraditions() {
    XCTAssertEqual(LanguageCatalog.contentLanguageName("he"), "עברית")
    XCTAssertEqual(LanguageCatalog.contentLanguageName("iw"), "עברית")
    XCTAssertEqual(LanguageCatalog.contentLanguageName("he-x-gamliel"),
                   "עברית — \(LanguageCatalog.traditionName("he-x-gamliel"))")
    XCTAssertNotEqual(LanguageCatalog.contentLanguageName("he"), LanguageCatalog.fallbackDisplayName("he"))
    XCTAssertEqual(LanguageCatalog.contentLanguageName("fil"), LanguageCatalog.contentLanguageName("tl"))
    XCTAssertEqual(LanguageCatalog.contentLanguageNames(["he", "iw", "he-x-gamliel"]),
                   ["עברית", "עברית — \(LanguageCatalog.traditionName("he-x-gamliel"))"])
  }

  func testExistingBasicPrayerSelectionsPinImmediatelyWithoutSortingTheDirectory() {
    let oldIds = CloudSyncedList.read(BasicPrayerFavorites.idsKey)
    let oldSort = UserDefaults.standard.object(forKey: BasicPrayerFavorites.moveToTopKey)
    defer {
      if let oldIds { CloudSyncedList.write(oldIds, forKey: BasicPrayerFavorites.idsKey) }
      else { CloudSyncedList.remove(BasicPrayerFavorites.idsKey) }
      if let oldSort { UserDefaults.standard.set(oldSort, forKey: BasicPrayerFavorites.moveToTopKey) }
      else { UserDefaults.standard.removeObject(forKey: BasicPrayerFavorites.moveToTopKey) }
      CloudPreferencesGeneration.shared.bump()
    }
    CloudSyncedList.write(["holyGod"], forKey: "favoriteBasicPrayerIds")
    UserDefaults.standard.set(true, forKey: BasicPrayerFavorites.moveToTopKey)
    XCTAssertTrue(BasicPrayerFavorites.contains("holyGod"), "Legacy stars are already Pray pins")
    XCTAssertEqual(BasicPrayerFavorites.apply(BasicPrayerCatalog.all).map(\.id), BasicPrayerCatalog.all.map(\.id))
    let generation = CloudPreferencesGeneration.shared.value
    BasicPrayerFavorites.toggle("ourFather")
    XCTAssertTrue(BasicPrayerFavorites.contains("ourFather"))
    XCTAssertGreaterThan(CloudPreferencesGeneration.shared.value, generation, "An existing Pray window refreshes")
    BasicPrayerFavorites.toggle("holyGod")
    XCTAssertFalse(BasicPrayerFavorites.contains("holyGod"))
    XCTAssertTrue(BasicPrayerFavorites.contains("ourFather"), "Removing one pin retains the others")
    XCTAssertNotNil(BasicPrayerCatalog.prayer(id: "holyGod"), "Removing a pin never removes the prayer")
  }

  func testClosingRunSignatureInvalidatesShiftedStepsButPreservesOrdinaryRuns() {
    var options = RosaryOptions()
    let baseline = PrayerRunSignature.rosary(options)
    XCTAssertFalse(baseline.contains("closing-v2"))
    options.includeClosingPopeIntention = false
    XCTAssertEqual(PrayerRunSignature.rosary(options), baseline)
    options.includeClosingPopeIntention = true
    XCTAssertTrue(PrayerRunSignature.rosary(options).hasSuffix("closing-v2:1,1,1"))
    options.includeClosingIntentions = true
    options.includeClosingPopeIntention = false
    options.includeClosingBishopIntention = false
    options.includeClosingDepartedIntention = false
    XCTAssertEqual(PrayerRunSignature.rosary(options), baseline)
  }

  func testOpeningFatimaBookmarksResetOnlyWhenTheReorderedPrayerIsPresent() {
    var options = RosaryOptions()
    XCTAssertFalse(PrayerRunSignature.rosary(options).contains("opening-fatima-v2"))
    options.includeOpeningFatimaPrayer = true
    XCTAssertTrue(PrayerRunSignature.rosary(options).hasSuffix("opening-fatima-v2"))
    options.includeOpeningPrayers = false
    XCTAssertFalse(PrayerRunSignature.rosary(options).contains("opening-fatima-v2"))
  }

  func testCustomRosaryBookmarksFollowMigratedOptionsAndChangedSequences() {
    func signature(_ options: [String: String], bundle: String = "rosary") -> String {
      PrayerRunSignature.custom(bundle, effectiveVariantId: nil, dayIndex: 0, options: options)
    }
    XCTAssertEqual(signature([:]), "custom|rosary||0|")
    XCTAssertEqual(signature(["closingPopeIntention": "true"]), signature(["closingIntentions": "true"]))
    XCTAssertTrue(signature(["closingIntentions": "true"]).hasSuffix("closing-v2:1,1,1"))
    XCTAssertTrue(signature(["openingFatimaPrayer": "true"]).hasSuffix("opening-fatima-v2"))
    XCTAssertFalse(signature(["openingFatimaPrayer": "true", "openingPrayers": "false"]).contains("opening-fatima-v2"))
    XCTAssertFalse(signature(["openingFatimaPrayer": "true"], bundle: "anotherRosary").contains("opening-fatima-v2"))
  }
}

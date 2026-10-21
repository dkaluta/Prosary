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

  func testBasicPrayerShelfAndFlowKeepTheChosenPrayerLanguage() throws {
    let prayer = try XCTUnwrap(BasicPrayerCatalog.all.first { $0.bodyKey == "paterNoster" })
    let normal = PrayerNamePresentation.basicPrayer(prayer, languageCode: "arc", showPrayerLanguage: false)
    XCTAssertEqual(normal.title, "צלותא מרניתא")
    XCTAssertNil(normal.translation)
    let bilingual = PrayerNamePresentation.basicPrayer(prayer, languageCode: "arc", showPrayerLanguage: true)
    XCTAssertEqual(bilingual.title, "צלותא מרניתא")
    let interfaceTitle = HebrewDisplayText.unpointed(PrayerPackStore.resolveBodyText(
      bundleId: prayer.bundleId, languageCode: UILanguage.current, key: prayer.titleKey))
    XCTAssertEqual(bilingual.translation, interfaceTitle == bilingual.title ? nil : interfaceTitle)
    XCTAssertEqual(BasicPrayerCatalog.step(for: prayer, languageCode: "arc").title, "צלותא מרניתא")
  }

  func testBasicPrayerNamesCoverEveryPrayerLanguageWithAnOptionalInterfaceSubtitle() throws {
    let ourFatherTitles = [
      "la": "Pater Noster", "en": "Our Father", "he": "אבינו שבשמים",
      "he-x-gamliel": "תפילת האדון", "arc": "צלותא מרניתא", "ar": "الأبانا",
      "el": "Πάτερ ημών", "es": "Padre nuestro", "ru": "Отче наш",
      "tl": "Ama Namin", "fr": "Notre Père", "it": "Padre nostro",
      "uk": "Отче наш",
    ]
    XCTAssertEqual(Set(ourFatherTitles.keys), Set(LanguageCatalog.all.map(\.code)))
    for (language, expectedOurFather) in ourFatherTitles {
      for prayer in BasicPrayerCatalog.all {
        let title = HebrewDisplayText.unpointed(BasicPrayerCatalog.step(for: prayer, languageCode: language).title)
        for enabled in [false, true] {
          let name = PrayerNamePresentation.basicPrayer(prayer, languageCode: language,
            interfaceLanguage: "he", showPrayerLanguage: enabled)
          XCTAssertEqual(name.title, title, "\(prayer.id), \(language), \(enabled)")
          let interfaceCode = language == "he-x-gamliel" ? language : "he"
          let interfaceTitle = HebrewDisplayText.unpointed(BasicPrayerCatalog.title(for: prayer, languageCode: interfaceCode))
          XCTAssertEqual(name.translation, enabled && title != interfaceTitle ? interfaceTitle : nil)
          if prayer.id == "ourFather" { XCTAssertEqual(name.title, expectedOurFather, language) }
        }
      }
    }
  }

  func testHebrewBasicPrayerSubtitlesKeepTheSelectedRite() throws {
    let prayer = try XCTUnwrap(BasicPrayerCatalog.prayer(id: "ourFather"))
    for (language, expected) in [("he", "אבינו שבשמים"), ("he-x-gamliel", "תפילת האדון")] {
      for enabled in [false, true] {
        let name = PrayerNamePresentation.basicPrayer(prayer, languageCode: language,
          interfaceLanguage: "he", showPrayerLanguage: enabled)
        XCTAssertEqual(name.title, expected)
        XCTAssertNil(name.translation, "The Hebrew subtitle must not name the other rite")
      }
    }
    let bilingual = PrayerNamePresentation.basicPrayer(prayer, languageCode: "he-x-gamliel",
      interfaceLanguage: "en", showPrayerLanguage: true)
    XCTAssertEqual(bilingual.title, "תפילת האדון")
    XCTAssertEqual(bilingual.translation, "Our Father")
  }

  func testHebrewDevotionNamesFollowTheSessionRiteWithoutDuplicateSubtitles() throws {
    let saved = InterfaceLanguageStore.shared.selection
    let savedDefault = UserDefaults.standard.object(forKey: LanguageCatalog.defaultsKey)
    let savedOrder = UserDefaults.standard.object(forKey: LanguageCatalog.fallbackOrderKey)
    defer {
      InterfaceLanguageStore.shared.selection = saved
      for (key, value) in [(LanguageCatalog.defaultsKey, savedDefault), (LanguageCatalog.fallbackOrderKey, savedOrder)] {
        if let value { UserDefaults.standard.set(value, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
      }
    }
    InterfaceLanguageStore.shared.selection = "he"
    UserDefaults.standard.set("he-x-gamliel", forKey: LanguageCatalog.defaultsKey)
    LanguageCatalog.setFallbackOrder(["he-x-gamliel", "he"])
    let info = try XCTUnwrap(PrayerPackStore.info(for: "trisagion"))
    XCTAssertEqual(info.localizedDisplayName, "קדישת")
    for (language, expected) in [("he", "טריסאגיון"), ("he-x-gamliel", "קדישת")] {
      for enabled in [false, true] {
        let name = info.namePresentation(prayerCode: language, showPrayerLanguage: enabled)
        XCTAssertEqual(name.title, expected)
        XCTAssertNil(name.translation)
      }
    }
    XCTAssertEqual(info.namePresentation(prayerCode: "arc", showPrayerLanguage: false).title, "טריסאגיון")
    XCTAssertEqual(info.namePresentation(prayerCode: "arc", showPrayerLanguage: true).translation, "טריסאגיון")
    InterfaceLanguageStore.shared.selection = "en"
    XCTAssertEqual(info.namePresentation(prayerCode: "he-x-gamliel", showPrayerLanguage: false).title, "Trisagion")
    let bilingual = info.namePresentation(prayerCode: "he-x-gamliel", showPrayerLanguage: true)
    XCTAssertEqual(bilingual.title, "קדישת")
    XCTAssertEqual(bilingual.translation, "Trisagion")
  }

  func testVicariatePrayerHeadingsStayVicariateWithAMissionDefaultAndFallbackPriority() throws {
    let savedDefault = UserDefaults.standard.object(forKey: LanguageCatalog.defaultsKey)
    let savedOrder = UserDefaults.standard.object(forKey: LanguageCatalog.fallbackOrderKey)
    defer {
      for (key, value) in [(LanguageCatalog.defaultsKey, savedDefault), (LanguageCatalog.fallbackOrderKey, savedOrder)] {
        if let value { UserDefaults.standard.set(value, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
      }
    }
    UserDefaults.standard.set("he-x-gamliel", forKey: LanguageCatalog.defaultsKey)
    LanguageCatalog.setFallbackOrder(["he-x-gamliel", "he"])
    let expectedTitles = ["ourFather": "אבינו שבשמים", "hailMary": "שמחי מרים",
                          "gloryBe": "כבוד לאב", "creed": "אני מאמין", "holyGod": "קדוש האלהים"]
    for (id, expected) in expectedTitles {
      let prayer = try XCTUnwrap(BasicPrayerCatalog.prayer(id: id))
      let name = PrayerNamePresentation.basicPrayer(prayer, languageCode: "he",
        interfaceLanguage: "he", showPrayerLanguage: true)
      XCTAssertEqual(name.title, expected, id)
      XCTAssertNil(name.translation, id)
      XCTAssertEqual(HebrewDisplayText.unpointed(BasicPrayerCatalog.step(for: prayer, languageCode: "he").title), expected, id)
    }
  }

  func testBasicPrayerNamesFollowInterfaceChangesAndPreserveAnExplicitOverride() throws {
    let saved = InterfaceLanguageStore.shared.selection
    let savedDefault = UserDefaults.standard.object(forKey: "defaultLanguageCode")
    defer {
      InterfaceLanguageStore.shared.selection = saved
      if let savedDefault { UserDefaults.standard.set(savedDefault, forKey: "defaultLanguageCode") }
      else { UserDefaults.standard.removeObject(forKey: "defaultLanguageCode") }
    }
    UserDefaults.standard.set("", forKey: "defaultLanguageCode")
    let prayer = try XCTUnwrap(BasicPrayerCatalog.prayer(id: "ourFather"))
    for (language, title) in [("he", "אבינו שבשמים"), ("fr", "Notre Père")] {
      InterfaceLanguageStore.shared.selection = language
      let following = PrayerNamePresentation.basicPrayer(prayer, languageCode: "",
        interfaceLanguage: "he", showPrayerLanguage: false)
      XCTAssertEqual(following.title, title)
      XCTAssertEqual(PrayerNamePresentation.basicPrayer(prayer, languageCode: "en",
        interfaceLanguage: "he", showPrayerLanguage: false).title, "Our Father")
      XCTAssertEqual(PrayerNamePresentation.basicPrayer(prayer, languageCode: "he-x-gamliel",
        interfaceLanguage: "he", showPrayerLanguage: false).title, "תפילת האדון")
      XCTAssertEqual(PrayerNamePresentation.basicPrayer(prayer, languageCode: "arc",
        interfaceLanguage: "he", showPrayerLanguage: false).title, "צלותא מרניתא")
      XCTAssertEqual(LanguageCatalog.resolve("").code, language)
    }
    for (language, title) in [("he-x-gamliel", "תפילת האדון"), ("arc", "צלותא מרניתא")] {
      UserDefaults.standard.set(language, forKey: "defaultLanguageCode")
      XCTAssertEqual(UILanguage.current, "fr", "The prayer override does not change the interface")
      XCTAssertEqual(PrayerNamePresentation.basicPrayer(prayer, languageCode: "",
        interfaceLanguage: "he", showPrayerLanguage: false).title, title)
      XCTAssertEqual(PrayerNamePresentation.basicPrayer(prayer, languageCode: "en",
        interfaceLanguage: "he", showPrayerLanguage: false).title, "Our Father")
      XCTAssertEqual(LanguageCatalog.resolve("").code, language)
    }
  }

  func testHebrewRosaryOptionNamesFollowTheExplicitRiteAgainstTheAppDefault() throws {
    let savedInterface = InterfaceLanguageStore.shared.selection
    let savedDefault = UserDefaults.standard.object(forKey: LanguageCatalog.defaultsKey)
    let savedOrder = UserDefaults.standard.object(forKey: LanguageCatalog.fallbackOrderKey)
    defer {
      InterfaceLanguageStore.shared.selection = savedInterface
      for (key, value) in [(LanguageCatalog.defaultsKey, savedDefault), (LanguageCatalog.fallbackOrderKey, savedOrder)] {
        if let value { UserDefaults.standard.set(value, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
      }
    }
    InterfaceLanguageStore.shared.selection = "he"
    for (language, other, ourFather, hailMary, gloryBe, creed, cross) in [
      ("he", "he-x-gamliel", "אבינו שבשמים", "שמחי מרים", "כבוד לאב", "אני מאמין", "סימן הצלב"),
      ("he-x-gamliel", "he", "תפילת האדון", "שלום לך מרים", "השבח לאב", "מאמינים של ניקאה", "אות הצלב"),
    ] {
      UserDefaults.standard.set(other, forKey: LanguageCatalog.defaultsKey)
      LanguageCatalog.setFallbackOrder([other, language])
      func label(_ key: String, chosen: String? = nil) -> String {
        RosaryPrayerLabels.option("favoriteEditor." + key, languageCode: chosen ?? language, fallback: "missing")
          .replacingOccurrences(of: "\u{2068}", with: "").replacingOccurrences(of: "\u{2069}", with: "")
      }
      XCTAssertEqual(label("openingPrayers"), "“\(ourFather)” ו־3 “\(hailMary)” בפתיחה")
      XCTAssertEqual(label("openingFatimaPrayer"), "“הו ישוע שלי” אחרי תפילת “\(gloryBe)” הפותחת")
      XCTAssertEqual(label("apostlesCreed"), creed)
      XCTAssertEqual(label("finalSignOfCross"), "\(cross) בסוף")
      XCTAssertTrue(label("presenterModeFooter").contains("“\(hailMary)”"))
      XCTAssertTrue(label("presenterModeFooter").contains("“\(gloryBe)”"))
      let schemaOption = try XCTUnwrap(PrayerPackStore.options(for: "rosary").first { $0.key == "openingPrayers" })
      XCTAssertEqual(schemaOption.localizedName(bundleId: "rosary", languageCode: language),
                     RosaryPrayerLabels.option("favoriteEditor.openingPrayers", languageCode: language, fallback: "missing"))
      let antiphon = try XCTUnwrap(PrayerPackStore.options(for: "rosary").first { $0.key == "antiphon" })
      for optionCase in antiphon.cases ?? [] {
        guard let value = MarianAntiphonOption(rawValue: optionCase.id), value != .none, value != .seasonal else { continue }
        XCTAssertEqual(antiphon.localizedCaseName(optionCase, bundleId: "rosary", languageCode: language),
                       value.displayName(languageCode: language))
      }
      let inherited = label("openingPrayers", chosen: "")
      XCTAssertEqual(inherited, label("openingPrayers", chosen: other))
    }
  }

  func testRosaryCaptionsKeepOtherInterfacesAndUseNeutralHebrewForOtherPrayerLanguages() {
    for language in ["he", "he-x-gamliel", "en", "arc"] {
      let opening = RosaryPrayerLabels.option("favoriteEditor.openingPrayers", languageCode: language,
                                             interfaceLanguage: "en", fallback: "missing")
      XCTAssertEqual(opening, UILanguage.text("favoriteEditor.openingPrayers", language: "en", fallback: "missing"))
      XCTAssertEqual(RosaryPrayerLabels.hailMaryProgress(3, total: 10, languageCode: language,
                                                        interfaceLanguage: "en"), "Hail Mary 3 of 10")
    }
    for language in ["en", "arc"] {
      XCTAssertEqual(RosaryPrayerLabels.option("favoriteEditor.openingPrayers", languageCode: language,
                                               interfaceLanguage: "he", fallback: "missing"), "תפילות פתיחה")
      XCTAssertEqual(RosaryPrayerLabels.hailMaryProgress(3, total: 10, languageCode: language,
                                                        interfaceLanguage: "he"), "תפילה 3 מתוך 10")
      XCTAssertEqual(RosaryPrayerLabels.option("favoriteEditor.fatimaPrayer", languageCode: language,
                                               interfaceLanguage: "he", fallback: "missing"), "תפילת פאטימה בסוף כל רז")
    }
  }
}

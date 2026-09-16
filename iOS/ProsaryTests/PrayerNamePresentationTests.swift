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
          let interfaceTitle = HebrewDisplayText.unpointed(BasicPrayerCatalog.step(for: prayer, languageCode: "he").title)
          XCTAssertEqual(name.translation, enabled && title != interfaceTitle ? interfaceTitle : nil)
          if prayer.id == "ourFather" { XCTAssertEqual(name.title, expectedOurFather, language) }
        }
      }
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
}

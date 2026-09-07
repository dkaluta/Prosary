import XCTest
@testable import Prosary

@MainActor
final class HebrewLanguageSelectionTests: XCTestCase {
  private let mission = "he-x-gamliel"

  private func withOrder(_ order: [String], _ check: () -> Void) {
    let original = UserDefaults.standard.object(forKey: LanguageCatalog.fallbackOrderKey)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: LanguageCatalog.fallbackOrderKey) }
      else { LanguageCatalog.resetFallbackOrder() }
    }
    LanguageCatalog.setFallbackOrder(order)
    check()
  }

  func testEnteringHebrewUsesTheFirstSavedTraditionFromEveryOtherLanguageOrAppSetting() {
    for order in [[mission, "arc", "he"], ["he", "arc", mission]] {
      withOrder(order) {
        for current in LanguageCatalog.all.map(\.code).filter({ $0 != "he" && $0 != mission }) + [""] {
          XCTAssertEqual(LanguageCatalog.selectingLanguage("he", current: current), order[0], current)
        }
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: LanguageCatalog.fallbackOrderKey), order)
      }
    }
  }

  func testAlreadySelectedHebrewTraditionsRemainExplicitInEitherPriorityOrder() {
    for order in [[mission, "arc", "he"], ["he", "arc", mission]] {
      withOrder(order) {
        for current in ["he", mission] {
          XCTAssertEqual(LanguageCatalog.selectingLanguage("he", current: current), current)
        }
      }
    }
  }

  func testLeavingHebrewAndReturningUsesPriorityAgain() {
    for (order, previous) in [([mission, "arc", "he"], "he"), (["he", "arc", mission], mission)] {
      withOrder(order) {
        let english = LanguageCatalog.selectingLanguage("en", current: previous)
        XCTAssertEqual(english, "en")
        XCTAssertEqual(LanguageCatalog.selectingLanguage("he", current: english), order[0])
      }
    }
  }

  func testOtherLanguageAndEmptyChoicesArePassedThrough() {
    withOrder([mission, "arc", "he"]) {
      for next in LanguageCatalog.all.map(\.code).filter({ $0 != "he" }) + ["", "unknown"] {
        for current in ["he", mission, "en", ""] {
          XCTAssertEqual(LanguageCatalog.selectingLanguage(next, current: current), next)
        }
      }
    }
  }

  func testEmptyAndDamagedSavedOrdersUseOnlyKnownDistinctTraditions() {
    for (order, expected) in [([], "he"), (["unknown"], "he"),
                              (["unknown", LanguageCatalog.vicariateContentCode, mission, mission, "arc", "he"], mission),
                              (["unknown", "he", "he", "arc", mission], "he")] {
      withOrder(order) {
        XCTAssertEqual(LanguageCatalog.selectingLanguage("he", current: ""), expected)
        XCTAssertEqual(LanguageCatalog.fallbackOrder.filter { $0 == expected }.count, 1)
        XCTAssertFalse(LanguageCatalog.fallbackOrder.contains("unknown"))
        XCTAssertFalse(LanguageCatalog.fallbackOrder.contains(LanguageCatalog.vicariateContentCode))
      }
    }
  }

  func testSelectedMissionCodeReachesItsRealPrayerTextAndAppDefault() {
    withOrder([mission, "arc", "he"]) {
      let originalDefault = UserDefaults.standard.object(forKey: "defaultLanguageCode")
      defer {
        if let originalDefault { UserDefaults.standard.set(originalDefault, forKey: "defaultLanguageCode") }
        else { UserDefaults.standard.removeObject(forKey: "defaultLanguageCode") }
      }
      guard let prayer = BasicPrayerCatalog.prayer(id: "ourFather"),
            let expected = PrayerTranslations.hebrewGamaliel[.paterNoster] else {
        return XCTFail("The sourced Mission Our Father must exist")
      }
      let selected = LanguageCatalog.selectingLanguage("he", current: "en")
      let step = BasicPrayerCatalog.step(for: prayer, languageCode: selected)
      XCTAssertEqual(step.body, expected)
      XCTAssertEqual(step.title, "תפילת האדון")
      XCTAssertNotEqual(step.body, BasicPrayerCatalog.step(for: prayer, languageCode: "he").body)
      UserDefaults.standard.set(selected, forKey: "defaultLanguageCode")
      XCTAssertEqual(BasicPrayerCatalog.step(for: prayer, languageCode: "").body, expected)
      XCTAssertEqual(LanguageCatalog.resolve("").code, mission)
    }
  }
}

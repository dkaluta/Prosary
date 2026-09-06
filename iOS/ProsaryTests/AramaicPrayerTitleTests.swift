import XCTest
@testable import Prosary

final class AramaicPrayerTitleTests: XCTestCase {
  @MainActor
  func testEveryMainAramaicPrayerKeepsItsSourcedTitleAheadOfEnglishFallback() throws {
    let defaults = UserDefaults.standard
    let saved = defaults.stringArray(forKey: LanguageCatalog.fallbackOrderKey)
    defer {
      if let saved { defaults.set(saved, forKey: LanguageCatalog.fallbackOrderKey) }
      else { defaults.removeObject(forKey: LanguageCatalog.fallbackOrderKey) }
    }
    LanguageCatalog.setFallbackOrder(["en", "he", "la"])
    let steps = PrayerEngine().buildSteps(for: Prayer(languageCode: "arc"))
    let titles = [
      "signumCrucis": "רושמא דצליבא",
      "symbolumApostolorum": "מהימנינן",
      "paterNoster": "צלותא מרניתא",
      "aveMaria": "שלם לך מרים",
      "gloriaPatri": "שובחא לאבא",
    ]
    for (bodyKey, expectedTitle) in titles {
      let body = PrayerPackStore.resolveBodyText(bundleId: "rosary", languageCode: "arc", key: bodyKey)
      let matching = steps.filter { $0.body == body }
      XCTAssertFalse(matching.isEmpty, bodyKey)
      XCTAssertTrue(matching.allSatisfy { $0.title.hasPrefix(expectedTitle) }, bodyKey)
      let basic = try XCTUnwrap(BasicPrayerCatalog.all.first { $0.bodyKey == bodyKey })
      XCTAssertEqual(BasicPrayerCatalog.step(for: basic, languageCode: "arc").title, expectedTitle)
    }
  }
}

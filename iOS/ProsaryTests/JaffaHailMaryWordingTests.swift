import XCTest
@testable import Prosary

@MainActor
final class JaffaHailMaryWordingTests: XCTestCase {
  func testRetiredPreferenceNeverChangesNativeOrBasicPrayerWording() throws {
    let defaults = UserDefaults.standard
    let key = "useJaffaHailMaryWording"
    let originalPreference = defaults.object(forKey: key)
    defer {
      if let originalPreference { defaults.set(originalPreference, forKey: key) }
      else { defaults.removeObject(forKey: key) }
    }
    defaults.removeObject(forKey: key)
    let original = PrayerTranslations.get(languageCode: "he", key: .aveMaria)
    let mission = PrayerTranslations.get(languageCode: "he-x-gamliel", key: .aveMaria)
    let prayer = try XCTUnwrap(BasicPrayerCatalog.prayer(id: "hailMary"))
    XCTAssertTrue(original.contains("מְלֵאַת הַחֶסֶד"))
    for retiredPreference in [true, false] {
      defaults.set(retiredPreference, forKey: key)
      XCTAssertEqual(PrayerTranslations.get(languageCode: "he", key: .aveMaria), original)
      XCTAssertEqual(PrayerTranslations.get(languageCode: "he-x-gamliel", key: .aveMaria), mission)
      XCTAssertEqual(BasicPrayerCatalog.step(for: prayer, languageCode: "he").body, original)
      XCTAssertEqual(PrayerTranslations.hebrew[.aveMaria], original)
    }
  }
}

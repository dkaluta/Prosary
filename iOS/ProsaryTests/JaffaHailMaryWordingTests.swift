import Combine
import XCTest
@testable import Prosary

@MainActor
final class JaffaHailMaryWordingTests: XCTestCase {
  func testOnlyVicariateTextChangesAndKeepsItsPointingStyle() {
    let original = "מְלֵאַת הַחֶסֶד / מלאת החסד"
    let expected = "בְּרוּכַת הַחֶסֶד / ברוכת החסד"
    XCTAssertEqual(JaffaHailMaryWording.applying(to: original,
      contentCode: LanguageCatalog.vicariateContentCode, enabled: true), expected)
    XCTAssertEqual(JaffaHailMaryWording.applying(to: original,
      contentCode: LanguageCatalog.vicariateContentCode, enabled: false), original)
    for code in ["he", "he-x-gamliel", "arc", "en"] {
      XCTAssertEqual(JaffaHailMaryWording.applying(to: original, contentCode: code, enabled: true), original)
    }
    XCTAssertEqual(JaffaHailMaryWording.applying(to: "Unrelated text",
      contentCode: LanguageCatalog.vicariateContentCode, enabled: true), "Unrelated text")
  }

  func testNativeHailMaryDefaultsOffAndRestoresExactlyWithoutChangingMission() throws {
    let defaults = UserDefaults.standard
    let originalPreference = defaults.object(forKey: JaffaHailMaryWording.defaultsKey)
    defer {
      if let originalPreference { defaults.set(originalPreference, forKey: JaffaHailMaryWording.defaultsKey) }
      else { defaults.removeObject(forKey: JaffaHailMaryWording.defaultsKey) }
    }
    defaults.removeObject(forKey: JaffaHailMaryWording.defaultsKey)
    XCTAssertFalse(JaffaHailMaryWording.isEnabled)
    let original = PrayerTranslations.get(languageCode: "he", key: .aveMaria)
    let mission = PrayerTranslations.get(languageCode: "he-x-gamliel", key: .aveMaria)
    XCTAssertTrue(original.contains("מְלֵאַת הַחֶסֶד"))
    XCTAssertTrue(mission.contains("מְלֵאַת הַחֶסֶד"))
    let expected = original.replacingOccurrences(of: "מְלֵאַת הַחֶסֶד", with: "בְּרוּכַת הַחֶסֶד")
    defaults.set(true, forKey: JaffaHailMaryWording.defaultsKey)
    XCTAssertEqual(PrayerTranslations.get(languageCode: "he", key: .aveMaria), expected)
    XCTAssertEqual(PrayerTranslations.get(languageCode: "he-x-gamliel", key: .aveMaria), mission)
    let prayer = try XCTUnwrap(BasicPrayerCatalog.prayer(id: "hailMary"))
    XCTAssertEqual(BasicPrayerCatalog.step(for: prayer, languageCode: "he").body, expected)
    XCTAssertEqual(PrayerTranslations.hebrew[.aveMaria], original, "The canonical table must remain untouched")
    defaults.set(false, forKey: JaffaHailMaryWording.defaultsKey)
    XCTAssertEqual(PrayerTranslations.get(languageCode: "he", key: .aveMaria), original)
    XCTAssertEqual(BasicPrayerCatalog.step(for: prayer, languageCode: "he").body, original)
  }

  func testOpenPrayerMonitorPublishesWordingChangesFromSettings() async {
    let defaults = UserDefaults.standard
    let key = JaffaHailMaryWording.defaultsKey
    let original = defaults.object(forKey: key)
    let monitor = PrayerLanguageMonitor.shared
    let next = !monitor.usesJaffaHailMaryWording
    let updated = expectation(description: "open prayer receives the wording setting")
    let subscription = monitor.$usesJaffaHailMaryWording.dropFirst().sink { value in
      if value == next { updated.fulfill() }
    }
    defer {
      subscription.cancel()
      if let original { defaults.set(original, forKey: key) }
      else { defaults.removeObject(forKey: key) }
    }
    defaults.set(next, forKey: key)
    await fulfillment(of: [updated], timeout: 3)
  }
}

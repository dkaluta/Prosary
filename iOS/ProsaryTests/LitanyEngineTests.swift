import XCTest
@testable import Prosary

@MainActor
final class LitanyEngineTests: XCTestCase {
  func testEverySupportedLanguageHasOneContextAppropriateFinalCollect() throws {
    let bundle = "litanyOfLoreto"
    let info = try XCTUnwrap(PrayerPackStore.info(for: bundle))
    let engine = PrayerEngine(calendar: MockLiturgicalCalendar())
    for language in info.languages + ["he-x-gamliel"] {
      let standard = engine.buildSteps(for: Prayer(
        kind: .custom, languageCode: language, customDevotionId: bundle, variantId: "standard"))
      let after = engine.buildSteps(for: Prayer(
        kind: .custom, languageCode: language, customDevotionId: bundle, variantId: "afterRosary"))
      let standaloneCollect = PrayerPackStore.resolveBodyText(
        bundleId: bundle, languageCode: language, key: "collectStandard")
      let rosaryCollect = PrayerPackStore.resolveBodyText(
        bundleId: bundle, languageCode: language, key: "collectAfterRosary")
      XCTAssertEqual(standard.count, 16, language)
      XCTAssertEqual(after.count, 16, language)
      XCTAssertNotEqual(standaloneCollect, rosaryCollect, language)
      XCTAssertEqual(standard.last?.body, standaloneCollect, language)
      XCTAssertEqual(after.last?.body, rosaryCollect, language)
      XCTAssertFalse(standard.contains { $0.body == rosaryCollect }, language)
      XCTAssertFalse(after.contains { $0.body == standaloneCollect }, language)
      XCTAssertEqual(standard.dropLast().map(\.body), after.dropLast().map(\.body), language)
      XCTAssertFalse((standard + after).contains { $0.body.isEmpty }, language)
    }
  }
}

import XCTest
@testable import Prosary

@MainActor
final class RosarySkipFifthDecadeTests: XCTestCase {
  func testFullSetsSkipEachFifthMysteryAndPreserveOpeningAndClosingPrayers() {
    let engine = PrayerEngine(calendar: StubLiturgicalCalendar())
    for (mode, decades) in [(MysterySelectionMode.specific, 4), (.todaysMysteries, 4), (.fifteenMystery, 12), (.twentyMystery, 16)] {
      for presenter in [false, true] {
        var prayer = Prayer(languageCode: "en", rosary: RosaryOptions(mysterySelectionMode: mode,
          includeClosingIntentions: true, includeStMichaelPrayer: true, presenterMode: presenter))
        let original = engine.buildSteps(for: prayer)
        prayer.rosary.skipFifthDecade = true
        let shortened = engine.buildSteps(for: prayer)
        XCTAssertEqual(Set(shortened.compactMap(\.decadeIndex)), Set(0..<decades))
        XCTAssertFalse(shortened.contains { $0.mystery?.order == 5 })
        XCTAssertEqual(shortened.filter { $0.mystery != nil && $0.isScripture }.count, decades)
        XCTAssertEqual(shortened.filter { $0.decadeIndex == nil }.map { "\($0.title)|\($0.body)" },
                       original.filter { $0.decadeIndex == nil }.map { "\($0.title)|\($0.body)" })
      }
    }
  }

  func testExplicitFifthSingleMysteryRemainsAvailable() {
    let prayer = Prayer(languageCode: "en", rosary: RosaryOptions(mysterySelectionMode: .singleMystery,
      specificMysteryOrder: 5, skipFifthDecade: true))
    let steps = PrayerEngine().buildSteps(for: prayer)
    XCTAssertEqual(Set(steps.compactMap(\.decadeIndex)), [0])
    XCTAssertEqual(Set(steps.compactMap { $0.mystery?.order }), [5])
  }

  func testPersistenceAndLegacyDecodingKeepTheOptionAndInvalidateOnlyChangedRuns() throws {
    var prayer = Prayer(rosary: RosaryOptions(skipFifthDecade: true))
    let entry = PresetEntry(prayer: prayer)
    XCTAssertTrue(entry.toPrayer().rosary.skipFifthDecade)
    let shortenedSignature = PrayerRunSignature.rosary(prayer.rosary)
    let encoded = try JSONEncoder().encode(prayer.rosary)
    XCTAssertTrue(try JSONDecoder().decode(RosaryOptions.self, from: encoded).skipFifthDecade)
    var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    legacy.removeValue(forKey: "skipFifthDecade")
    let restored = try JSONDecoder().decode(RosaryOptions.self, from: JSONSerialization.data(withJSONObject: legacy))
    XCTAssertFalse(restored.skipFifthDecade)
    XCTAssertNotEqual(PrayerRunSignature.rosary(restored), shortenedSignature)
    prayer.rosary.skipFifthDecade = false
    entry.update(from: prayer)
    XCTAssertFalse(entry.toPrayer().rosary.skipFifthDecade)
    prayer.rosary.mysterySelectionMode = .singleMystery
    let singleSignature = PrayerRunSignature.rosary(prayer.rosary)
    prayer.rosary.skipFifthDecade = true
    XCTAssertEqual(PrayerRunSignature.rosary(prayer.rosary), singleSignature)
  }
}

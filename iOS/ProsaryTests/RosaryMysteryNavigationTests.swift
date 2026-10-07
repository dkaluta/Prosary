import XCTest
@testable import Prosary

@MainActor
final class RosaryMysteryNavigationTests: XCTestCase {
  func testFinalMysteryWithoutClosingPrayersHasACompletionTargetInEverySessionMode() {
    let engine = PrayerEngine(calendar: StubLiturgicalCalendar())
    let modes: [(MysterySelectionMode, Int)] = [(.singleMystery, 1), (.specific, 5),
      (.todaysMysteries, 5), (.fifteenMystery, 15), (.twentyMystery, 20)]
    for (mode, count) in modes {
      for presenter in [false, true] {
        let options = RosaryOptions(mysterySelectionMode: mode, specificMysteryOrder: 5,
          marianAntiphon: .none, includeClosingIntentions: false, includeStMichaelPrayer: false,
          includeLitanyOfLoreto: false, includeRosaryCollect: false,
          includeFinalSignOfCross: false, presenterMode: presenter)
        let steps = engine.buildSteps(for: Prayer(languageCode: "en", rosary: options))
        let starts = RosaryMysteryNavigation.announcementIndices(in: steps)
        XCTAssertEqual(starts.count, count)
        XCTAssertEqual(steps.last?.decadeIndex, count - 1)
        for index in steps.indices where steps[index].decadeIndex == count - 1 {
          XCTAssertEqual(RosaryMysteryNavigation.nextIndex(in: steps, from: index), steps.count)
        }
        XCTAssertNil(RosaryMysteryNavigation.nextIndex(in: steps, from: steps.count))
        if count > 1 {
          XCTAssertEqual(RosaryMysteryNavigation.nextIndex(in: steps, from: starts[count - 2]), starts.last)
          XCTAssertEqual(RosaryMysteryNavigation.previousIndex(in: steps, from: steps.count - 1), starts[count - 2])
        } else {
          XCTAssertNil(RosaryMysteryNavigation.previousIndex(in: steps, from: steps.count - 1))
        }
      }
    }
  }
}

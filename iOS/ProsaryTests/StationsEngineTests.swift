//
//  StationsEngineTests.swift
//  ProsaryTests
//

import XCTest
@testable import Prosary

final class StationsEngineTests: XCTestCase {
  private func engine() -> PrayerEngine {
    PrayerEngine(calendar: StubLiturgicalCalendar())
  }

  private func steps(languageCode: String = "en") -> [RosaryStep] {
    engine().buildSteps(for: Prayer(kind: .stationsOfTheCross, languageCode: languageCode))
  }

  func testOpeningPrayerThenFourteenStationsThenClosingPrayer() {
    let all = steps()
    XCTAssertEqual(all.first?.title, "Sign of the Cross")
    XCTAssertEqual(all[1].title, "Opening Prayer")
    XCTAssertEqual(all.last?.title, "Closing Prayer")

    let stationSteps = all.dropFirst(2).dropLast()
    XCTAssertEqual(stationSteps.count, 14)
  }

  func testStationsAreInOrderWithCorrectOrdinalSubtitles() {
    let stationSteps = Array(steps().dropFirst(2).dropLast())
    XCTAssertEqual(stationSteps.first?.subtitle, "1st Station")
    XCTAssertEqual(stationSteps[13].subtitle, "14th Station")
  }

  func testNoStepHasABeadTrackShape() {
    // Stations has no decades/beads — the flow UI shows a plain progress bar instead (see
    // ARCHITECTURE.md's "Bead progress track" section).
    let all = steps()
    XCTAssertTrue(all.allSatisfy { $0.mystery == nil && $0.decadeIndex == nil && $0.hailMaryIndexInDecade == nil })
  }

  func testEachStationBodyContainsTheSharedVersicleAndResponse() {
    let stationSteps = Array(steps().dropFirst(2).dropLast())
    for step in stationSteps {
      XCTAssertTrue(step.body.contains("We adore You, O Christ, and we bless You"))
      XCTAssertTrue(step.body.contains("Because by Your holy Cross You have redeemed the world"))
    }
  }

  func testFirstStationIsCondemnedToDeath() {
    let firstStation = steps().dropFirst(2).first
    XCTAssertEqual(firstStation?.title, "Jesus is Condemned to Death")
    XCTAssertEqual(firstStation?.imageKey, "station_01_condemned_to_death")
  }

  func testEnglishBodyContainsEnglishText() {
    XCTAssertTrue(steps(languageCode: "en").contains { $0.body.contains("We adore You") })
  }

  func testLatinBodyContainsLatinText() {
    XCTAssertTrue(steps(languageCode: "la").contains { $0.body.contains("Adoramus te, Christe") })
  }
}

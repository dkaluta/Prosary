//
//  FranciscanCrownEngineTests.swift
//  ProsaryTests
//

import XCTest
import SwiftUI
@testable import Prosary

private struct FixedLiturgicalCalendar: LiturgicalCalendarProviding {
  var antiphon: MarianAntiphonOption = .salveRegina

  func mysteryGroup(for date: Date) -> MysteryGroup { .joyful }
  func seasonColor(for date: Date) -> Color { .clear }
  func seasonalMarianAntiphon(for date: Date) -> MarianAntiphonOption { antiphon }
  func isEasterSeason(for date: Date) -> Bool { false }
}

final class FranciscanCrownEngineTests: XCTestCase {
  private func engine(antiphon: MarianAntiphonOption = .salveRegina) -> PrayerEngine {
    PrayerEngine(calendar: FixedLiturgicalCalendar(antiphon: antiphon))
  }

  func testSevenDecadesOfTenHailMarys() {
    let steps = engine().buildSteps(for: Prayer(kind: .franciscanCrown, languageCode: "en"))
    let decadeIndices = Set(steps.compactMap(\.decadeIndex))
    XCTAssertEqual(decadeIndices, Set(0..<7))

    for d in 0..<7 {
      let hailMarysInDecade = steps.filter { $0.decadeIndex == d && $0.hailMaryIndexInDecade != nil }
      XCTAssertEqual(hailMarysInDecade.count, 10, "decade \(d) should have 10 Hail Marys")
    }
  }

  func testNoStepHasAMystery() {
    // Franciscan Crown steps deliberately leave `mystery` nil (see BeadModels' generalization) —
    // the Seven Joys aren't Rosary "mysteries" even though 6 of the 7 reuse mystery imageKeys.
    let steps = engine().buildSteps(for: Prayer(kind: .franciscanCrown, languageCode: "en"))
    XCTAssertTrue(steps.allSatisfy { $0.mystery == nil })
  }

  func testTwoClosingHailMarysAndOneClosingOurFather() {
    let steps = engine().buildSteps(for: Prayer(kind: .franciscanCrown, languageCode: "en"))
    let nonDecadeHailMarys = steps.filter { $0.decadeIndex == nil && $0.title.hasPrefix("Hail Mary") }
    XCTAssertEqual(nonDecadeHailMarys.count, 2)

    let nonDecadeOurFathers = steps.filter { $0.decadeIndex == nil && $0.title == "Our Father" }
    XCTAssertEqual(nonDecadeOurFathers.count, 1)
  }

  func testEndsWithSeasonalAntiphonThenClosingCross() {
    let steps = engine(antiphon: .reginaCaeli).buildSteps(for: Prayer(kind: .franciscanCrown, languageCode: "en"))
    XCTAssertEqual(steps[steps.count - 2].title, "Regina Caeli")
    XCTAssertTrue(steps[steps.count - 2].isAntiphon)
    XCTAssertEqual(steps.last?.title, "Sign of the Cross")
  }

  func testFirstJoyIsAnnunciationReusingExistingMysteryContent() {
    let steps = engine().buildSteps(for: Prayer(kind: .franciscanCrown, languageCode: "en"))
    let firstJoy = steps.first { $0.decadeIndex == 0 && $0.isScripture }
    XCTAssertEqual(firstJoy?.title, "The Annunciation")
    XCTAssertEqual(firstJoy?.imageKey, "joyful_01_annunciation")
  }

  func testFourthJoyIsTheNewAdorationOfTheMagiContent() {
    let steps = engine().buildSteps(for: Prayer(kind: .franciscanCrown, languageCode: "en"))
    let fourthJoy = steps.first { $0.decadeIndex == 3 && $0.isScripture }
    XCTAssertEqual(fourthJoy?.title, "The Adoration of the Magi")
    XCTAssertEqual(fourthJoy?.imageKey, "franciscan_04_adoration_of_the_magi")
  }

  func testEnglishBodyContainsEnglishText() {
    let steps = engine().buildSteps(for: Prayer(kind: .franciscanCrown, languageCode: "en"))
    XCTAssertTrue(steps.contains { $0.body.contains("Hail Mary, full of grace") })
  }

  func testLatinBodyContainsLatinText() {
    let steps = engine().buildSteps(for: Prayer(kind: .franciscanCrown, languageCode: "la"))
    XCTAssertTrue(steps.contains { $0.body.contains("Ave Maria, gratia plena") })
  }
}

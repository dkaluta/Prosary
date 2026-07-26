//
//  SevenSorrowsEngineTests.swift
//  ProsaryTests
//

import XCTest
@testable import Prosary

final class SevenSorrowsEngineTests: XCTestCase {
  private let engine = PrayerEngine()

  func testSevenDecadesOfSevenHailMarys() {
    let steps = engine.buildSteps(for: Prayer(kind: .sevenSorrows, languageCode: "en"))
    let decadeIndices = Set(steps.compactMap(\.decadeIndex))
    XCTAssertEqual(decadeIndices, Set(0..<7))

    for d in 0..<7 {
      let hailMarysInDecade = steps.filter { $0.decadeIndex == d && $0.hailMaryIndexInDecade != nil }
      XCTAssertEqual(hailMarysInDecade.count, 7, "decade \(d) should have 7 Hail Marys")
    }
  }

  func testNoStepHasAMystery() {
    // Seven Sorrows steps deliberately leave `mystery` nil (see BeadModels' generalization) —
    // the Seven Sorrows aren't Rosary "mysteries", and unlike Franciscan Crown, none of the
    // seven reuse an existing mystery imageKey either.
    let steps = engine.buildSteps(for: Prayer(kind: .sevenSorrows, languageCode: "en"))
    XCTAssertTrue(steps.allSatisfy { $0.mystery == nil })
  }

  func testThreeClosingHailMarysForOurLadysTears() {
    let steps = engine.buildSteps(for: Prayer(kind: .sevenSorrows, languageCode: "en"))
    let nonDecadeHailMarys = steps.filter { $0.decadeIndex == nil && $0.title.hasPrefix("Hail Mary") }
    XCTAssertEqual(nonDecadeHailMarys.count, 3)
  }

  func testEndsWithClosingPrayerThenClosingCross() {
    let steps = engine.buildSteps(for: Prayer(kind: .sevenSorrows, languageCode: "en"))
    XCTAssertEqual(steps[steps.count - 2].title, "Our Lady of Sorrows")
    XCTAssertEqual(steps.last?.title, "Sign of the Cross")
  }

  func testFirstSorrowIsProphecyOfSimeon() {
    let steps = engine.buildSteps(for: Prayer(kind: .sevenSorrows, languageCode: "en"))
    let firstSorrow = steps.first { $0.decadeIndex == 0 && $0.hailMaryIndexInDecade == nil && $0.title != "Our Father" }
    XCTAssertEqual(firstSorrow?.title, "The Prophecy of Simeon")
    XCTAssertEqual(firstSorrow?.imageKey, "seven_sorrows_01_prophecy_of_simeon")
    XCTAssertTrue(firstSorrow?.isScripture ?? false)
  }

  func testFourthSorrowHasNoScriptureCitation() {
    // "Mary Meets Jesus on the Way of the Cross" isn't narrated in any Gospel — a traditional
    // devotional scene, not a quoted verse — so unlike the other six, it's not isScripture.
    let steps = engine.buildSteps(for: Prayer(kind: .sevenSorrows, languageCode: "en"))
    let fourthSorrow = steps.first { $0.decadeIndex == 3 && $0.hailMaryIndexInDecade == nil && $0.title != "Our Father" }
    XCTAssertEqual(fourthSorrow?.title, "Mary Meets Jesus on the Way of the Cross")
    XCTAssertFalse(fourthSorrow?.isScripture ?? true)
  }

  func testEnglishBodyContainsEnglishText() {
    let steps = engine.buildSteps(for: Prayer(kind: .sevenSorrows, languageCode: "en"))
    XCTAssertTrue(steps.contains { $0.body.contains("Hail Mary, full of grace") })
  }

  func testLatinBodyContainsLatinText() {
    let steps = engine.buildSteps(for: Prayer(kind: .sevenSorrows, languageCode: "la"))
    XCTAssertTrue(steps.contains { $0.body.contains("Ave Maria, gratia plena") })
  }
}

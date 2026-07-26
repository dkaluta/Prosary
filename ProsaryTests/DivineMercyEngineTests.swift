//
//  DivineMercyEngineTests.swift
//  ProsaryTests
//

import XCTest
@testable import Prosary

final class DivineMercyEngineTests: XCTestCase {
  private let engine = PrayerEngine()

  func testFiveDecadesOfTenPetitions() {
    let steps = engine.buildSteps(for: Prayer(kind: .divineMercyChaplet, languageCode: "en"))
    let decadeIndices = Set(steps.compactMap(\.decadeIndex))
    XCTAssertEqual(decadeIndices, Set(0..<5))

    for d in 0..<5 {
      let petitionsInDecade = steps.filter { $0.decadeIndex == d && $0.hailMaryIndexInDecade != nil }
      XCTAssertEqual(petitionsInDecade.count, 10, "decade \(d) should have 10 petitions")
    }
  }

  func testNoStepHasAMystery() {
    let steps = engine.buildSteps(for: Prayer(kind: .divineMercyChaplet, languageCode: "en"))
    XCTAssertTrue(steps.allSatisfy { $0.mystery == nil })
  }

  func testEveryStepReusesTheSingleDivineMercyImage() {
    // Unlike the Rosary/Franciscan Crown/Seven Sorrows, every step — opening, decades, and
    // closing alike — reuses the one divine_mercy_image illustration (the same reuse pattern
    // the Angelus uses for joyful_01_annunciation), since there's no per-decade content to
    // illustrate separately.
    let steps = engine.buildSteps(for: Prayer(kind: .divineMercyChaplet, languageCode: "en"))
    XCTAssertTrue(steps.allSatisfy { $0.imageKey == "divine_mercy_image" })
  }

  func testOfferingIsRepeatedIdenticallyAcrossEveryDecade() {
    let steps = engine.buildSteps(for: Prayer(kind: .divineMercyChaplet, languageCode: "en"))
    let offerings = steps.filter { $0.decadeIndex != nil && $0.hailMaryIndexInDecade == nil }
    XCTAssertEqual(offerings.count, 5)
    XCTAssertTrue(offerings.allSatisfy { $0.body.contains("Eternal Father, I offer You") })
  }

  func testOpeningReusesExistingPrayersNotNewContent() {
    let steps = engine.buildSteps(for: Prayer(kind: .divineMercyChaplet, languageCode: "en"))
    XCTAssertEqual(steps[0].title, "Sign of the Cross")
    XCTAssertEqual(steps[1].title, "Our Father")
    XCTAssertEqual(steps[2].title, "Hail Mary")
    XCTAssertEqual(steps[3].title, "The Apostles' Creed")
  }

  func testClosingAcclamationRepeatedThreeTimesThenClosingCross() {
    let steps = engine.buildSteps(for: Prayer(kind: .divineMercyChaplet, languageCode: "en"))
    let closingAcclamations = steps.filter { $0.decadeIndex == nil && $0.body.contains("Holy God") }
    XCTAssertEqual(closingAcclamations.count, 3)
    XCTAssertEqual(steps.last?.title, "Sign of the Cross")
  }

  func testEnglishBodyContainsEnglishText() {
    let steps = engine.buildSteps(for: Prayer(kind: .divineMercyChaplet, languageCode: "en"))
    XCTAssertTrue(steps.contains { $0.body.contains("For the sake of His sorrowful Passion") })
  }

  func testLatinBodyContainsLatinText() {
    let steps = engine.buildSteps(for: Prayer(kind: .divineMercyChaplet, languageCode: "la"))
    XCTAssertTrue(steps.contains { $0.body.contains("Pro dolorosa Eius passione") })
  }
}

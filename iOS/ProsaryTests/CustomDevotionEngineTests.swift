//
//  CustomDevotionEngineTests.swift
//  ProsaryTests
//
//  PrayerEngine.buildCustomDevotionSteps is the one generic builder behind every PrayerKind.custom
//  devotion; these tests exercise it via the actual bundled trisagion.prosaryprayer (produced by
//  Shared/tools/make-prosaryprayer.sh from Shared/content/trisagion) rather than a fixture, the
//  same convention PrayerPackLoaderTests uses for Rosary/Angelus.
//

import XCTest
@testable import Prosary

final class CustomDevotionEngineTests: XCTestCase {
  func testTrisagionProducesTheSixStepSequence() {
    let engine = PrayerEngine()
    let steps = engine.buildSteps(for: Prayer(kind: .custom, languageCode: "en", customDevotionId: "trisagion"))

    XCTAssertEqual(steps.count, 6)
    XCTAssertEqual(steps.map(\.title), [
      "Holy God", "Holy God", "Holy God", "Glory Be", "Holy God", "Holy God",
    ])
    XCTAssertTrue(steps[0].body.contains("Holy God, Holy Mighty One, Holy Immortal One"))
    XCTAssertTrue(steps[3].body.contains("Glory be to the Father"))
    XCTAssertTrue(steps[4].body.contains("Holy Immortal One, have mercy on us."))
    XCTAssertFalse(steps[4].body.contains("Holy Mighty One"))
  }

  func testTrisagionImagesMatchTheStepsJSONImageKeys() {
    let engine = PrayerEngine()
    let steps = engine.buildSteps(for: Prayer(kind: .custom, languageCode: "en", customDevotionId: "trisagion"))

    XCTAssertEqual(steps.map(\.imageKey), [
      "jesus_portrait", "jesus_portrait", "jesus_portrait", "glory_be", "jesus_portrait", "jesus_portrait",
    ])
  }

  func testMissingCustomDevotionIdProducesNoSteps() {
    let engine = PrayerEngine()
    let steps = engine.buildSteps(for: Prayer(kind: .custom, languageCode: "en"))
    XCTAssertTrue(steps.isEmpty)
  }
}

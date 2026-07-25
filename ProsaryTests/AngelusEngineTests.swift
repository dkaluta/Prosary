//
//  AngelusEngineTests.swift
//  ProsaryTests
//

import XCTest
import SwiftUI
@testable import Prosary

private struct FixedLiturgicalCalendar: LiturgicalCalendarProviding {
  var isEasterSeasonValue: Bool

  func mysteryGroup(for date: Date) -> MysteryGroup { .joyful }
  func seasonColor(for date: Date) -> Color { .clear }
  func seasonalMarianAntiphon(for date: Date) -> MarianAntiphonOption { .salveRegina }
  func isEasterSeason(for date: Date) -> Bool { isEasterSeasonValue }
}

final class AngelusEngineTests: XCTestCase {
  func testStandardFormOutsideEastertide() {
    let engine = MockAngelusEngine(calendar: FixedLiturgicalCalendar(isEasterSeasonValue: false))
    let steps = engine.buildSteps(languageCode: "en")

    XCTAssertEqual(steps.count, 7)
    XCTAssertEqual(steps.map(\.title), [
      "The Annunciation", "Hail Mary",
      "The Fiat", "Hail Mary",
      "The Incarnation", "Hail Mary",
      "Let Us Pray",
    ])
    XCTAssertTrue(steps[0].body.contains("The Angel of the Lord declared unto Mary"))
    XCTAssertTrue(steps[1].body.contains("Hail Mary, full of grace"))
    XCTAssertTrue(steps.last!.body.contains("Pour forth, we beseech Thee"))
    XCTAssertFalse(steps.contains { $0.body.contains("Queen of Heaven") })
  }

  func testReginaCaeliSubstitutionDuringEastertide() {
    let engine = MockAngelusEngine(calendar: FixedLiturgicalCalendar(isEasterSeasonValue: true))
    let steps = engine.buildSteps(languageCode: "en")

    XCTAssertEqual(steps.count, 1)
    XCTAssertEqual(steps[0].title, "Regina Caeli")
    XCTAssertTrue(steps[0].body.contains("Queen of Heaven, rejoice"))
    XCTAssertTrue(steps[0].body.contains("Rejoice and be glad, O Virgin Mary"))
    XCTAssertFalse(steps[0].body.contains("Pour forth, we beseech Thee"))
  }

  func testFallsBackToLatinWhenLanguageIsNil() {
    let engine = MockAngelusEngine(calendar: FixedLiturgicalCalendar(isEasterSeasonValue: false))
    let steps = engine.buildSteps(languageCode: nil)

    XCTAssertTrue(steps[0].body.contains("Angelus Domini nuntiavit Mariae"))
  }
}

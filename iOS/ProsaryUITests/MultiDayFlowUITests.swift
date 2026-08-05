//
//  MultiDayFlowUITests.swift
//  ProsaryUITests
//
//  The O Antiphons are the app's one days-type devotion, so they are what proves the multi-day
//  plumbing end to end: a day is picked for you, the day menu can move you to another, and a
//  day is five steps rather than the whole week at once.
//

import XCTest

final class MultiDayFlowUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  private func openOAntiphons(_ app: XCUIApplication) {
    app.tabBars.buttons["Categories"].tap()
    // Listed under both "advent" and "meditative", so the query has to take the first.
    let row = app.buttons["category.oAntiphons"].firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.tap()
  }

  /// A devotion with no favorite prays in the app's default language, which is Latin — the
  /// antiphon's title is translated, the day's own label is its Latin incipit either way.
  @MainActor
  func testADayIsItsOwnSequenceOfFiveSteps() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-resetStore"]
    app.launch()

    openOAntiphons(app)

    XCTAssertTrue(app.staticTexts["Lectio"].waitForExistence(timeout: 5))

    let nextButton = app.buttons["prayerFlowNextButton"]
    // Five steps in a day: reading, antiphon, Magnificat, Gloria Patri, antiphon again.
    for _ in 0..<4 {
      XCTAssertTrue(nextButton.exists)
      XCTAssertEqual(nextButton.label, "Next")
      nextButton.tap()
    }

    XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
    XCTAssertEqual(nextButton.label, "Finish")
    nextButton.tap()

    XCTAssertTrue(app.buttons["category.oAntiphons"].firstMatch.waitForExistence(timeout: 5))
  }

  @MainActor
  func testTheDayMenuMovesBetweenDays() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-resetStore"]
    app.launch()

    openOAntiphons(app)
    XCTAssertTrue(app.staticTexts["Lectio"].waitForExistence(timeout: 5))

    let dayMenu = app.buttons["dayMenu"]
    XCTAssertTrue(dayMenu.waitForExistence(timeout: 5), "A days-type devotion offers its day picker")
    dayMenu.tap()

    // Days are labelled "period — name": "23 December — O Emmanuel".
    let lastDay = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "O Emmanuel")).firstMatch
    XCTAssertTrue(lastDay.waitForExistence(timeout: 5))
    lastDay.tap()

    // Switching days restarts the sequence at that day's own reading.
    XCTAssertTrue(app.staticTexts["Lectio"].waitForExistence(timeout: 5))
    app.buttons["prayerFlowNextButton"].tap()
    XCTAssertTrue(app.staticTexts["O Emmanuel"].waitForExistence(timeout: 5))
  }
}

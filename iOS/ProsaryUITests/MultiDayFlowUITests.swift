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
    // The simulator remembers its orientation between runs, and landscape shortens every
    // list — rows fall below the fold and queries that assume a visible row fail for reasons
    // that have nothing to do with the app. Start upright, always.
    #if !os(macOS)
    XCUIDevice.shared.orientation = .portrait
    #endif
    continueAfterFailure = false
  }

  private func openOAntiphons(_ app: XCUIApplication) {
    let searchTab = app.tabBars.buttons["Search"]
    XCTAssertTrue(searchTab.waitForExistence(timeout: 10))
    searchTab.tap()
    XCTAssertTrue(app.buttons["search.category.all"].waitForExistence(timeout: 5))
    // Browse by identity: a Latin prayer title does not match the English search phrase.
    let row = app.buttons["search.local.oAntiphons"].firstMatch
    for _ in 0..<8 {
      if row.exists && row.isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(row.waitForExistence(timeout: 5) && row.isHittable, app.debugDescription)
    row.tap()
  }

  private func launchLatinPrayer() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)",
                           "-interfaceLanguageCode", "en", "-defaultLanguageCode", "la",
                           "-autoAdvanceSeconds", "0"]
    app.launch()
    return app
  }

  /// This fixture explicitly chooses Latin prayer text with English interface controls.
  @MainActor
  func testADayIsItsOwnSequenceOfFiveSteps() throws {
    let app = launchLatinPrayer()

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

    XCTAssertTrue(app.buttons["search.local.oAntiphons"].firstMatch.waitForExistence(timeout: 5))
  }

  @MainActor
  func testTheDayMenuMovesBetweenDays() throws {
    let app = launchLatinPrayer()

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

//
//  AngelusFlowUITests.swift
//  ProsaryUITests
//
//  A devotion with no favorite prays in the app's default language, which is Latin — and since
//  0.7.2 the step headings are translated too, so this walks the Angelus by its Latin headings
//  ("Angelus Domini", not "The Annunciation"). Asserting English is what made these tests fail
//  once the headings stopped being hardcoded literals.
//

import XCTest

final class AngelusFlowUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testAngelusFlowFromHomeToFinish() throws {
    let app = XCUIApplication()
    app.launch()

    // The Angelus card has a stable accessibility identifier regardless of the dynamic subtitle.
    app.buttons["angelusCard"].tap()

    // First step of the standard (non-Eastertide) form, headed in the praying language.
    XCTAssertTrue(app.staticTexts["Angelus Domini"].waitForExistence(timeout: 5))

    // Queried by identifier, not the "Next"/"Back" label text, since the system
    // navigation-bar back button also reads as plain "Back" and would otherwise collide.
    let nextButton = app.buttons["prayerFlowNextButton"]
    // 7 steps total: tapping Next 6 times reaches the last one, where the button becomes Finish.
    for _ in 0..<6 {
      XCTAssertTrue(nextButton.exists)
      XCTAssertEqual(nextButton.label, "Next")
      nextButton.tap()
    }

    XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
    XCTAssertEqual(nextButton.label, "Finish")
    nextButton.tap()

    // Back at Home — the Rosary card should be visible.
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testAngelusBackButtonReturnsToPreviousStep() throws {
    let app = XCUIApplication()
    app.launch()

    app.buttons["angelusCard"].tap()
    XCTAssertTrue(app.staticTexts["Angelus Domini"].waitForExistence(timeout: 5))

    app.buttons["prayerFlowNextButton"].tap()
    // The second step is the first Hail Mary — "Ave Maria" while praying in Latin.
    XCTAssertTrue(app.staticTexts["Ave Maria"].waitForExistence(timeout: 5))

    app.buttons["prayerFlowBackButton"].tap()
    XCTAssertTrue(app.staticTexts["Angelus Domini"].waitForExistence(timeout: 5))
  }

  /// Headings follow the prayer, not the interface: the same devotion prayed in English heads
  /// its first step "The Annunciation". Covers titleKey resolution end to end.
  @MainActor
  func testHeadingsFollowThePrayerLanguage() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-defaultLanguageCode", "en"]
    app.launch()

    app.buttons["angelusCard"].tap()
    XCTAssertTrue(app.staticTexts["The Annunciation"].waitForExistence(timeout: 5))
  }
}

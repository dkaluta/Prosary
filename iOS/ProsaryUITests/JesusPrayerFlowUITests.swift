//
//  JesusPrayerFlowUITests.swift
//  ProsaryUITests
//
//  These tests use -resetStore so the SwiftData store starts clean (no Jesus Prayer default),
//  ensuring tapping the home card always goes to JesusPrayerSetupView instead of jumping
//  straight to a flow. The target chooser is two rows of plain buttons (counts on top, the
//  open-ended choices below) rather than one five-segment picker, so the segments are ordinary
//  buttons carrying the `.isSelected` trait on both iOS and macOS. The counter flow advances
//  through its central "Pray" button — it passes a centralActionLabel, so PrayerStepFlowView
//  renders that instead of a footer Next.
//

import XCTest

final class JesusPrayerFlowUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  private func launchClean() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-resetStore"]
    app.launch()
    return app
  }

  @MainActor
  func testTargetChooserOffersBothRows() throws {
    let app = launchClean()
    app.buttons["jesusPrayerCard"].tap()

    for target in ["33", "66", "99", "Unbounded", "Custom"] {
      XCTAssertTrue(app.buttons[target].waitForExistence(timeout: 5),
                    "\(target) should be offered")
    }
    // 33 is the default, and the two rows share one selection.
    XCTAssertTrue(app.buttons["33"].isSelected)
    app.buttons["99"].tap()
    XCTAssertTrue(app.buttons["99"].isSelected)
    XCTAssertFalse(app.buttons["33"].isSelected)
  }

  @MainActor
  func testBoundedTargetDefaultsTo33AndTracksCount() throws {
    let app = launchClean()

    app.buttons["jesusPrayerCard"].tap()
    XCTAssertTrue(app.buttons["33"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["33"].isSelected)

    app.buttons["Begin"].tap()
    XCTAssertTrue(app.staticTexts["1 of 33"].waitForExistence(timeout: 5))

    app.buttons["centralActionButton"].tap()
    app.buttons["centralActionButton"].tap()
    XCTAssertTrue(app.staticTexts["3 of 33"].waitForExistence(timeout: 5))

    app.buttons["prayerFlowBackButton"].tap()
    XCTAssertTrue(app.staticTexts["2 of 33"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testUnboundedTargetHasNoFixedTotalAndAlwaysOffersFinish() throws {
    let app = launchClean()

    app.buttons["jesusPrayerCard"].tap()
    XCTAssertTrue(app.buttons["Unbounded"].waitForExistence(timeout: 5))
    app.buttons["Unbounded"].tap()
    app.buttons["Begin"].tap()

    XCTAssertTrue(app.staticTexts["1"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["1 of 33"].exists)

    app.buttons["centralActionButton"].tap()
    app.buttons["centralActionButton"].tap()
    XCTAssertTrue(app.staticTexts["3"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["prayerFlowNextButton"].exists,
                   "A counter flow replaces Next with the central Pray button")

    // An open-ended session never turns Next into Finish, so the toolbar offers it instead.
    let finishButton = app.buttons["Finish"]
    XCTAssertTrue(finishButton.exists)
    finishButton.tap()

    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testCustomTargetRequiresAValidNumberBeforeBeginIsEnabled() throws {
    let app = launchClean()

    app.buttons["jesusPrayerCard"].tap()
    XCTAssertTrue(app.buttons["Custom"].waitForExistence(timeout: 5))
    app.buttons["Custom"].tap()

    XCTAssertFalse(app.buttons["Begin"].isEnabled)

    app.textFields["Number of repetitions"].tap()
    app.textFields["Number of repetitions"].typeText("12")

    XCTAssertTrue(app.buttons["Begin"].isEnabled)
    app.buttons["Begin"].tap()
    XCTAssertTrue(app.staticTexts["1 of 12"].waitForExistence(timeout: 5))
  }
}

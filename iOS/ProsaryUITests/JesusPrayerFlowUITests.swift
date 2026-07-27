//
//  JesusPrayerFlowUITests.swift
//  ProsaryUITests
//
//  These tests use -resetStore so the SwiftData store starts clean (no Jesus Prayer default),
//  ensuring tapping the home card always goes to JesusPrayerSetupView instead of jumping
//  straight to a flow. On macOS the target picker is an NSSegmentedControl, so segments are
//  accessed via app.segmentedControls.firstMatch.buttons rather than app.buttons.
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
  func testBoundedTargetDefaultsTo33AndTracksCount() throws {
    let app = launchClean()

    app.buttons["jesusPrayerCard"].tap()

    // On macOS, the segmented target picker segments live inside an NSSegmentedControl.
    let targetPicker = app.segmentedControls.firstMatch
    XCTAssertTrue(targetPicker.waitForExistence(timeout: 5))
    XCTAssertTrue(targetPicker.buttons["33"].isSelected)

    app.buttons["Begin"].tap()
    XCTAssertTrue(app.staticTexts["1 of 33"].waitForExistence(timeout: 5))

    app.buttons["prayerFlowNextButton"].tap()
    app.buttons["prayerFlowNextButton"].tap()
    XCTAssertTrue(app.staticTexts["3 of 33"].waitForExistence(timeout: 5))

    app.buttons["prayerFlowBackButton"].tap()
    XCTAssertTrue(app.staticTexts["2 of 33"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testUnboundedTargetHasNoFixedTotalAndAlwaysOffersFinish() throws {
    let app = launchClean()

    app.buttons["jesusPrayerCard"].tap()
    let targetPicker = app.segmentedControls.firstMatch
    XCTAssertTrue(targetPicker.waitForExistence(timeout: 5))
    targetPicker.buttons["Unbounded"].tap()
    app.buttons["Begin"].tap()

    XCTAssertTrue(app.staticTexts["1"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["1 of 33"].exists)

    app.buttons["prayerFlowNextButton"].tap()
    app.buttons["prayerFlowNextButton"].tap()
    XCTAssertTrue(app.staticTexts["3"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons["prayerFlowNextButton"].label, "Next")

    let finishButton = app.buttons["Finish"]
    XCTAssertTrue(finishButton.exists)
    finishButton.tap()

    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testCustomTargetRequiresAValidNumberBeforeBeginIsEnabled() throws {
    let app = launchClean()

    app.buttons["jesusPrayerCard"].tap()
    let targetPicker = app.segmentedControls.firstMatch
    XCTAssertTrue(targetPicker.waitForExistence(timeout: 5))
    targetPicker.buttons["Custom"].tap()

    XCTAssertFalse(app.buttons["Begin"].isEnabled)

    app.textFields["Number of repetitions"].tap()
    app.textFields["Number of repetitions"].typeText("12")

    XCTAssertTrue(app.buttons["Begin"].isEnabled)
    app.buttons["Begin"].tap()
    XCTAssertTrue(app.staticTexts["1 of 12"].waitForExistence(timeout: 5))
  }
}

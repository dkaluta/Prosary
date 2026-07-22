//
//  JesusPrayerFlowUITests.swift
//  ProsaryUITests
//

import XCTest

final class JesusPrayerFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBoundedTargetDefaultsTo33AndTracksCount() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["The Jesus Prayer"].tap()
        XCTAssertTrue(app.buttons["33"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["33"].isSelected)

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
        let app = XCUIApplication()
        app.launch()

        app.buttons["The Jesus Prayer"].tap()
        app.buttons["Unbounded"].tap()
        app.buttons["Begin"].tap()

        XCTAssertTrue(app.staticTexts["1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["1 of 33"].exists)

        app.buttons["prayerFlowNextButton"].tap()
        app.buttons["prayerFlowNextButton"].tap()
        XCTAssertTrue(app.staticTexts["3"].waitForExistence(timeout: 5))
        // The footer button never turns into "Finish" for an unbounded session — only the
        // separate toolbar action (checked below) can end it.
        XCTAssertEqual(app.buttons["prayerFlowNextButton"].label, "Next")

        let finishButton = app.buttons["Finish"]
        XCTAssertTrue(finishButton.exists)
        finishButton.tap()

        XCTAssertTrue(app.buttons["Pray the Rosary"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCustomTargetRequiresAValidNumberBeforeBeginIsEnabled() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["The Jesus Prayer"].tap()
        app.buttons["Custom"].tap()

        XCTAssertFalse(app.buttons["Begin"].isEnabled)

        app.textFields["Number of repetitions"].tap()
        app.textFields["Number of repetitions"].typeText("12")

        XCTAssertTrue(app.buttons["Begin"].isEnabled)
        app.buttons["Begin"].tap()
        XCTAssertTrue(app.staticTexts["1 of 12"].waitForExistence(timeout: 5))
    }
}

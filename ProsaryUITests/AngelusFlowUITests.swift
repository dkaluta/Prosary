//
//  AngelusFlowUITests.swift
//  ProsaryUITests
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

        app.buttons["The Angelus"].tap()

        // First step of the standard (non-Eastertide) form.
        XCTAssertTrue(app.staticTexts["The Annunciation"].waitForExistence(timeout: 5))

        // Queried by identifier, not the "Next"/"Back" label text, since the system
        // navigation-bar back button (Home has no navigationTitle of its own) also reads as
        // plain "Back" and would otherwise collide with the footer's own Back button.
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

        // Back at Home.
        XCTAssertTrue(app.buttons["Pray the Rosary"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAngelusBackButtonReturnsToPreviousStep() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["The Angelus"].tap()
        XCTAssertTrue(app.staticTexts["The Annunciation"].waitForExistence(timeout: 5))

        app.buttons["prayerFlowNextButton"].tap()
        XCTAssertTrue(app.staticTexts["Hail Mary"].waitForExistence(timeout: 5))

        app.buttons["prayerFlowBackButton"].tap()
        XCTAssertTrue(app.staticTexts["The Annunciation"].waitForExistence(timeout: 5))
    }
}

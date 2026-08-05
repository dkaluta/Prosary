//
//  RosaryQuickSetupTests.swift
//  ProsaryUITests
//
//  "Pray any Rosary" opens the options over a scratch Prayer. Its sheet embeds the shared
//  option sections inside its own Form, and embedding the whole RosaryOptionsEditorView there
//  instead nested a Form in a Form — which SwiftUI renders as a clipped stub with no rows at
//  all (and lets the inner screen's navigation title win). Shipped that way in 0.7.1, so the
//  sheet's contents are asserted here rather than trusted.
//

import XCTest

final class RosaryQuickSetupTests: XCTestCase {
  func testPrayAnyRosaryShowsItsOptionsAndCanStartASession() {
    let app = XCUIApplication()
    app.launch()

    // "Pray any Rosary" moved into Pray's + menu when the tab became the favorites list.
    XCTAssertTrue(app.buttons["addFavoriteButton"].waitForExistence(timeout: 10))
    app.buttons["addFavoriteButton"].tap()

    let anyRosary = app.buttons["Pray any Rosary"]
    XCTAssertTrue(anyRosary.waitForExistence(timeout: 5))
    anyRosary.tap()

    // The sheet keeps its own title; the nested-Form bug let the inner screen's win.
    let sheet = app.navigationBars["Pray any Rosary"]
    XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Quick setup should keep its own title")

    // The first section, which is on screen as the sheet settles.
    XCTAssertTrue(app.staticTexts["Which mysteries?"].waitForExistence(timeout: 5),
                  "Options should render inside the sheet")

    // A Form only keeps visible rows in the accessibility tree, so reach the last section
    // by scrolling rather than asserting on something below the fold.
    app.swipeUp()
    XCTAssertTrue(app.switches["Final Sign of the Cross"].waitForExistence(timeout: 5),
                  "The closing section should render too")

    // And the point of the sheet: it starts a session.
    sheet.buttons["Pray"].tap()
    XCTAssertTrue(app.buttons["prayerFlowNextButton"].waitForExistence(timeout: 10),
                  "Praying from the quick setup should open the flow")
  }
}

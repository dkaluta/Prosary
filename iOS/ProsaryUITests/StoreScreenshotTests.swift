//
//  StoreScreenshotTests.swift
//  ProsaryUITests
//
//  Walks the five App Store screenshot screens and attaches full-screen captures — the iOS
//  half of the store-listing pipeline (Android's screenshots come from adb on the emulator;
//  simctl can't tap, so a UI test drives the simulator instead). Extraction:
//  xcodebuild test -only-testing:ProsaryUITests/StoreScreenshotTests -resultBundlePath r.xcresult
//  then `xcrun xcresulttool export attachments` and copy into iOS/fastlane/screenshots/en-US.
//

import XCTest

final class StoreScreenshotTests: XCTestCase {
  private func snap(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testCaptureStoreScreenshots() {
    let app = XCUIApplication()
    app.launch()

    // 1 — Home (Pray tab).
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10))
    snap("01-home")

    // 2 — praying the Rosary (bead track). A saved session prays on one tap now; there is no
    // picker in between since the Pray tab became the favorites list.
    app.buttons["rosaryCard"].tap()
    XCTAssertTrue(app.buttons["prayerFlowNextButton"].waitForExistence(timeout: 10))
    snap("02-rosary")
    app.navigationBars.buttons.element(boundBy: 0).tap() // back to Pray

    // 3 — Stations of the Cross flow, opened from Categories (it has no saved session).
    app.tabBars.buttons["Categories"].tap()
    // A List keeps only visible rows in the accessibility tree, and the Stations sit below the
    // fold under their tag, so scroll until the row is actually there.
    let stations = app.buttons["category.stationsOfTheCross"].firstMatch
    for _ in 0..<6 where !stations.exists {
      app.swipeUp()
    }
    XCTAssertTrue(stations.waitForExistence(timeout: 5))
    stations.tap()
    XCTAssertTrue(app.buttons["prayerFlowNextButton"].waitForExistence(timeout: 10))
    snap("03-stations")
    app.navigationBars.buttons.element(boundBy: 0).tap()

    // 4 — Browse (live catalog; give the fetch room).
    let browseTab = app.tabBars.buttons["Browse"]
    XCTAssertTrue(browseTab.waitForExistence(timeout: 5))
    browseTab.tap()
    _ = app.staticTexts["Kyrie"].waitForExistence(timeout: 15)
    snap("04-browse")

    // 5 — Categories.
    app.tabBars.buttons["Categories"].tap()
    sleep(1)
    snap("05-categories")
  }
}

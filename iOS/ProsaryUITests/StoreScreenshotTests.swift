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
  override func setUpWithError() throws {
    // The simulator remembers its orientation between runs, and landscape shortens every
    // list — rows fall below the fold and queries that assume a visible row fail for reasons
    // that have nothing to do with the app. Start upright, always.
    #if os(iOS)
    XCUIDevice.shared.orientation = .portrait
    #endif
  }

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

    // 2 — praying the Rosary (bead track). The card opens the Rosary's presets; the default
    // one sits at the top of that screen and prays on a tap.
    app.buttons["rosaryCard"].tap()
    let defaultPreset = app.buttons["prayDefaultPreset"].firstMatch
    XCTAssertTrue(defaultPreset.waitForExistence(timeout: 10))
    defaultPreset.tap()
    XCTAssertTrue(app.buttons["prayerFlowNextButton"].waitForExistence(timeout: 10))
    snap("02-rosary")
    app.navigationBars.buttons.element(boundBy: 0).tap() // back to the presets
    app.navigationBars.buttons.element(boundBy: 0).tap() // back to Pray

    // 3 — Stations of the Cross flow, opened from Search (it has no saved session).
    app.tabBars.buttons["Search"].tap()
    let searchField = app.searchFields.firstMatch
    XCTAssertTrue(searchField.waitForExistence(timeout: 5))
    searchField.tap()
    searchField.typeText("Stations")
    // A List keeps only visible rows in the accessibility tree, and the Stations sit below the
    // fold in the local list, so scroll until the row is actually reachable — existing is not
    // enough, since a row half-under the tab bar swallows the tap (which is how adding a
    // devotion above it broke this).
    let stations = app.buttons["search.local.stationsOfTheCross"].firstMatch
    for _ in 0..<8 where !stations.isHittable {
      app.swipeUp(velocity: .slow)
    }
    XCTAssertTrue(stations.isHittable)
    stations.tap()
    // A list still carrying scroll momentum swallows the tap: the row is hittable where it was
    // a moment ago, not where the finger lands. One retry rather than a longer sleep.
    if !app.buttons["prayerFlowNextButton"].waitForExistence(timeout: 5) {
      stations.tap()
    }
    XCTAssertTrue(app.buttons["prayerFlowNextButton"].waitForExistence(timeout: 10))
    snap("03-stations")
    app.navigationBars.buttons.element(boundBy: 0).tap()

    // 4 — Community catalogue, opened from Search.
    app.tabBars.buttons["Search"].tap()
    let community = app.buttons["search.community"]
    XCTAssertTrue(community.waitForExistence(timeout: 5))
    community.tap()
    _ = app.staticTexts["Kyrie"].waitForExistence(timeout: 15)
    snap("04-browse")
    app.buttons["Done"].tap()

    // 5 — Daily readings, opened from its Home widget.
    app.tabBars.buttons["Home"].tap()
    let readings = app.buttons["homeWidgets.open.readings"]
    for _ in 0..<6 where !readings.isHittable { app.swipeUp() }
    XCTAssertTrue(readings.isHittable)
    readings.tap()
    XCTAssertTrue(app.buttons["readings.chooseDate"].waitForExistence(timeout: 5))
    snap("05-readings")
  }
}

//
//  ProsaryUITestsLaunchTests.swift
//  ProsaryUITests
//
//  Cold-launch health: the app reaches Home with its devotion cards loaded from the bundled
//  packs, and attaches the launch screenshot Xcode collects per UI configuration.
//

import XCTest

final class ProsaryUITestsLaunchTests: XCTestCase {
  override class var runsForEachTargetApplicationUIConfiguration: Bool { true }

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testLaunchReachesHome() throws {
    let app = XCUIApplication()
    app.launch()

    // Pray lists saved sessions, and a fresh store seeds exactly one — a store that failed to
    // open would leave the tab empty, which "did it launch" alone would miss. This runs once
    // per UI configuration, so it asserts only what every configuration shows.
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 15))

    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Launch Screen"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor
  func testLaunchPerformance() throws {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
      XCUIApplication().launch()
    }
  }
}

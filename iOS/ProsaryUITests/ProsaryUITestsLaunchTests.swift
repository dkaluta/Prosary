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

    // A pack that fails to load would leave Home without its cards — the failure mode a bare
    // "did it launch" check misses entirely.
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 15))
    XCTAssertTrue(app.buttons["angelusCard"].exists)
    XCTAssertTrue(app.buttons["jesusPrayerCard"].exists)

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

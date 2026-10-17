//
//  PrayerAdaptiveUITests.swift
//  ProsaryUITests
//
//  Exercise the same live reader while its available space and native bars change. These
//  run on ordinary iPhones as well as Duo; fold poses still require simulator/device checks
//  because XCUIDevice exposes orientation, not a public fold operation.
//

import XCTest
#if os(iOS)
import UIKit

final class PrayerAdaptiveUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    executionTimeAllowance = 240
    XCUIDevice.shared.orientation = .portrait
  }

  override func tearDownWithError() throws {
    XCUIDevice.shared.orientation = .portrait
  }

  @MainActor
  private func launchClean() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)",
                           "-interfaceLanguageCode", "en", "-defaultLanguageCode", "en",
                           "-autoAdvanceSeconds", "0"]
    app.launch()
    return app
  }

  @MainActor
  private func openRosary(in app: XCUIApplication) {
    let pray = app.buttons["Pray"].firstMatch
    if pray.waitForExistence(timeout: 5) { pray.tap() }
    else { app.cells["Pray"].firstMatch.tap() }
    let card = app.buttons["rosaryCard"]
    XCTAssertTrue(card.waitForExistence(timeout: 10))
    card.tap()
    let preset = app.buttons["prayDefaultPreset"].firstMatch
    XCTAssertTrue(preset.waitForExistence(timeout: 10))
    preset.tap()
    XCTAssertTrue(app.staticTexts["prayerProgressText"].waitForExistence(timeout: 10))
  }

  @MainActor
  private func waitForLabel(_ label: String, on element: XCUIElement) {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", label), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
  }

  @MainActor
  private func assertReachable(_ control: XCUIElement, in app: XCUIApplication) {
    let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      control.exists && control.isHittable && app.frame.insetBy(dx: -1, dy: -1).contains(control.frame)
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 15), .completed,
                   "\(control.identifier) stays visible and reachable after the layout changes")
    // Native bar buttons expose their visible glyph/pill frames, which can be smaller than
    // the system-managed touch area. Their reachability is the relevant assertion here.
  }

  @MainActor
  private func capture(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor
  private func tapToolbarAction(_ identifier: String, in app: XCUIApplication) {
    let action = app.buttons[identifier]
    if !action.isHittable {
      // Native toolbars may put secondary actions in overflow at narrow or short sizes.
      let more = app.buttons["More"].firstMatch
      XCTAssertTrue(more.waitForExistence(timeout: 5), app.debugDescription)
      more.tap()
    }
    XCTAssertTrue(action.waitForExistence(timeout: 5) && action.isHittable, app.debugDescription)
    action.tap()
  }

  @MainActor
  func testLiveRosaryKeepsProgressAndNavigationAcrossBothLandscapeDirections() throws {
    let app = launchClean()
    defer { app.terminate() }
    openRosary(in: app)
    let progress = app.staticTexts["prayerProgressText"]
    let firstProgress = progress.label
    let next = app.buttons["prayerFlowNextButton"]
    let back = app.buttons["prayerFlowBackButton"]
    next.tap()
    let advanced = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label != %@", firstProgress), object: progress)
    XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 5), .completed)
    let currentProgress = progress.label
    let currentBody = app.staticTexts["prayerBodyText"].label

    for (orientation, name) in [(UIDeviceOrientation.landscapeLeft, "landscape-left"),
                                (.landscapeRight, "landscape-right"), (.portrait, "portrait")] {
      XCUIDevice.shared.orientation = orientation
      assertReachable(next, in: app)
      assertReachable(back, in: app)
      XCTAssertEqual(app.buttons.matching(identifier: "prayerFlowNextButton").count, 1)
      XCTAssertEqual(app.buttons.matching(identifier: "prayerFlowBackButton").count, 1)
      XCTAssertEqual(progress.label, currentProgress)
      XCTAssertEqual(app.staticTexts["prayerBodyText"].label, currentBody)
      XCTAssertFalse(app.alerts.firstMatch.exists, "Resizing keeps the current session open")

      let overlap = next.frame.intersection(back.frame)
      XCTAssertFalse(overlap.width > 1 && overlap.height > 1)
      if abs(next.frame.midY - back.frame.midY) > abs(next.frame.midX - back.frame.midX) {
        // Duo's vertical arrangement belongs to the system toolbar rather than a custom
        // horizontal footer rotated into the content area.
        for identifier in ["prayerFlowBackButton", "prayerFlowNextButton"] {
          XCTAssertTrue(app.toolbars.containing(.button, identifier: identifier).firstMatch.exists
            || app.navigationBars.containing(.button, identifier: identifier).firstMatch.exists,
            "Vertical prayer navigation uses the native bar")
        }
      }
      capture("adaptive-rosary-" + name)

      back.tap()
      waitForLabel(firstProgress, on: progress)
      next.tap()
      waitForLabel(currentProgress, on: progress)
    }
  }

  @MainActor
  func testOpenMysterySheetKeepsItsSelectionAndSessionAcrossRotation() throws {
    let app = launchClean()
    defer { app.terminate() }
    openRosary(in: app)
    app.buttons["prayerFlowNextButton"].tap()
    let progress = app.staticTexts["prayerProgressText"]
    let currentProgress = progress.label
    tapToolbarAction("chooseMysteryButton", in: app)
    let selector = app.buttons["mysterySetSelector"]
    XCTAssertTrue(selector.waitForExistence(timeout: 5))
    selector.tap()
    let joyful = app.buttons["Joyful"]
    XCTAssertTrue(joyful.waitForExistence(timeout: 5))
    joyful.tap()
    let entireSet = app.buttons["chooseMystery.entireSet"]
    XCTAssertTrue(entireSet.waitForExistence(timeout: 5))

    for (orientation, name) in [(UIDeviceOrientation.landscapeLeft, "landscape"),
                                (.portrait, "portrait")] {
      XCUIDevice.shared.orientation = orientation
      assertReachable(app.buttons["Cancel"], in: app)
      XCTAssertTrue(entireSet.exists, "The sheet keeps the selected mystery group")
      XCTAssertTrue(app.buttons["chooseMystery.joyful.1"].exists)
      XCTAssertFalse(app.buttons["chooseMystery.sorrowful.1"].exists)
      XCTAssertFalse(app.alerts.firstMatch.exists)
      capture("adaptive-open-mystery-sheet-" + name)
    }

    app.buttons["Cancel"].tap()
    assertReachable(app.buttons["prayerFlowNextButton"], in: app)
    XCTAssertEqual(progress.label, currentProgress, "Cancel returns to the same live prayer step")
  }

  @MainActor
  func testJesusPrayerKeepsItsCountAndCentralActionAcrossRotation() throws {
    let app = launchClean()
    defer { app.terminate() }
    let search = app.buttons["Search"].firstMatch
    if search.waitForExistence(timeout: 5) { search.tap() }
    else { app.cells["Search"].firstMatch.tap() }
    XCTAssertTrue(app.buttons["search.category.all"].waitForExistence(timeout: 10))
    let row = app.buttons["search.local.jesusPrayer"].firstMatch
    for _ in 0..<8 {
      if row.exists && row.isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(row.waitForExistence(timeout: 5) && row.isHittable)
    row.tap()
    let begin = app.buttons["Begin"]
    XCTAssertTrue(begin.waitForExistence(timeout: 5))
    begin.tap()
    let progress = app.staticTexts["prayerProgressText"]
    waitForLabel("1 of 33", on: progress)
    let action = app.buttons["centralActionButton"]
    let body = app.staticTexts["prayerBodyText"].label
    action.tap()
    waitForLabel("2 of 33", on: progress)

    for (index, pose) in [(UIDeviceOrientation.landscapeLeft, "landscape-left"),
                          (.landscapeRight, "landscape-right"), (.portrait, "portrait")].enumerated() {
      XCUIDevice.shared.orientation = pose.0
      assertReachable(action, in: app)
      XCTAssertGreaterThanOrEqual(action.frame.width, 44)
      XCTAssertGreaterThanOrEqual(action.frame.height, 44)
      waitForLabel("\(index + 2) of 33", on: progress)
      XCTAssertEqual(app.staticTexts["prayerBodyText"].label, body)
      XCTAssertEqual(app.buttons.matching(identifier: "centralActionButton").count, 1)
      XCTAssertFalse(app.buttons["prayerFlowBackButton"].exists)
      XCTAssertFalse(app.buttons["prayerFlowNextButton"].exists)
      XCTAssertFalse(app.alerts.firstMatch.exists)
      capture("adaptive-jesus-prayer-" + pose.1)
      action.tap()
      waitForLabel("\(index + 3) of 33", on: progress)
    }
  }
}
#endif

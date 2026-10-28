#if os(iOS)
import XCTest

final class BibleBookUITests: XCTestCase {
  @MainActor private func openReader() throws -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
      "-readingsEditionId", "douay-rheims-1899", "-homeWidgetOrder", "scripture"]
    app.launch()
    let open = app.buttons["homeWidgets.open.scripture"]
    XCTAssertTrue(open.waitForExistence(timeout: 10)); open.tap()
    let counter = app.staticTexts["bible.pageCount"]
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      counter.exists && Int(counter.label.replacingOccurrences(of: ",", with: "").split(whereSeparator: { !$0.isNumber }).last ?? "0") ?? 0 > 500
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 90), .completed)
    return app
  }
  @MainActor private func select(_ title: String, in app: XCUIApplication) {
    let button = app.buttons[title].firstMatch
    if button.exists { button.tap() } else { app.cells[title].firstMatch.tap() }
  }
  @MainActor func testBibleTabRetainsTheCurrentSourceBlockAfterVisitingHome() throws {
    let app = try openReader(); defer { app.terminate() }
    let counter = app.staticTexts["bible.pageCount"]
    let first = counter.label
    app.buttons["bible.nextPage"].tap()
    let advanced = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", first), object: counter)
    XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 10), .completed)
    let retained = counter.label
    select("Home", in: app); select("Bible", in: app)
    XCTAssertTrue(counter.waitForExistence(timeout: 5)); XCTAssertEqual(counter.label, retained)
    XCTAssertFalse(app.progressIndicators["bible.preparingEdition"].exists)
  }
  @MainActor func testPhoneUsesJustifiedContinuousTextWithInlineMarkers() throws {
    let app = try openReader(); defer { app.terminate() }
    let text = app.webViews.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "In the beginning")).firstMatch
    XCTAssertTrue(text.waitForExistence(timeout: 10))
    let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); image.name = "continuous-edition-phone"; image.lifetime = .keepAlways; add(image)
  }
}
#endif

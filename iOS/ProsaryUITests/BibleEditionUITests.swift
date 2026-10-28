#if os(iOS)
import XCTest

final class BibleEditionUITests: XCTestCase {
  @MainActor func testEditionPagesStayLoadedAcrossBooksAndExposeTheLastPage() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
      "-readingsEditionId", "douay-rheims-1899", "-homeWidgetOrder", "scripture"]
    app.launch()
    defer { app.terminate() }
    let open = app.buttons["homeWidgets.open.scripture"]
    XCTAssertTrue(open.waitForExistence(timeout: 10)); open.tap()
    let count = app.staticTexts["bible.pageCount"]
    func numbers() -> [Int] {
      guard count.exists else { return [] }
      return count.label.replacingOccurrences(of: ",", with: "").split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }
    let prepared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      numbers().last.map { $0 > 500 } == true
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [prepared], timeout: 90), .completed)
    let initial = numbers()
    let total = try XCTUnwrap(initial.last)
    XCTAssertTrue(app.webViews.firstMatch.exists)
    XCTAssertFalse(app.progressIndicators["bible.preparingEdition"].exists)
    let text = app.webViews.firstMatch
    text.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    let hidden = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      !count.exists && !app.buttons["bible.bookMenu"].exists
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 10), .completed)
    let focused = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    focused.name = "bible-chrome-hidden"; focused.lifetime = .keepAlways; add(focused)
    text.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    XCTAssertTrue(count.waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["bible.bookMenu"].isHittable)
    let restored = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    restored.name = "bible-native-glass-restored"; restored.lifetime = .keepAlways; add(restored)
    // Reflow can change the edition's total when the bars reclaim their space.
    let restoredTotal = try XCTUnwrap(numbers().last)
    app.buttons["bible.nextPage"].tap()
    let advanced = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      numbers().first.map { $0 > 1 } == true
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 10), .completed)
    XCTAssertEqual(numbers().last, restoredTotal)
    XCTAssertFalse(app.progressIndicators["bible.preparingEdition"].exists)
    app.buttons["bible.bookMenu"].tap(); app.buttons["Exodus"].tap()
    XCTAssertTrue(app.navigationBars["Exodus"].waitForExistence(timeout: 10))
    XCTAssertEqual(numbers().last, total)
    XCTAssertGreaterThan(try XCTUnwrap(numbers().first), 10)
    app.buttons["bible.previousChapter"].tap()
    XCTAssertTrue(app.navigationBars["Genesis"].waitForExistence(timeout: 10))
    XCTAssertEqual(numbers().last, total)
    XCTAssertFalse(app.progressIndicators["bible.preparingEdition"].exists)
    app.buttons["bible.verseMenu"].tap(); app.buttons["3"].tap()
    XCTAssertEqual(numbers().last, total)
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = "whole-edition-pages-and-verse-lookup"; attachment.lifetime = .keepAlways; add(attachment)
    let slider = app.sliders["bible.pageSlider"]
    XCTAssertTrue(slider.exists); slider.adjust(toNormalizedSliderPosition: 1)
    let nearEnd = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      numbers().first.map { $0 > total * 95 / 100 } == true
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [nearEnd], timeout: 10), .completed, count.label)
    // XCTest's normalized slider drag can stop a few physical pixels short of the end.
    for _ in 0..<20 where app.buttons["bible.nextPage"].isEnabled {
      app.buttons["bible.nextPage"].tap()
    }
    let atEnd = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      numbers().first.map { $0 >= total - 1 } == true
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [atEnd], timeout: 10), .completed, count.label)
    XCTAssertFalse(app.buttons["bible.nextPage"].isEnabled)
    XCTAssertFalse(app.progressIndicators["bible.preparingEdition"].exists)
  }
}
#endif

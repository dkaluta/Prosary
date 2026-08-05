import XCTest
final class ZZShot: XCTestCase {
  func testShot() {
    let app = XCUIApplication()
    app.launch()
    _ = app.buttons["rosaryCard"].waitForExistence(timeout: 15)
    let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    a.name = "pray-favorites"; a.lifetime = .keepAlways; add(a)
  }
}

import XCTest
@testable import Prosary

final class HomeDashboardLayoutTests: XCTestCase {
  func testNarrowPanesKeepOneReadableColumn() {
    for width in [CGFloat(0), 280, 375, 430, 720] {
      XCTAssertEqual(HomeDashboardLayout.columnCount(availableWidth: width), 1)
    }
  }

  func testColumnsFollowAvailablePaneWidth() {
    XCTAssertEqual(HomeDashboardLayout.columnCount(availableWidth: 760), 2)
    XCTAssertEqual(HomeDashboardLayout.columnCount(availableWidth: 1024), 2)
    XCTAssertEqual(HomeDashboardLayout.columnCount(availableWidth: 1200), 3)
    XCTAssertEqual(HomeDashboardLayout.columnCount(availableWidth: 2000), 3)
    XCTAssertEqual(HomeDashboardLayout.columnCount(availableWidth: 1024 / 2), 1)
  }
}

import XCTest
@testable import Prosary

final class HomeWidgetOrderTests: XCTestCase {
  func testNewInstallAndIntentionallyEmptyHomeRemainDistinct() {
    XCTAssertEqual(HomeWidgetOrder.decode(nil), HomeWidgetOrder.defaults)
    XCTAssertEqual(HomeWidgetOrder.decode(""), [])
  }

  func testRestoredLayoutPreservesOrderAndDiscardsUnknownDuplicates() {
    XCTAssertEqual(HomeWidgetOrder.decode("photo\nunknown\nreadings\nphoto\nreflection"),
                   [.photo, .readings, .reflection])
    XCTAssertEqual(HomeWidgetOrder.decode(HomeWidgetOrder.encode([.feast, .photo, .feast])), [.feast, .photo])
  }

  func testPhotoCleanupCannotDeleteFilesOutsidePrivatePhotoDirectory() {
    XCTAssertNil(HomePhotoStore.ownedURL("/private/tmp/unrelated.jpg"))
    XCTAssertNil(HomePhotoStore.ownedURL(HomePhotoStore.directory.appendingPathComponent("../unrelated.jpg").path))
    XCTAssertNotNil(HomePhotoStore.ownedURL(HomePhotoStore.directory.appendingPathComponent("chosen.jpg").path))
  }
}

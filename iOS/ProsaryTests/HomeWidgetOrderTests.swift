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

  func testDailyCardMigrationPreservesEmptyAndExistingCardsWithoutDuplicates() {
    XCTAssertEqual(HomeWidgetOrder.addingDailyCards(to: []), [])
    XCTAssertEqual(HomeWidgetOrder.addingDailyCards(to: [.photo, .readings, .feast]),
                   [.photo, .readings, .torah, .feast, .reflection])
    let migrated = HomeWidgetOrder.addingDailyCards(to: [.reflection, .torah, .photo])
    XCTAssertEqual(migrated, [.reflection, .torah, .photo])
    XCTAssertEqual(HomeWidgetOrder.addingDailyCards(to: migrated), migrated)
  }

  func testPhotoCleanupCannotDeleteFilesOutsidePrivatePhotoDirectory() {
    XCTAssertNil(HomePhotoStore.ownedURL("/private/tmp/unrelated.jpg"))
    XCTAssertNil(HomePhotoStore.ownedURL(HomePhotoStore.directory.appendingPathComponent("../unrelated.jpg").path))
    XCTAssertNotNil(HomePhotoStore.ownedURL(HomePhotoStore.directory.appendingPathComponent("chosen.jpg").path))
  }

  func testCardColorsNormalizeUnknownValuesAndDefaultResetsOnlyOneCard() {
    XCTAssertTrue(HomeWidgetDisplay.colors("bad json").isEmpty)
    XCTAssertTrue(HomeWidgetDisplay.colors("null").isEmpty)
    var colors = HomeWidgetDisplay.colors(#"{"readings":"blue","feast":"rose","photo":"default","torah":"purple","unknown":"green"}"#)
    XCTAssertEqual(colors, [.readings: .blue, .feast: .rose])
    colors[.readings] = .default
    let stored = HomeWidgetDisplay.encodeColors(colors)
    XCTAssertEqual(HomeWidgetDisplay.colors(stored), [.feast: .rose])
    XCTAssertEqual(stored, #"{"feast":"rose"}"#)
    XCTAssertEqual(HomeWidgetDisplay.encodeColors([.torah: .gold, .feast: .green]), #"{"feast":"green","torah":"gold"}"#)
  }
}

import XCTest
@testable import Prosary

final class CustomDevotionLaunchTests: XCTestCase {
  func testLitanyEndingFollowsEntryContextEvenWhenFavoriteSavedTheOtherForm() {
    XCTAssertEqual(CustomDevotionLaunch.variantId(
      devotionId: "litanyOfLoreto", incoming: nil, saved: "afterRosary"), "standard")
    XCTAssertEqual(CustomDevotionLaunch.variantId(
      devotionId: "litanyOfLoreto", incoming: "afterRosary", saved: "standard"), "afterRosary")
    XCTAssertFalse(CustomDevotionLaunch.allowsVariantChoice("litanyOfLoreto"))
  }

  func testOtherDevotionsRetainTheirSavedAndExplicitForms() {
    XCTAssertEqual(CustomDevotionLaunch.variantId(
      devotionId: "stationsOfTheCross", incoming: nil, saved: "scriptural"), "scriptural")
    XCTAssertEqual(CustomDevotionLaunch.variantId(
      devotionId: "stationsOfTheCross", incoming: "traditional", saved: "scriptural"), "traditional")
    XCTAssertTrue(CustomDevotionLaunch.allowsVariantChoice("stationsOfTheCross"))
  }
}

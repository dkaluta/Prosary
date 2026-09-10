import XCTest
@testable import Prosary

@MainActor
final class CustomDevotionOptionTests: XCTestCase {
  func testLegacyRosaryRowsBecomeOneToggleAtTheFirstLegacyPosition() throws {
    let options = [toggle("antiphon"), toggle("closingPopeIntention"),
                   toggle("closingBishopIntention", defaultValue: "true"),
                   toggle("closingDepartedIntention"), toggle("stMichael")]
    let result = CustomDevotionOption.normalizedForEditing(options, bundleId: "rosary")
    XCTAssertEqual(result.map(\.key), ["antiphon", "closingIntentions", "stMichael"])
    let combined = try XCTUnwrap(result.first { $0.key == "closingIntentions" })
    XCTAssertEqual(combined.kind.rawValue, "toggle")
    XCTAssertEqual(combined.defaultValue, "true", "Any enabled old default enables the combined group")
    XCTAssertEqual(combined.localizedName,
      UILanguage.text("favoriteEditor.closingIntentions", language: UILanguage.current,
                      fallback: "Closing Intentions"))
    XCTAssertEqual(options.count, 5, "The source pack's option declaration is unchanged")
  }

  func testExistingCombinedOptionKeepsItsAuthoredPositionAndMetadata() {
    let combined = CustomDevotionOption(key: "closingIntentions", kind: .toggle,
      name: "Authored label", nameByLanguage: ["he": "כותרת"], defaultValue: "false")
    let options = [toggle("closingPopeIntention", defaultValue: "true"), toggle("antiphon"),
                   combined, toggle("closingDepartedIntention"), toggle("stMichael")]
    let result = CustomDevotionOption.normalizedForEditing(options, bundleId: "rosary")
    XCTAssertEqual(result.map(\.key), ["antiphon", "closingIntentions", "stMichael"])
    XCTAssertEqual(result[1].name, combined.name)
    XCTAssertEqual(result[1].nameByLanguage, combined.nameByLanguage)
    XCTAssertEqual(result[1].defaultValue, "false")
    XCTAssertEqual(CustomDevotionOption.normalizedForEditing(result, bundleId: "rosary").map(\.key),
                   result.map(\.key), "A current pack is already normalized")
  }

  func testOtherPacksAndRosariesWithoutLegacyRowsKeepTheirOptions() {
    let foreign = [toggle("closingPopeIntention"), toggle("closingBishopIntention")]
    XCTAssertEqual(CustomDevotionOption.normalizedForEditing(foreign, bundleId: "customRosary").map(\.key),
                   foreign.map(\.key))
    let current = [toggle("antiphon"), toggle("closingIntentions"), toggle("stMichael")]
    XCTAssertEqual(CustomDevotionOption.normalizedForEditing(current, bundleId: "rosary").map(\.key),
                   current.map(\.key))
    XCTAssertTrue(CustomDevotionOption.normalizedForEditing([], bundleId: "rosary").isEmpty)
  }

  private func toggle(_ key: String, defaultValue: String = "false") -> CustomDevotionOption {
    CustomDevotionOption(key: key, kind: .toggle, name: key, defaultValue: defaultValue)
  }
}

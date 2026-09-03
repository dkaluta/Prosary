//
//  HebrewDisplayTextTests.swift
//  ProsaryTests
//

import XCTest
@testable import Prosary

final class HebrewDisplayTextTests: XCTestCase {
  func testUnpointedRemovesNiqqudAndCantillationButKeepsHebrewPunctuation() {
    XCTAssertEqual(
      HebrewDisplayText.unpointed("שָׁל֖וֹם־יְרוּשָׁלַיִם׃"),
      "שלום־ירושלים׃")
  }

  func testUnpointedDoesNotRemoveMarksFromOtherScripts() {
    XCTAssertEqual(HebrewDisplayText.unpointed("ܫܠܳܡ — café"), "ܫܠܳܡ — café")
  }

  func testRosaryStepStripsOnlyItsDisplayHeadings() {
    let step = RosaryStep(
      title: "שִׂמְחִי מִרְיָם",
      subtitle: "לְגִדּוּל הָאֱמוּנָה",
      body: "שִׂמְחִי מִרְיָם",
      acclamation: "קָדוֹשׁ")

    XCTAssertEqual(step.title, "שמחי מרים")
    XCTAssertEqual(step.subtitle, "לגדול האמונה")
    XCTAssertEqual(step.body, "שִׂמְחִי מִרְיָם")
    XCTAssertEqual(step.acclamation, "קָדוֹשׁ")
  }

  func testHardcodedHebrewMysteryCitationUsesGematriaChapterWithoutColon() {
    let description = MysteryTranslations.hebrew["luminous_02_wedding_at_cana"]?.description
    XCTAssertTrue(description?.contains("— יוחנן ב׳ 7–11 (דליטש)") == true)
    XCTAssertFalse(description?.contains("יוחנן ב׳:") == true)
  }

  func testEveryHardcodedMysteryCitationUsesEnDashesForVerseRanges() {
    for (languageCode, mysteries) in MysteryTranslations.byLanguage {
      for (imageKey, mystery) in mysteries {
        XCTAssertNil(
          mystery.description.range(of: #"\d-\d"#, options: .regularExpression),
          "ASCII verse-range hyphen in \(languageCode)/\(imageKey)")
      }
    }
  }
}

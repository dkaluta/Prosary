import Foundation
import XCTest
@testable import Prosary

@MainActor
final class FeastSaintDescriptionTests: XCTestCase {
  private func fixture() throws -> FeastDay {
    // Synthetic prose is deliberately unrelated to devotional content.
    let data = Data(#"""
      {"title":"Fixture feast","rank":"Feast","observances":[
        {"title":"Fixture saint","identity":"fixture",
         "titleByLanguage":{"he":"שם לדוגמה","ar":"اسم تجريبي","tl":"Halimbawang pangalan"},
         "descriptionByLanguage":{"he":"פסקה לדוגמה.\n\nפסקה נוספת.","ar":"نص تجريبي.","tl":"Halimbawang teksto.","fr":"   "},
         "descriptionSourceByLanguage":{"he":"https://example.org/he","ar":"https://example.org/ar","tl":"javascript:alert(1)"},
         "descriptionCreditByLanguage":{"he":"קרדיט לדוגמה","ar":"مصدر تجريبي"}},
        {"title":"No description","identity":"no-prose"}
      ]}
      """#.utf8)
    return try JSONDecoder().decode(FeastDay.self, from: data)
  }

  func testDescriptionsRequireTheSelectedLanguageInEverySelectedCalendar() throws {
    let feast = try fixture()
    let rows = feast.saintDescriptions(calendarID: "syriac", language: "iw-IL")
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows.first?.title, "שם לדוגמה")
    XCTAssertEqual(rows.first?.text, "פסקה לדוגמה.\n\nפסקה נוספת.")
    XCTAssertEqual(rows.first?.sourceURL?.absoluteString, "https://example.org/he")
    XCTAssertEqual(rows.first?.credit, "קרדיט לדוגמה")
    XCTAssertEqual(feast.saintDescriptions(calendarID: "syriac", language: "ar-EG").first?.text, "نص تجريبي.")
    for language in ["en", "fr", "ru", "it", "uk"] {
      XCTAssertTrue(feast.saintDescriptions(calendarID: "syriac", language: language).isEmpty,
                    "Missing or blank \(language) prose must never fall back to another language")
    }
    for calendar in ["lpj", "roman", "roman1962", "ugcc", "maronite", ""] {
      XCTAssertEqual(feast.saintDescriptions(calendarID: calendar, language: "he").first?.text,
        "פסקה לדוגמה.\n\nפסקה נוספת.", "Calendar-scoped source data must remain visible")
    }
  }

  func testSourceAndCreditDoNotBorrowAnotherLanguageAndUnsafeLinksAreOmitted() throws {
    let row = try XCTUnwrap(fixture().saintDescriptions(calendarID: "syriac", language: "fil-PH").first)
    XCTAssertEqual(row.title, "Halimbawang pangalan")
    XCTAssertEqual(row.text, "Halimbawang teksto.")
    XCTAssertNil(row.credit)
    XCTAssertNil(row.sourceURL)
  }

  func testExistingFeastPayloadsStillDecodeWithoutObservances() throws {
    let feast = try JSONDecoder().decode(FeastDay.self, from: Data(#"{"title":"Existing fixture","rank":"Feast"}"#.utf8))
    XCTAssertNil(feast.observances)
    XCTAssertEqual(feast.localizedTitle("he"), "Existing fixture")
    XCTAssertTrue(feast.saintDescriptions(calendarID: "syriac", language: "he").isEmpty)
  }

  func testDescriptionDoesNotRepeatTheParentTitleWithWhitespaceOrHebrewPoints() {
    let description = FeastSaintDescription(title: "  שֵׁם\u{00a0}לְדוּגְמָה\n", text: "Fixture prose",
                                           sourceURL: nil, credit: nil)
    XCTAssertFalse(description.showsTitle(beneath: "שם לדוגמה"))
    XCTAssertFalse(FeastSaintDescription(title: "Fixture   feast", text: "Fixture prose", sourceURL: nil, credit: nil)
      .showsTitle(beneath: "Fixture feast"))
  }

  func testDistinctObservanceHeadingsRemainVisible() {
    let description = FeastSaintDescription(title: "Fixture saint", text: "Fixture prose",
                                           sourceURL: nil, credit: nil)
    XCTAssertTrue(description.showsTitle(beneath: "Fixture feast; Fixture saint"))
    XCTAssertTrue(description.showsTitle(beneath: "Fixture feast"))
  }

  private func sectionFixture(_ sections: [[String: Any]], descriptions: [String: String] = [:],
                              reflections: [String: String] = [:]) throws -> FeastDay {
    let payload: [String: Any] = ["title": "Fixture feast", "rank": "Feast", "observances": [[
      "title": "Fixture observance", "identity": "fixture", "sections": sections,
      "descriptionByLanguage": descriptions, "reflectionByLanguage": reflections
    ]]]
    return try JSONDecoder().decode(FeastDay.self, from: JSONSerialization.data(withJSONObject: payload))
  }

  func testEachCalendarKeepsItsOwnSectionIDsTitlesAndOrder() throws {
    for (calendar, ids) in [("roman", ["history", "local-custom"]),
                            ("syriac", ["psalmody", "procession", "commemoration"])] {
      let sections = ids.map { id -> [String: Any] in
        ["id": id, "titleByLanguage": ["en": "Fixture \(id)"],
         "textByLanguage": ["en": "First \(id) paragraph.\n\nSecond \(id) paragraph."]]
      }
      let fullText = ids.map { "Fixture \($0):\nFirst \($0) paragraph.\n\nSecond \($0) paragraph." }.joined(separator: "\n\n")
      let row = try XCTUnwrap(sectionFixture(sections, descriptions: ["en": fullText])
        .saintDescriptions(calendarID: calendar, language: "en").first)
      XCTAssertEqual(row.sections.map(\.id), ids)
      XCTAssertEqual(row.sections.map(\.title), ids.map { "Fixture \($0)" })
      XCTAssertEqual(row.sections.first?.text, "First \(ids[0]) paragraph.\n\nSecond \(ids[0]) paragraph.")
      XCTAssertEqual(row.text, fullText)
    }
  }

  func testSectionsUseExactLocaleWithHebrewAndFilipinoAliases() throws {
    let feast = try sectionFixture([
      ["id": "custom-section", "titleByLanguage": ["he": "כותרת לדוגמה", "tl": "Halimbawang pamagat"],
       "textByLanguage": ["he": "פסקה לדוגמה.", "tl": "Halimbawang teksto."]]
    ])
    XCTAssertEqual(feast.saintDescriptions(calendarID: "syriac", language: "iw-IL").first?.sections.first?.title,
      "כותרת לדוגמה")
    XCTAssertEqual(feast.saintDescriptions(calendarID: "roman", language: "fil-PH").first?.sections.first?.text,
      "Halimbawang teksto.")
    XCTAssertTrue(feast.saintDescriptions(calendarID: "roman", language: "en").isEmpty)
  }

  func testPartialOrForeignSectionsKeepTheCompleteProse() throws {
    let fullText = "First section:\nFirst paragraph.\n\nSecond section:\nSecond paragraph."
    let feast = try sectionFixture([
      ["id": "first", "titleByLanguage": ["en": "First section"], "textByLanguage": ["en": "First paragraph."]],
      ["id": "second", "titleByLanguage": ["fr": "Deuxième section"], "textByLanguage": ["en": "Second paragraph."]]
    ], descriptions: ["en": fullText, "he": "פסקה מלאה לדוגמה."])
    let english = try XCTUnwrap(feast.saintDescriptions(calendarID: "roman", language: "en").first)
    XCTAssertEqual(english.text, fullText)
    XCTAssertTrue(english.sections.isEmpty)
    let hebrew = try XCTUnwrap(feast.saintDescriptions(calendarID: "syriac", language: "iw").first)
    XCTAssertEqual(hebrew.text, "פסקה מלאה לדוגמה.")
    XCTAssertTrue(hebrew.sections.isEmpty)
  }

  func testSectionComparisonIgnoresWhitespaceAndReflectionsRemainIndependent() throws {
    let feast = try sectionFixture([
      ["id": "local", "titleByLanguage": ["en": "Fixture heading"], "textByLanguage": ["en": "Fixture paragraph."]]
    ], descriptions: ["en": "Fixture heading:\r\n\r\nFixture   paragraph."], reflections: ["en": "Fixture reflection."])
    XCTAssertEqual(feast.saintDescriptions(calendarID: "roman", language: "en").first?.sections.count, 1)
    let reflection = try XCTUnwrap(feast.reflections(language: "en").first)
    XCTAssertEqual(reflection.text, "Fixture reflection.")
    XCTAssertTrue(reflection.sections.isEmpty)
  }
}

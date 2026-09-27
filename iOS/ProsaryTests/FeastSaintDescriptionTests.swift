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

  func testDescriptionsRequireTheSelectedLanguageAndSyriacCalendar() throws {
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
      XCTAssertTrue(feast.saintDescriptions(calendarID: calendar, language: "he").isEmpty)
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
}

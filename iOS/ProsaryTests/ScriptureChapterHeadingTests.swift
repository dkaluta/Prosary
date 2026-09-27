import XCTest
@testable import Prosary

@MainActor
final class ScriptureChapterHeadingTests: XCTestCase {
  private func edition(_ language: String) -> ReadingTextEdition {
    ReadingTextEdition(id: language, languageCode: language, name: "Fixture \(language)",
                       attribution: "Synthetic fixture", sourceURL: "https://example.org")
  }

  func testHebrewChapterNumbersUseTraditionalPunctuationAndAvoidSacredNameForms() {
    for (value, expected) in [(1, "א׳"), (10, "י׳"), (15, "ט״ו"), (16, "ט״ז"),
                              (99, "צ״ט"), (100, "ק׳"), (115, "קט״ו"), (116, "קט״ז"),
                              (150, "ק״נ"), (151, "קנ״א")] {
      XCTAssertEqual(ScriptureChapterHeading.number(value, language: "he"), expected)
      XCTAssertEqual(ScriptureChapterHeading.number(value, language: "iw-IL"), expected)
    }
  }

  func testChapterWordAndNumberFollowTheSelectedBibleRatherThanTheInterface() throws {
    let editions = [edition("en"), edition("he"), edition("ar"), edition("el")]
    let hebrew = try XCTUnwrap(ReadingEditionSelection.selected("he", interfaceLanguage: "en", editions: editions))
    XCTAssertEqual(ScriptureChapterHeading(chapter: 15, edition: hebrew, script: "Hebr").text, "פרק ט״ו")
    let english = try XCTUnwrap(ReadingEditionSelection.selected("en", interfaceLanguage: "he", editions: editions))
    XCTAssertEqual(ScriptureChapterHeading(chapter: 15, edition: english, script: "Hebr").text, "Chapter 15")
    let arabic = try XCTUnwrap(ReadingEditionSelection.selected("ar", interfaceLanguage: "en", editions: editions))
    XCTAssertEqual(ScriptureChapterHeading(chapter: 115, edition: arabic, script: "Hebr").text, "الفصل ١١٥")
    let greek = try XCTUnwrap(ReadingEditionSelection.selected("el", interfaceLanguage: "he", editions: editions))
    XCTAssertEqual(ScriptureChapterHeading(chapter: 15, edition: greek, script: "Hebr").text, "Κεφάλαιο 15")
  }

  func testAramaicHeadingFollowsThePassageScript() {
    let aramaic = edition("arc")
    XCTAssertEqual(ScriptureChapterHeading(chapter: 15, edition: aramaic, script: "Hebr").text, "קפלאון ט״ו")
    XCTAssertEqual(ScriptureChapterHeading(chapter: 1, edition: aramaic, script: "Syrc").text, "ܩܦܠܐܘܢ ܐ")
    XCTAssertEqual(ScriptureChapterHeading(chapter: 15, edition: aramaic, script: "Syrc").text, "ܩܦܠܐܘܢ ܝܗ")
    XCTAssertEqual(ScriptureChapterHeading(chapter: 16, edition: aramaic, script: "Syrc").number, "ܝܘ")
    XCTAssertEqual(ScriptureChapterHeading(chapter: 150, edition: aramaic, script: "Syrc").number, "ܩܢ")
  }

  func testDecimalBibleLanguagesRetainTheirOwnChapterLabel() {
    for (language, expected) in [("fr", "Chapitre"), ("it", "Capitolo"), ("ru", "Глава"),
                                  ("uk", "Розділ"), ("tl", "Kabanata")] {
      XCTAssertEqual(ScriptureChapterHeading(chapter: 115, edition: edition(language), script: "Hebr").text,
                     "\(expected) 115")
    }
  }
}

import XCTest
@testable import Prosary

final class ReadingTextStoreTests: XCTestCase {
  private let english = ReadingTextEdition(id: "english", languageCode: "en", name: "English fixture",
    attribution: "Synthetic test data", sourceURL: "https://example.com/english")
  private let hebrew = ReadingTextEdition(id: "hebrew", languageCode: "he", name: "Hebrew fixture",
    attribution: "Synthetic test data", sourceURL: "https://example.com/hebrew")

  func testSelectionOnlyUsesMatchingInterfaceLanguageOrExplicitEdition() {
    let editions = [english, hebrew]
    XCTAssertEqual(ReadingEditionSelection.selected("", interfaceLanguage: "iw-IL", editions: editions), hebrew)
    XCTAssertEqual(ReadingEditionSelection.selected("", interfaceLanguage: "en_US", editions: editions), english)
    XCTAssertNil(ReadingEditionSelection.selected("", interfaceLanguage: "ar", editions: editions))
    XCTAssertNil(ReadingEditionSelection.selected("removed", interfaceLanguage: "en", editions: editions))
    XCTAssertEqual(ReadingEditionSelection.selected("english", interfaceLanguage: "he", editions: editions), english)
  }

  func testPassageLookupKeepsCitationContextAndEditionExact() {
    let verse = ReadingTextVerse(chapter: 1, verse: 1, text: "Synthetic fixture text")
    let data = ReadingTextDataset(schemaVersion: 1, editions: [english, hebrew],
      passages: ["daily|Genesis 1:1": ["english": [verse]], "torah|Genesis 1:1": ["hebrew": [verse]]])
    XCTAssertEqual(data.passage(citation: "Genesis 1:1", isTorah: false, editionID: "english")?.verses, [verse])
    XCTAssertEqual(data.passage(citation: "Genesis 1:1", isTorah: false, editionID: "english")?.includesWholeVerses, false)
    XCTAssertNil(data.passage(citation: "Genesis 1:1", isTorah: false, editionID: "hebrew"))
    XCTAssertNil(data.passage(citation: "Genesis 1:1", isTorah: true, editionID: "english"))
    XCTAssertNil(data.passage(citation: "Gen. 1:1", isTorah: false, editionID: "english"))
    XCTAssertNotNil(data.passage(citation: "Genesis 1:1", isTorah: true, editionID: "hebrew"))
  }

  func testWholeVerseMetadataDecodesAndKeepsOriginalCitationAndContext() throws {
    let payload = #"{"schemaVersion":1,"editions":[{"id":"fixture","languageCode":"en","name":"Fixture","attribution":"Fixture","sourceURL":"https://example.com"}],"passages":{"daily|John 3:16a":{"fixture":[{"chapter":3,"verse":16,"text":"Whole fixture verse"}]},"torah|John 3:16a":{"fixture":[{"chapter":3,"verse":16,"text":"Context fixture"}]}},"wholeVersePassages":["daily|John 3:16a"]}"#
    let data = try JSONDecoder().decode(ReadingTextDataset.self, from: Data(payload.utf8))
    XCTAssertEqual(data.passage(citation: "John 3:16a", isTorah: false, editionID: "fixture")?.includesWholeVerses, true)
    XCTAssertEqual(data.passage(citation: "John 3:16a", isTorah: true, editionID: "fixture")?.includesWholeVerses, false)
    XCTAssertNil(data.passage(citation: "John 3:16", isTorah: false, editionID: "fixture"))
    XCTAssertNil(data.passage(citation: "John 3:16a", isTorah: false, editionID: "missing"))
  }

  func testBundledSeptember10FirstReadingAndPsalmShowWholeVerses() async throws {
    let store = ReadingTextStore()
    let firstResult = await store.passage(citation: "1 Corinthians 8:1b–7; 8:11–13", isTorah: false, editionID: "douay-rheims-1899")
    let first = try XCTUnwrap(firstResult)
    XCTAssertTrue(first.includesWholeVerses)
    XCTAssertEqual(first.verses.map(\.verse), [1, 2, 3, 4, 5, 6, 7, 11, 12, 13])
    XCTAssertTrue(first.verses.allSatisfy { $0.chapter == 8 })
    let psalmResult = await store.passage(citation: "Psalm 139:1–3; 139:13–14ab; 139:23–24", isTorah: false, editionID: "douay-rheims-1899")
    let psalm = try XCTUnwrap(psalmResult)
    XCTAssertTrue(psalm.includesWholeVerses)
    // DRA verse 4 includes the end of the appointed Hebrew-numbered verse 3.
    XCTAssertEqual(psalm.verses.map(\.verse), [1, 2, 3, 4, 13, 14, 23, 24])
    XCTAssertTrue(psalm.verses.allSatisfy { $0.chapter == 138 })
    let gospel = await store.passage(citation: "Luke 6:27–38", isTorah: false, editionID: "douay-rheims-1899")
    XCTAssertEqual(gospel?.includesWholeVerses, false)
    XCTAssertEqual(gospel?.verses.count, 12)
  }

  func testMalformedVersionAndEmptyVersesAreUnavailable() {
    for (version, verses) in [(2, [ReadingTextVerse(chapter: 1, verse: 1, text: "Fixture")]),
                              (1, []), (1, [ReadingTextVerse(chapter: 0, verse: 1, text: "Fixture")]),
                              (1, [ReadingTextVerse(chapter: 1, verse: 1, text: "  ")])] {
      let data = ReadingTextDataset(schemaVersion: version, editions: [english],
                                   passages: ["daily|Genesis 1:1": ["english": verses]])
      XCTAssertNil(data.passage(citation: "Genesis 1:1", isTorah: false, editionID: "english"))
    }
  }

  func testReadingMetadataDoesNotLoadPassageCorpus() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let metadata = directory.appendingPathComponent("editions.json")
    let corpus = directory.appendingPathComponent("texts.json")
    let edition = #"{"id":"fixture","languageCode":"en","name":"Fixture","attribution":"Synthetic test data","sourceURL":"https://example.com"}"#
    try Data("{\"schemaVersion\":1,\"editions\":[\(edition)]}".utf8).write(to: metadata)
    let store = ReadingTextStore(resourceURL: corpus, editionsURL: metadata)
    let editions = await store.editions()
    XCTAssertEqual(editions.count, 1)
    // The text resource arrives after listing metadata. Eager text loading would cache a failure.
    let text = "{\"schemaVersion\":1,\"editions\":[\(edition)],\"passages\":{\"daily|Fixture 1:1\":{\"fixture\":[{\"chapter\":1,\"verse\":1,\"text\":\"Synthetic fixture text\"}]}}}"
    try Data(text.utf8).write(to: corpus)
    let result = await store.passage(citation: "Fixture 1:1", isTorah: false, editionID: "fixture")
    XCTAssertEqual(result?.verses.first?.text, "Synthetic fixture text")
  }

  func testBundledSourceFilesResolveAllEditionsAndPreserveHebrewCantillation() async throws {
    XCTAssertNotNil(Bundle.main.url(forResource: "readings-editions", withExtension: "json"))
    XCTAssertNotNil(Bundle.main.url(forResource: "readings-texts", withExtension: "json"))
    let store = ReadingTextStore()
    let editions = await store.editions()
    XCTAssertEqual(editions.map(\.languageCode).sorted(), ["ar", "en", "fr", "he", "it", "ru", "tl", "uk"])
    // The reviewed Arabic source is a limited corpus; keep complete Luke 6
    // coverage assertions for each of the seven full Bible editions.
    for edition in editions where edition.languageCode != "ar" {
      let daily = await store.passage(citation: "Luke 6:27–38", isTorah: false, editionID: edition.id)
      XCTAssertEqual(daily?.verses.count, 12, edition.id)
      XCTAssertEqual(daily?.verses.first?.verse, 27, edition.id)
      XCTAssertEqual(daily?.verses.last?.verse, 38, edition.id)
    }
    let selected = try XCTUnwrap(ReadingEditionSelection.selected("", interfaceLanguage: "he", editions: editions))
    let loaded = await store.passage(citation: "Genesis 47:28–50:26", isTorah: true, editionID: selected.id)
    let torah = try XCTUnwrap(loaded)
    XCTAssertEqual(torah.verses.count, 85)
    XCTAssertEqual(torah.verses.first?.chapter, 47)
    XCTAssertEqual(torah.verses.last?.chapter, 50)
    XCTAssertTrue(torah.verses.contains { verse in
      verse.text.unicodeScalars.contains { (0x0591...0x05AF).contains($0.value) }
    }, "The native reader must retain the source cantillation")
    XCTAssertNotNil(torah.edition.sourceLink)
  }

  func testBundledOldJesuitArabicOpensReviewedPassagesWithoutBorrowingMissingText() async throws {
    let store = ReadingTextStore()
    let editions = await store.editions()
    let edition = try XCTUnwrap(ReadingEditionSelection.selected("", interfaceLanguage: "ar-LB", editions: editions))
    XCTAssertEqual(edition.id, "jesuit-arabic-1897")
    XCTAssertTrue(edition.name.contains("1897"))
    XCTAssertFalse(edition.attribution.isEmpty)
    XCTAssertNotNil(edition.sourceLink)

    let loaded = await store.passage(citation: "Luke 1:26–38", isTorah: false, editionID: edition.id)
    let passage = try XCTUnwrap(loaded)
    XCTAssertEqual(passage.edition, edition)
    XCTAssertEqual(passage.verses.map(\.verse), Array(26...38))
    XCTAssertTrue(passage.verses.allSatisfy { $0.chapter == 1 })
    XCTAssertEqual(passage.verses.last?.text,
      "فقالت مريم هاءنذا أمة الرب فليكن لي بحسب قولك. وانصرف الملاك من عندها.")

    let missingDaily = await store.passage(citation: "Luke 6:27–38", isTorah: false, editionID: edition.id)
    let missingTorah = await store.passage(citation: "Genesis 47:28–50:26", isTorah: true, editionID: edition.id)
    XCTAssertNil(missingDaily)
    XCTAssertNil(missingTorah)
  }

  func testBundledHebrewNewTestamentKeepsPublishedVowelsExceptTheDivineName() async throws {
    let store = ReadingTextStore()
    for citation in ["Luke 6:27–38", "1 Corinthians 8:1b–7; 8:11–13", "Luke 1:26–38"] {
      let result = await store.passage(citation: citation, isTorah: false, editionID: "masoretic-delitzsch")
      let passage = try XCTUnwrap(result)
      XCTAssertTrue(passage.verses.allSatisfy { verse in
        verse.text.unicodeScalars.contains { (0x05B0...0x05BB).contains($0.value) || $0.value == 0x05C7 }
      }, citation)
      XCTAssertTrue(passage.edition.attribution.contains("1901"))
      XCTAssertTrue(passage.edition.attribution.contains("delitz.fr"))
      XCTAssertFalse(passage.edition.attribution.contains("ללא ניקוד"))
      XCTAssertEqual(passage.edition.sourceURL, "https://delitz.fr/12/")
    }
    let announcement = await store.passage(citation: "Luke 1:26–38", isTorah: false, editionID: "masoretic-delitzsch")
    let text = try XCTUnwrap(announcement).verses.map(\.text).joined(separator: " ")
    let marks = "[\\u0591-\\u05BD\\u05BF\\u05C1\\u05C2\\u05C4\\u05C5\\u05C7]*"
    let name = try NSRegularExpression(pattern: "י\(marks)ה\(marks)ו\(marks)ה\(marks)")
    let matches = name.matches(in: text, range: NSRange(text.startIndex..., in: text))
    XCTAssertFalse(matches.isEmpty)
    for match in matches {
      let word = (text as NSString).substring(with: match.range)
      XCTAssertFalse(word.unicodeScalars.contains { (0x05B0...0x05BC).contains($0.value) || $0.value == 0x05C7 })
    }
  }
}

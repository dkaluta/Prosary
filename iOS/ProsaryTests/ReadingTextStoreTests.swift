import XCTest
@testable import Prosary

final class ReadingTextStoreTests: XCTestCase {
  private let english = ReadingTextEdition(id: "english", languageCode: "en", name: "English fixture",
    attribution: "Synthetic test data", sourceURL: "https://example.com/english")
  private let hebrew = ReadingTextEdition(id: "hebrew", languageCode: "he", name: "Hebrew fixture",
    attribution: "Synthetic test data", sourceURL: "https://example.com/hebrew")

  private func sourceFixture(verses: [[String: Any]]? = nil, blocks: Any? = nil,
                             sourceChanges: [String: Any] = [:]) -> [String: Any] {
    var source: [String: Any] = ["book":"SUS", "name":"סיפור מקור", "attribution":"Credited Hebrew translator",
      "sourceURL":"https://example.org/hebrew-scan#page=12", "isComplete":true,
      "contentBlocks":blocks ?? [["id":"first", "kind":"verse", "chapter":1, "verse":1]]]
    source.merge(sourceChanges) { _, new in new }
    return ["schemaVersion":1,
      "editions":[["id":"fixture", "languageCode":"he", "name":"Selected Bible", "attribution":"Base Bible credit", "sourceURL":"https://example.org/base"]],
      "passages":["daily|Daniel 13:1":["fixture":verses ?? [["chapter":1, "verse":1, "text":"טקסט מקור"]]]],
      "passageSources":["daily|Daniel 13:1":["fixture":source]]]
  }

  private func sourceDataset(_ object: [String: Any]) throws -> ReadingTextDataset {
    try JSONDecoder().decode(ReadingTextDataset.self, from: JSONSerialization.data(withJSONObject: object))
  }

  private func sourcePassage(_ object: [String: Any]) throws -> ReadingTextPassage? {
    try sourceDataset(object).passage(citation: "Daniel 13:1", isTorah: false, editionID: "fixture")
  }

  func testReviewedSourceRedirectKeepsItsOwnNameCreditAndPartialNotice() throws {
    var fixture = sourceFixture(verses: [["chapter":1, "verse":1, "endVerse":3, "text":"טקסט מקור"]],
      sourceChanges: ["isComplete":false])
    fixture["wholeVersePassages"] = ["daily|Daniel 13:1"]
    let passage = try XCTUnwrap(sourcePassage(fixture))
    XCTAssertEqual(passage.edition.name, "Selected Bible")
    XCTAssertEqual(passage.source?.book, "SUS", "A Daniel appointment can have a separately credited Hebrew source")
    XCTAssertEqual(passage.source?.name, "סיפור מקור")
    XCTAssertEqual(passage.source?.attribution, "Credited Hebrew translator")
    XCTAssertEqual(passage.source?.sourceLink?.fragment, "page=12")
    XCTAssertEqual(passage.source?.isComplete, false)
    XCTAssertTrue(passage.includesWholeVerses)
    XCTAssertEqual(passage.sourceDisplays?.first?.blocks.first?.unit?.verseLabel, "1–3")
    XCTAssertNil(try sourceDataset(fixture).passage(citation: "Susanna 1:1", isTorah: false, editionID: "fixture"))
    XCTAssertNil(try sourceDataset(fixture).passage(citation: "Daniel 13:1", isTorah: true, editionID: "fixture"))
  }

  func testReviewedSourcePreservesReorderedChaptersWitnessesAndExactNotes() throws {
    let restored: [String: Any] = ["id":"restored-letter", "kind":"restoredLetter", "anchor":"כָּלְתָה", "occurrence":1,
      "letterIndex":2, "mark":"consonant", "sourcePages":[12], "sourceURL":"https://example.org/source#page=12"]
    let uncertain: [String: Any] = ["id":"witness-point", "kind":"unreadablePoint", "anchor":"ש", "occurrence":1,
      "letterIndex":1, "mark":"vowel", "sourcePages":[13], "sourceURL":"https://example.org/source#page=13"]
    let verses: [[String: Any]] = [["chapter":2, "verse":4, "text":"כָּלְתָה", "sourceNotes":[restored]],
      ["chapter":1, "verse":8, "endVerse":9, "text":"שני"], ["chapter":2, "verse":1, "text":"שלישי"]]
    let blocks: [[String: Any]] = [["id":"first", "kind":"verse", "chapter":2, "verse":4, "printedLabel":"ד"],
      ["id":"witness", "kind":"witness", "text":"ש", "printedLabel":"עדות", "addresses":[["chapter":2,"verse":4]], "sourceNotes":[uncertain]],
      ["id":"second", "kind":"verse", "chapter":1, "verse":8],
      ["id":"extra", "kind":"passage", "text":"מזמור נוסף"], ["id":"third", "kind":"verse", "chapter":2, "verse":1]]
    let passage = try XCTUnwrap(sourcePassage(sourceFixture(verses: verses, blocks: blocks)))
    let displays = try XCTUnwrap(passage.sourceDisplays)
    XCTAssertEqual(displays.map { $0.chapter.chapter }, [2, 1, 2], "Chapter revisits must not be regrouped or sorted")
    let shown = displays.flatMap(\.blocks)
    XCTAssertEqual(shown.map(\.id), ["first", "witness", "second", "extra", "third"])
    XCTAssertEqual(shown.map(\.text), ["כָּלְתָה", "ש", "שני", "מזמור נוסף", "שלישי"])
    XCTAssertEqual(shown.flatMap(\.sourceNotes).map(\.id), ["restored-letter", "witness-point"])
    XCTAssertEqual(shown[0].printedLabel, "ד")
    XCTAssertEqual(shown[1].printedLabel, "עדות")
    XCTAssertNil(shown[1].unit, "A witness is not duplicated in the primary numbered index")
    XCTAssertEqual(shown[2].unit?.verseLabel, "8–9")
  }

  func testReviewedSourceRejectsMissingRepeatedReorderedAndInteriorPrimaryReferences() throws {
    let verses: [[String: Any]] = [["chapter":1,"verse":1,"endVerse":3,"text":"ראשון"], ["chapter":1,"verse":5,"text":"שני"]]
    let first: [String: Any] = ["id":"first","kind":"verse","chapter":1,"verse":1]
    let second: [String: Any] = ["id":"second","kind":"verse","chapter":1,"verse":5]
    let interior: [String: Any] = ["id":"interior","kind":"verse","chapter":1,"verse":2]
    let repeated: [String: Any] = ["id":"again","kind":"verse","chapter":1,"verse":1]
    for blocks in [[first], [first, second, repeated], [second, first], [interior, second], [first, first]] {
      XCTAssertNil(try sourcePassage(sourceFixture(verses: verses, blocks: blocks)), "Invalid source coverage must not fall back to the flat list")
    }
    XCTAssertNil(try sourcePassage(sourceFixture(verses: [["chapter":1,"verse":1,"endVerse":3,"text":"א"],
      ["chapter":1,"verse":2,"text":"ב"]], blocks: [first, interior])), "Overlapping primary units are invalid")
  }

  func testReviewedSourceRejectsMalformedMetadataAndOrphanCredits() throws {
    for changes: [String: Any] in [["book":"sus"], ["name":" "], ["attribution":""], ["isComplete":1],
      ["sourceURL":"http://example.org"], ["sourceURL":"https://name:secret@example.org"],
      ["contentBlocks":NSNull()], ["contentBlocks":[]], ["unknown":"value"]] {
      XCTAssertThrowsError(try sourceDataset(sourceFixture(sourceChanges: changes)), "\(changes)")
    }
    for metadata: Any in [NSNull(), [String: Any](), ["daily|Daniel 13:1":[String: Any]()],
      ["daily|Missing 1:1":["fixture":(sourceFixture()["passageSources"] as! [String: [String: Any]])["daily|Daniel 13:1"]!["fixture"]!]],
      ["daily|Daniel 13:1":["missing":(sourceFixture()["passageSources"] as! [String: [String: Any]])["daily|Daniel 13:1"]!["fixture"]!]]] {
      var fixture = sourceFixture(); fixture["passageSources"] = metadata
      XCTAssertThrowsError(try sourceDataset(fixture))
    }
  }

  func testReviewedSourceRejectsPairedTextAndDuplicateOrInvalidBlockNotes() throws {
    XCTAssertNil(try sourcePassage(sourceFixture(verses: [["chapter":1,"verse":1,"text":"טקסט","transliteratedText":"paired"]])))
    let note: [String: Any] = ["id":"repeated", "kind":"unreadablePoint", "anchor":"ק", "occurrence":1,
      "letterIndex":1, "mark":"vowel", "sourcePages":[12], "sourceURL":"https://example.org/source"]
    let verses: [[String: Any]] = [["chapter":1,"verse":1,"text":"ק","sourceNotes":[note]]]
    let blocks: [[String: Any]] = [["id":"first","kind":"verse","chapter":1,"verse":1],
      ["id":"extra","kind":"passage","text":"ק","sourceNotes":[note]]]
    XCTAssertNil(try sourcePassage(sourceFixture(verses: verses, blocks: blocks)))
    var invalid = blocks; invalid[1]["text"] = "קָ"
    XCTAssertThrowsError(try sourceDataset(sourceFixture(verses: verses, blocks: invalid)), "An uncertainty note cannot retain its guessed vowel")
  }

  func testReviewedSourceRejectsMalformedKeysEvenWhenTheyMatchPassageKeys() throws {
    for key in ["daily|", "torah|", "other|Daniel 13:1", "Daniel 13:1"] {
      var fixture = sourceFixture()
      let passages = fixture["passages"] as! [String: Any]
      let sources = fixture["passageSources"] as! [String: Any]
      fixture["passages"] = [key: passages["daily|Daniel 13:1"]!]
      fixture["passageSources"] = [key: sources["daily|Daniel 13:1"]!]
      XCTAssertThrowsError(try sourceDataset(fixture), "A matching passage is insufficient for malformed source key \(key)")
    }
    XCTAssertNotNil(try sourcePassage(sourceFixture()))
  }

  func testPairedScriptPassageRetainsBothTextsAndFollowsDefaultUntilOverridden() throws {
    let payload = #"{"schemaVersion":1,"editions":[{"id":"paired","languageCode":"arc","name":"Paired fixture","attribution":"Synthetic fixture","sourceURL":"https://example.com","textScript":"Hebr","transliteratedTextScript":"Syrc"}],"passages":{"daily|Fixture 1:1":{"paired":[{"chapter":1,"verse":1,"text":"Hebrew-script fixture","transliteratedText":"Syriac-script fixture"}]}}}"#
    let data = try JSONDecoder().decode(ReadingTextDataset.self, from: Data(payload.utf8))
    let passage = try XCTUnwrap(data.passage(citation: "Fixture 1:1", isTorah: false, editionID: "paired"))
    XCTAssertTrue(passage.edition.supportsAramaicScriptChoice)
    let verse = try XCTUnwrap(passage.verses.first)
    for (override, defaultScript, expected) in [(nil, "Hebr", "Hebrew-script fixture"),
                                                (nil, "Syrc", "Syriac-script fixture"),
                                                ("Hebr", "Syrc", "Hebrew-script fixture"),
                                                ("Syrc", "Hebr", "Syriac-script fixture"),
                                                (nil, "invalid", "Hebrew-script fixture")] as [(String?, String, String)] {
      let script = ReadingTextScript.resolved(override: override, defaultScript: defaultScript)
      XCTAssertEqual(verse.displayedText(script: script, edition: passage.edition), expected)
    }
    for incomplete in [payload.replacingOccurrences(of: #","transliteratedText":"Syriac-script fixture""#, with: ""),
                       payload.replacingOccurrences(of: "Syriac-script fixture", with: "  ")] {
      let invalid = try JSONDecoder().decode(ReadingTextDataset.self, from: Data(incomplete.utf8))
      XCTAssertNil(invalid.passage(citation: "Fixture 1:1", isTorah: false, editionID: "paired"),
                   "A paired edition must never mix a missing script with another script")
    }
  }

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

  func testAvailableEditionsOnlyOffersCompleteTextInTheRequestedContext() {
    let verse = ReadingTextVerse(chapter: 1, verse: 1, text: "Synthetic fixture text")
    let data = ReadingTextDataset(schemaVersion: 1, editions: [english, hebrew],
      passages: ["daily|Psalm 1:1": ["english": [verse], "hebrew": []],
                 "torah|Psalm 1:1": ["hebrew": [verse]]])
    XCTAssertEqual(data.availableEditions(citation: "Psalm 1:1", isTorah: false), [english])
    XCTAssertEqual(data.availableEditions(citation: "Psalm 1:1", isTorah: true), [hebrew])
    XCTAssertTrue(data.availableEditions(citation: "Psalm 2:1", isTorah: false).isEmpty)
    XCTAssertNil(data.passage(citation: "Psalm 1:1", isTorah: false, editionID: "hebrew"),
                 "Offering another edition must never silently substitute it")
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

  func testBundledSeptember16PsalmUsesDouayRheimsNumbers() async throws {
    let result = await ReadingTextStore().passage(citation: "Psalm 33:2–3; 33:4–5; 33:12; 33:22",
                                                 isTorah: false, editionID: "douay-rheims-1899")
    let passage = try XCTUnwrap(result)
    XCTAssertEqual(passage.verses.map(\.verse), [2, 3, 4, 5, 12, 22])
    XCTAssertTrue(passage.verses.allSatisfy { $0.chapter == 32 })
    XCTAssertTrue(passage.verses.first?.text.contains("harp") == true)
  }

  func testBundledCorinthiansKeepsTheClosingBlessingAcrossNumberingSystems() async throws {
    let store = ReadingTextStore()
    for start in [3, 5] {
      let citation = "2 Corinthians 13:\(start)–13"
      for (edition, end) in [("douay-rheims-1899", 13), ("ang-dating-biblia-1905", 14)] {
        let result = await store.passage(citation: citation, isTorah: false, editionID: edition)
        let passage = try XCTUnwrap(result, "\(citation) / \(edition)")
        XCTAssertTrue(passage.verses.allSatisfy { $0.chapter == 13 })
        XCTAssertEqual(passage.verses.map(\.verse), Array(start...end),
                       "The final blessing must remain present in each edition's numbering")
        let blessing = edition == "douay-rheims-1899" ? "Holy Ghost" : "Espiritu Santo"
        XCTAssertTrue(passage.verses.last?.text.contains(blessing) == true)
      }
    }
  }

  func testBundledLiturgicalCutsKeepTheWholeAppointedBoundary() async throws {
    let store = ReadingTextStore()
    let cases: [(String, String, Int, ClosedRange<Int>)] = [
      ("Mark 3:20–30", "ang-dating-biblia-1905", 3, 19...30),
      ("Mark 3:20–30", "peshitta-1905", 3, 19...30),
      ("Luke 7:11–18", "douay-rheims-1899", 7, 11...19)
    ]
    for (citation, edition, chapter, verses) in cases {
      let result = await store.passage(citation: citation, isTorah: false, editionID: edition)
      let passage = try XCTUnwrap(result, "\(citation) / \(edition)")
      XCTAssertTrue(passage.verses.allSatisfy { $0.chapter == chapter })
      XCTAssertEqual(passage.verses.map(\.verse), Array(verses))
      XCTAssertTrue(passage.includesWholeVerses,
                    "The reader must disclose the complete verse containing the appointed clause")
    }
  }

  func testBundledSeptember13ReadingsUseTheSelectedEditionsNumbering() async throws {
    let store = ReadingTextStore()
    let cases: [(String, [String])] = [
      ("Sirach 27:30; 28:1–7", ["27:33"] + (1...9).map { "28:\($0)" }),
      ("Psalm 103:1–2; 103:3–4; 103:9–10; 103:11–12", [1, 2, 3, 4, 9, 10, 11, 12].map { "102:\($0)" }),
      ("Romans 14:7–9", (7...9).map { "14:\($0)" }),
      ("Matthew 18:21–35", (21...35).map { "18:\($0)" })
    ]
    for (citation, expected) in cases {
      let result = await store.passage(citation: citation, isTorah: false, editionID: "douay-rheims-1899")
      let passage = try XCTUnwrap(result, citation)
      XCTAssertEqual(passage.verses.map { "\($0.chapter):\($0.verse)" }, expected, citation)
      XCTAssertTrue(passage.verses.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }
    let psalmEditions = ["douay-rheims-1899": 102, "synodal-1876": 102, "jesuit-arabic-1897": 102,
                        "masoretic-delitzsch": 103, "ang-dating-biblia-1905": 103,
                        "crampon-1923": 103, "kulish-1905": 103]
    for (editionID, chapter) in psalmEditions {
      let result = await store.passage(citation: cases[1].0, isTorah: false, editionID: editionID)
      let psalm = try XCTUnwrap(result, editionID)
      XCTAssertEqual(psalm.verses.map(\.verse), [1, 2, 3, 4, 9, 10, 11, 12], editionID)
      XCTAssertTrue(psalm.verses.allSatisfy { $0.chapter == chapter }, editionID)
      XCTAssertTrue(psalm.includesWholeVerses, editionID)
    }
    for editionID in ["martini", "peshitta-1905"] {
      let result = await store.passage(citation: cases[1].0, isTorah: false, editionID: editionID)
      XCTAssertNil(result, editionID)
    }
    let frenchResult = await store.passage(citation: cases[0].0, isTorah: false, editionID: "crampon-1923")
    let french = try XCTUnwrap(frenchResult)
    XCTAssertEqual(french.verses.map { "\($0.chapter):\($0.verse)" }, ["27:30"] + (1...7).map { "28:\($0)" })
    XCTAssertTrue(french.verses.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    let hebrewResult = await store.passage(citation: cases[0].0, isTorah: false, editionID: "masoretic-delitzsch")
    let hebrew = try XCTUnwrap(hebrewResult)
    XCTAssertEqual(hebrew.verses.map { "\($0.chapter):\($0.verse)" }, ["27:30"] + (1...7).map { "28:\($0)" })
    XCTAssertEqual(hebrew.source?.book, "SIR")
    XCTAssertTrue(hebrew.source?.attribution.contains("אברהם כהנא") == true)
  }

  func testEveryBundledSupplementResolvesItsCompleteSourceDisplay() throws {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "readings-texts", withExtension: "json"))
    let dataset = try JSONDecoder().decode(ReadingTextDataset.self, from: Data(contentsOf: url))
    let sources = try XCTUnwrap(dataset.passageSources)
    XCTAssertEqual(sources.values.reduce(0) { $0 + $1.count }, 20)
    for (key, editions) in sources {
      let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
      for (edition, source) in editions {
        let passage = try XCTUnwrap(dataset.passage(citation: parts[1], isTorah: parts[0] == "torah", editionID: edition), key)
        let expected = try XCTUnwrap(dataset.passages[key]?[edition])
        XCTAssertEqual(passage.verses, expected, key)
        XCTAssertEqual(passage.source, source, key)
        if let authored = source.contentBlocks {
          let displayed = try XCTUnwrap(passage.sourceDisplays, key).flatMap(\.blocks)
          XCTAssertEqual(displayed.map(\.id), authored.map(\.id), key)
          XCTAssertEqual(displayed.compactMap(\.unit), expected, key)
          for (block, shown) in zip(authored, displayed) {
            XCTAssertEqual(shown.sourceNotes, shown.unit?.sourceNotes ?? block.sourceNotes ?? [], key)
            if block.kind != .verse { XCTAssertEqual(shown.text, block.text, key) }
          }
        }
      }
    }
    let sirach = try XCTUnwrap(dataset.passage(citation: "Sirach 51:13–17", isTorah: false, editionID: "masoretic-delitzsch"))
    XCTAssertEqual(sirach.verses.map(\.verse), [9, 10, 11, 12])
    let note = try XCTUnwrap(sirach.sourceDisplays?.flatMap(\.blocks).flatMap(\.sourceNotes).first { $0.id == "sir-51-11-alef-vowel" })
    XCTAssertEqual(note.anchor, "וְאזְכֶּרְךָ")
    XCTAssertEqual(note.sourcePages, [529])
    let daniel = try XCTUnwrap(dataset.passage(citation: "Daniel 3:25, 34–45", isTorah: false, editionID: "masoretic-delitzsch"))
    XCTAssertEqual(daniel.source?.book, "S3Y")
    XCTAssertEqual(daniel.source?.name, "תפלת עזריה ושירת שלשת הנערים בכבשן")
    XCTAssertTrue(daniel.source?.attribution.contains("תרגום דב היליר") == true)
    XCTAssertEqual(daniel.verses.first?.chapter, 1)
    XCTAssertEqual(daniel.verses.first?.verse, 4)
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
    XCTAssertEqual(editions.map(\.languageCode).sorted(), ["ar", "arc", "el", "en", "fr", "he", "it", "ru", "tl", "uk"])
    // Arabic and Aramaic have limited reviewed coverage; Greek is Old Testament only.
    // Keep complete Luke 6
    // coverage assertions for each of the seven full Bible editions.
    for edition in editions where !["ar", "arc", "el"].contains(edition.languageCode) {
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

  func testBundledGreekEditionKeepsSeptuagintChaptersAndOmitsNewTestament() async throws {
    let store = ReadingTextStore()
    let editions = await store.editions()
    let edition = try XCTUnwrap(editions.first { $0.id == "brenton-lxx" })
    XCTAssertEqual(edition.languageCode, "el")
    let result = await store.passage(citation: "Psalm 103:1–2; 103:3–4; 103:9–10; 103:11–12",
                                     isTorah: false, editionID: edition.id)
    let passage = try XCTUnwrap(result)
    XCTAssertTrue(passage.verses.allSatisfy { $0.chapter == 102 })
    XCTAssertTrue(passage.verses.first?.text.unicodeScalars.contains { (0x0370...0x03FF).contains($0.value) } == true)
    XCTAssertEqual(ScriptureChapterHeading(chapter: 102, edition: edition, script: "Grek").text, "Κεφάλαιο 102")
    let gospel = await store.passage(citation: "Luke 6:27–38", isTorah: false, editionID: edition.id)
    XCTAssertNil(gospel)
  }

  func testBundledPeshittaKeepsSourceSyriacAndHebrewProjectionTogether() async throws {
    let store = ReadingTextStore()
    let editions = await store.editions()
    let edition = try XCTUnwrap(editions.first { $0.id == "peshitta-1905" })
    XCTAssertTrue(edition.supportsAramaicScriptChoice)
    let result = await store.passage(citation: "Luke 1:26–38", isTorah: false, editionID: edition.id)
    let passage = try XCTUnwrap(result)
    XCTAssertEqual(passage.verses.map(\.verse), Array(26...38))
    for verse in passage.verses {
      XCTAssertEqual(PrayerTypography.script(of: verse.text), .hebrew)
      let syriac = try XCTUnwrap(verse.transliteratedText)
      XCTAssertEqual(PrayerTypography.script(of: syriac), .syriac)
      XCTAssertEqual(verse.displayedText(script: "Syrc", edition: edition), syriac)
      XCTAssertEqual(verse.displayedText(script: "Hebr", edition: edition), verse.text)
    }
    let torahResult = await store.passage(citation: "Genesis 47:28–50:26", isTorah: true, editionID: edition.id)
    let torah = try XCTUnwrap(torahResult)
    XCTAssertEqual(torah.verses.count, 85)
    XCTAssertEqual(torah.verses.first?.chapter, 47)
    XCTAssertEqual(torah.verses.last?.chapter, 50)
    XCTAssertTrue(torah.verses.allSatisfy { $0.transliteratedText?.isEmpty == false })
  }

  func testBundledPeshittaOldTestamentKeepsBothScriptsAndWithholdsUnreviewedPsalms() async throws {
    let store = ReadingTextStore()
    let result = await store.passage(citation: "Genesis 1:1–13", isTorah: false, editionID: "peshitta-1905")
    let passage = try XCTUnwrap(result)
    XCTAssertEqual(passage.verses.map(\.verse), Array(1...13))
    XCTAssertTrue(passage.verses.allSatisfy { $0.chapter == 1 })
    for verse in passage.verses {
      XCTAssertEqual(PrayerTypography.script(of: verse.text), .hebrew)
      let source = try XCTUnwrap(verse.transliteratedText)
      XCTAssertEqual(PrayerTypography.script(of: source), .syriac)
      XCTAssertEqual(verse.displayedText(script: "Syrc", edition: passage.edition), source)
      XCTAssertEqual(verse.displayedText(script: "Hebr", edition: passage.edition), verse.text)
    }
    XCTAssertTrue(passage.verses.first?.transliteratedText?.hasPrefix("ܒܪܺܝܫܺܝܬ݂ ܒܪܳܐ") == true,
                  "The source's consonants and vowel marks must survive native decoding")
    let unavailable = await store.passage(citation: "Psalm 23:1–3a; 23:3b–4; 23:5–5; 23:6–6",
                                          isTorah: false, editionID: "peshitta-1905")
    XCTAssertNil(unavailable, "Peshitta Psalm numbering remains unreviewed; no edition is substituted")
  }

  func testBundledArabicExpansionUsesThePrintedPsalmChapter() async throws {
    let store = ReadingTextStore()
    let result = await store.passage(citation: "Luke 12:8–12", isTorah: false, editionID: "jesuit-arabic-1897")
    let gospel = try XCTUnwrap(result)
    XCTAssertEqual(gospel.verses.map(\.verse), Array(8...12))
    XCTAssertTrue(gospel.verses.allSatisfy { $0.chapter == 12 && PrayerTypography.script(of: $0.text) == .arabic })
    let psalmResult = await store.passage(citation: "Psalm 23:1–3a; 23:3b–4; 23:5–5; 23:6–6",
                                          isTorah: false, editionID: "jesuit-arabic-1897")
    let psalm = try XCTUnwrap(psalmResult)
    XCTAssertEqual(psalm.verses.map(\.verse), Array(1...6))
    XCTAssertTrue(psalm.verses.allSatisfy { $0.chapter == 22 && PrayerTypography.script(of: $0.text) == .arabic })
    XCTAssertEqual(ScriptureChapterHeading(chapter: 22, edition: psalm.edition, script: "Arab").text,
                   "الفصل ٢٢")
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

    let missingDaily = await store.passage(citation: "Luke 13:1–9", isTorah: false, editionID: edition.id)
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

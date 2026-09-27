import CryptoKit
import Foundation
import XCTest
@testable import Prosary

final class BibleSourceStructureTests: XCTestCase {
  func testSirachPhysicalOrderWitnessesAndLazyCrossChapterNavigation() async throws {
    let (edition, data) = try fixture()
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = BibleStore(catalogURL: nil, directory: folder)
    try await store.install(data, edition: edition)
    let interleaving = try await store.displayChapter(edition: edition, book: "SIR", number: 12)
    XCTAssertEqual(interleaving.blocks.map(\.id), ["twelve-1", "eleven-34", "twelve-2"])
    XCTAssertEqual(interleaving.blocks.compactMap { $0.unit?.chapter }, [12, 11, 12])
    XCTAssertEqual(interleaving.loadedChapterNumbers, [11, 12])
    let moved = try await store.verseTarget(edition: edition, book: "SIR", chapter: 11, verse: 34)
    XCTAssertEqual(moved, BibleVerseTarget(displayChapter: 12, blockId: "eleven-34"))
    XCTAssertEqual(bibleVerseChoiceLabel(interleaving.blocks[1], display: interleaving, edition: edition.readingEdition, script: "Hebr"), "י״א:ל״ד")
    let eleven = try await store.displayChapter(edition: edition, book: "SIR", number: 11)
    XCTAssertEqual(eleven.blocks.map(\.id), ["eleven-33"])
    XCTAssertEqual(eleven.loadedChapterNumbers, [11])
    let last = try await store.displayChapter(edition: edition, book: "SIR", number: 51)
    XCTAssertEqual(last.loadedChapterNumbers, [51])
    XCTAssertEqual(last.blocks.map(\.id), ["fiftyone-12", "hymn", "fiftyone-13", "fiftyone-15", "thirteen-again", "closing"])
    XCTAssertEqual(last.choices.map(\.id), ["fiftyone-12", "fiftyone-13", "fiftyone-15", "thirteen-again"])
    let witness = try XCTUnwrap(last.blocks.first { $0.id == "thirteen-again" })
    XCTAssertEqual(last.occurrence(of: witness), 2)
    XCTAssertTrue(witness.isScripture)
    XCTAssertFalse(last.blocks.last!.isScripture)
    let primary = try await store.verseTarget(edition: edition, book: "SIR", chapter: 51, verse: 13)
    XCTAssertEqual(primary?.blockId, "fiftyone-13")
    let fortyone = try await store.displayChapter(edition: edition, book: "SIR", number: 41)
    XCTAssertEqual(fortyone.blocks.map(\.kind), [.verse, .verse, .heading, .witness])
    XCTAssertEqual(fortyone.blocks.last?.addresses.first?.part, "א")
    XCTAssertEqual(fortyone.blocks.last?.printedLabel, "ידא–טז")
  }

  func testPrintedSusannaLabelDoesNotChangeNumericRangeJump() async throws {
    let chapters: [[String: Any]] = [["chapter":1,"verses":[["chapter":1,"verse":40,"endVerse":41,"text":"מקור"]],
      "contentBlocks":[["id":"sus-forty","kind":"verse","chapter":1,"verse":40,"printedLabel":"כ–כא"]]]]
    let (edition, data) = try fixture(book: "SUS", suppliedChapters: chapters)
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = BibleStore(catalogURL: nil, directory: folder)
    try await store.install(data, edition: edition)
    let display = try await store.displayChapter(edition: edition, book: "SUS", number: 1)
    XCTAssertEqual(display.choices[0].unit?.verseLabel, "40–41")
    XCTAssertEqual(display.choices[0].printedLabel, "כ–כא")
    let target = try await store.verseTarget(edition: edition, book: "SUS", chapter: 1, verse: 41)
    XCTAssertEqual(target?.blockId, "sus-forty")
    let absent = try await store.verseTarget(edition: edition, book: "SUS", chapter: 1, verse: 20)
    XCTAssertNil(absent)
    var wrongStart = chapters
    wrongStart[0]["contentBlocks"] = [["id":"sus-forty","kind":"verse","chapter":1,"verse":41]]
    let (invalidEdition, invalidData) = try fixture(book:"SUS", suppliedChapters:wrongStart)
    XCTAssertThrowsError(try BibleStore.validatedArchive(invalidData, edition:invalidEdition))
  }

  func testRejectsMissingDuplicateDanglingAndIncorrectPresentations() throws {
    for defect in ["missing", "duplicate", "duplicateID", "dangling", "missingRoute", "wrongRoute", "extraRoute", "duplicateRoute", "implicitDuplicate", "unknownAddressChapter", "paired", "pairedNoBlocks", "empty", "null", "unknownKind", "unknownField", "nullLabel", "duplicateAddress", "equivalentAddress", "badAddress", "nullRoute", "emptyRoutes", "emptyVerses", "unknownRouteField"] {
      do {
        let (edition, data) = try fixture(defect: defect)
        XCTAssertThrowsError(try BibleStore.validatedArchive(data, edition: edition), defect)
      } catch { /* Strict decoding is also a valid rejection. */ }
    }
  }

  func testVersionGatesAndTextualBlockSourceNotes() throws {
    for version in [1, 2, 4] {
      for defect in ["", "empty"] {
        let (edition, data) = try fixture(defect: defect, version: version)
        XCTAssertThrowsError(try BibleStore.validatedArchive(data, edition: edition))
      }
    }
    // Exercise chapter-level gating independently of the metadata route gate.
    for version in [1, 2] {
      for blocks: [[String: Any]] in [[], [["id":"one","kind":"verse","chapter":1,"verse":1]]] {
        let chapters: [[String: Any]] = [["chapter":1,"verses":[["chapter":1,"verse":1,"text":"מקור"]], "contentBlocks":blocks]]
        let (edition, data) = try fixture(version:version, book:"SUS", suppliedChapters:chapters)
        XCTAssertThrowsError(try BibleStore.validatedArchive(data, edition:edition))
      }
    }
    for defect in ["notes", "passageNotes"] {
      let (edition, data) = try fixture(defect: defect)
      _ = try BibleStore.validatedArchive(data, edition: edition)
    }
    for defect in ["duplicateNote", "guessedMark", "headingNote", "pairedBlock", "emptyNotes"] {
      do {
        let (edition, data) = try fixture(defect: defect)
        XCTAssertThrowsError(try BibleStore.validatedArchive(data, edition: edition), defect)
      } catch { }
    }
  }

  private func fixture(defect: String = "", version: Int = 3, book: String = "SIR",
                       suppliedChapters: [[String: Any]]? = nil) throws -> (BibleEdition, Data) {
    func unit(_ chapter: Int, _ verse: Int) -> [String: Any] { ["chapter":chapter,"verse":verse,"text":"מקור"] }
    func ref(_ id: String, _ chapter: Int, _ verse: Int) -> [String: Any] { ["id":id,"kind":"verse","chapter":chapter,"verse":verse] }
    var chapters = suppliedChapters ?? [
      ["chapter":11,"verses":[unit(11,33),unit(11,34)],"contentBlocks":[ref("eleven-33",11,33)]],
      ["chapter":12,"verses":[unit(12,1),unit(12,2)],"contentBlocks":[ref("twelve-1",12,1),ref("eleven-34",11,34),ref("twelve-2",12,2)]],
      ["chapter":41,"verses":[unit(41,14),unit(41,15)],"contentBlocks":[ref("fortyone-14",41,14),ref("fortyone-15",41,15),
        ["id":"section","kind":"heading","text":"מוּסַר בֹּשֶׁת"],
        ["id":"subverse","kind":"witness","text":"עדות","printedLabel":"ידא–טז","addresses":[["chapter":41,"verse":14,"endVerse":16,"part":"א"]]]]],
      ["chapter":51,"verses":[unit(51,12),unit(51,13),unit(51,15)],"contentBlocks":[ref("fiftyone-12",51,12),
        ["id":"hymn","kind":"passage","text":"הוֹדוּ"],ref("fiftyone-13",51,13),ref("fiftyone-15",51,15),
        ["id":"thirteen-again","kind":"witness","text":"עדות אחרת","printedLabel":"יג","addresses":[["chapter":51,"verse":13]]],
        ["id":"closing","kind":"colophon","text":"סוף הספר"]]]]
    var routes: Any? = suppliedChapters == nil ? [["chapter":11,"verse":34,"displayChapter":12,"blockId":"eleven-34"]] : nil
    if suppliedChapters == nil {
      var first = chapters[0]["contentBlocks"] as! [[String: Any]]
      var last = chapters[3]["contentBlocks"] as! [[String: Any]]
      switch defect {
      case "missing":
        var second = chapters[1]["contentBlocks"] as! [[String: Any]]
        second.removeAll { $0["id"] as? String == "eleven-34" }; chapters[1]["contentBlocks"] = second
      case "duplicate": first.append(ref("duplicate",11,33))
      case "duplicateID": last[0]["id"] = "eleven-33"
      case "dangling": first[0]["verse"] = 999
      case "missingRoute": routes = nil
      case "wrongRoute": routes = [["chapter":12,"verse":1,"displayChapter":12,"blockId":"twelve-1"]]
      case "extraRoute": routes = [["chapter":12,"verse":1,"displayChapter":11,"blockId":"twelve-1"],["chapter":11,"verse":33,"displayChapter":11,"blockId":"eleven-33"]]
      case "duplicateRoute": routes = [["chapter":12,"verse":1,"displayChapter":11,"blockId":"twelve-1"],["chapter":12,"verse":1,"displayChapter":11,"blockId":"twelve-1"]]
      case "implicitDuplicate": break
      case "unknownAddressChapter": last[4]["addresses"] = [["chapter":999,"verse":13]]
      case "empty": first = []
      case "unknownKind": first[0]["kind"] = "invisible"
      case "unknownField": first[0]["text"] = "discarded"
      case "nullLabel": first[0]["printedLabel"] = NSNull()
      case "duplicateAddress": last[4]["addresses"] = [["chapter":51,"verse":13],["chapter":51,"verse":13]]
      case "equivalentAddress": last[4]["addresses"] = [["chapter":51,"verse":13],["chapter":51,"verse":13,"endVerse":13]]
      case "badAddress": last[4]["addresses"] = [["chapter":51,"verse":13,"endVerse":12]]
      case "nullRoute": routes = NSNull()
      case "emptyRoutes": routes = []
      case "emptyVerses": chapters[1]["verses"] = []
      case "unknownRouteField": routes = [["chapter":12,"verse":1,"displayChapter":11,"blockId":"twelve-1","text":"ignored"]]
      default: break
      }
      if ["notes", "passageNotes", "duplicateNote", "guessedMark", "headingNote", "pairedBlock", "emptyNotes"].contains(defect) {
        let note: [String: Any] = ["id":"qoph-vowel","kind":"unreadablePoint","anchor":"בַּקּבָּה","occurrence":1,"letterIndex":2,"mark":"vowel","sourcePages":[16],"sourceURL":"https://example.org/scan.pdf#page=16"]
        let index = defect == "passageNotes" ? 1 : 4
        last[index]["text"] = defect == "guessedMark" ? "בַּקָּבָּה" : "בַּקּבָּה"
        last[index]["sourceNotes"] = defect == "emptyNotes" ? [] : [note]
        if defect == "duplicateNote" {
          var verses = chapters[3]["verses"] as! [[String: Any]]
          verses[0]["text"] = "בַּקּבָּה"; verses[0]["sourceNotes"] = [note]; chapters[3]["verses"] = verses
        }
        if defect == "headingNote" { last[index]["kind"] = "heading" }
        if defect == "pairedBlock" { last[index]["transliteratedText"] = "unsupported" }
      }
      chapters[0]["contentBlocks"] = defect == "null" ? NSNull() : first
      chapters[3]["contentBlocks"] = last
      if defect == "implicitDuplicate" { chapters[0].removeValue(forKey: "contentBlocks") }
      if defect == "pairedNoBlocks" {
        routes = nil
        for index in chapters.indices { chapters[index].removeValue(forKey: "contentBlocks") }
      }
    }
    let revision = String(repeating: "a", count: 64)
    var metadata: [String: Any] = ["id":book,"name":"Source fixture","chapters":chapters.map { ["number":$0["chapter"]!,"verseCount":($0["verses"] as! [[String: Any]]).count,"isComplete":false] }]
    if let routes { metadata["addressRoutes"] = routes }
    let manifest: [String: Any] = ["schemaVersion":version,"editionId":"structure-test","revision":revision,"books":[metadata]]
    var files = [("manifest.json", try JSONSerialization.data(withJSONObject: manifest))]
    for var chapter in chapters {
      chapter["schemaVersion"] = version; chapter["editionId"] = "structure-test"; chapter["book"] = book
      files.append(("chapters/\(book)/\(chapter["chapter"]!).json", try JSONSerialization.data(withJSONObject: chapter)))
    }
    let data = BibleStoreTests.zip(files)
    var catalog: [String: Any] = ["id":"structure-test","languageCode":"he","name":"Fixture","attribution":"Source fixture","sourceURL":"https://example.org/scan.pdf",
      "archiveSchemaVersion":version,"revision":revision,"downloadURL":"https://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/structure-test.zip",
      "archiveSHA256":SHA256.hash(data: data).map { String(format:"%02x",$0) }.joined(),"archiveByteCount":data.count,"unpackedByteCount":files.reduce(0) { $0 + $1.1.count },"books":[metadata]]
    if defect == "paired" || defect == "pairedNoBlocks" { catalog["textScript"] = "Hebr"; catalog["transliteratedTextScript"] = "Syrc" }
    return (try JSONDecoder().decode(BibleEdition.self, from: JSONSerialization.data(withJSONObject: catalog)), data)
  }
}

import CryptoKit
import Foundation
import XCTest
@testable import Prosary

final class BibleStoreTests: XCTestCase {
  func testCatalogMatchesReadingEditionsAndRealArchivesValidate() async throws {
    let editions = try await BibleStore.shared.editions()
    let readings = await ReadingTextStore.shared.editions()
    XCTAssertEqual(Set(editions.map(\.id)), Set(readings.map(\.id)))
    let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    for edition in editions {
      XCTAssertEqual(edition.readingEdition, readings.first { $0.id == edition.id })
      let archive = repository.appending(path: "Shared/dist/bibles").appending(path: URL(string: edition.downloadURL)!.lastPathComponent)
      _ = try BibleStore.validatedArchive(Data(contentsOf: archive), edition: edition)
    }
  }

  func testAtomicInstallOfflineReloadAndRemovalAreEditionScoped() async throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let (edition, data) = try fixture()
    let store = BibleStore(catalogURL: nil, directory: folder)
    try await store.install(data, edition: edition)
    let installed = await store.isInstalled(edition)
    XCTAssertTrue(installed)
    let reloaded = BibleStore(catalogURL: nil, directory: folder)
    let chapter = try await reloaded.chapter(edition: edition, book: "GEN", number: 1)
    XCTAssertEqual(chapter.verses.map(\.verse), [1, 3]) // A real gap stays a gap.
    do { try await store.install(Data("bad".utf8), edition: edition); XCTFail("Invalid update installed") }
    catch { }
    let afterFailure = try await store.chapter(edition: edition, book: "GEN", number: 1)
    XCTAssertEqual(afterFailure.verses, chapter.verses)
    let unrelated = folder.appending(path: "unrelated.json")
    try Data("preserve".utf8).write(to: unrelated)
    try await store.remove(edition)
    let afterRemoval = await store.isInstalled(edition)
    XCTAssertFalse(afterRemoval)
    XCTAssertEqual(try String(contentsOf: unrelated, encoding: .utf8), "preserve")
    do { _ = try await store.chapter(edition: edition, book: "GEN", number: 1); XCTFail("Removed text cached") }
    catch { }
  }

  func testRejectsHashMismatchUndeclaredPathsAndUnpairedOrDuplicateVerses() throws {
    let (edition, data) = try fixture()
    XCTAssertThrowsError(try BibleStore.validatedArchive(data + Data([0]), edition: edition))
    for kind in ["extra", "duplicate", "unpaired", "wrongChapter", "wrongManifest", "size", "overlap", "reversedRange", "wrongIntroduction", "emptyIntroduction", "sourceOrderOverlap"] {
      let (badEdition, badData) = try fixture(defect: kind)
      XCTAssertThrowsError(try BibleStore.validatedArchive(badData, edition: badEdition), kind)
    }
  }

  func testSirachDisplacedLabelsKeepSourceOrderAndRemainNavigable() async throws {
    let (edition, data) = try fixture(defect: "sourceOrder")
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = BibleStore(catalogURL: nil, directory: folder)
    try await store.install(data, edition: edition)
    let chapter = try await store.chapter(edition: edition, book: "SIR", number: 3)
    // Kahana volume B, PDF453 prints 25 after 27; it must not be silently reordered.
    XCTAssertEqual(chapter.verses.map(\.verse), [24, 26, 27, 25, 28])
    for label in [24, 26, 27, 25, 28] { XCTAssertEqual(chapter.unitStart(containing: label), label) }
    XCTAssertNil(chapter.unitStart(containing: 29))
  }

  func testUnnumberedIntroductionPreservesSourceWithoutAddingAVerse() async throws {
    let (edition, data) = try fixture(defect: "introduction")
    _ = try BibleStore.validatedArchive(data, edition: edition)
    let book = try XCTUnwrap(edition.books.first)
    XCTAssertEqual(book.introduction(for: 1), "פְּתִיחָה בְּלִי מִסְפָּר")
    XCTAssertNil(book.introduction(for: 2))
    XCTAssertEqual(book.chapters[0].verseCount, 2)
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = BibleStore(catalogURL: nil, directory: folder)
    try await store.install(data, edition: edition)
    let chapter = try await store.chapter(edition: edition, book: "GEN", number: 1)
    XCTAssertEqual(chapter.verses.map(\.verse), [1, 3])
    XCTAssertNil(chapter.unitStart(containing: 0))
  }

  func testCombinedPrintedVerseIsOneUnitWithEveryLabelNavigable() async throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let (edition, data) = try fixture(defect: "combined")
    let store = BibleStore(catalogURL: nil, directory: folder)
    try await store.install(data, edition: edition)
    let chapter = try await store.chapter(edition: edition, book: "GEN", number: 1)
    XCTAssertEqual(chapter.verses.count, 2)
    XCTAssertEqual(chapter.verses[0].verseLabel, "1–2")
    XCTAssertEqual(chapter.unitStart(containing: 1), 1)
    XCTAssertEqual(chapter.unitStart(containing: 2), 1)
    XCTAssertEqual(chapter.unitStart(containing: 3), 3)
    XCTAssertNil(chapter.unitStart(containing: 4))
  }

  func testCatalogRejectsUnsafePathsAndNonHTTPSDownloads() throws {
    for changes in [["id":"../outside"], ["downloadURL":"http://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/test.zip"], ["revision":"bad"]] {
      let (edition, _) = try fixture(changes: changes)
      XCTAssertThrowsError(try BibleStore.validate(edition))
    }
  }

  func testChapterNavigationFollowsAvailableInventoryAcrossBooks() async throws {
    let editions = try await BibleStore.shared.editions()
    let edition = try XCTUnwrap(editions.first)
    let first = try XCTUnwrap(edition.books.first)
    let start = BiblePosition(book: first.id, chapter: first.chapters[0].number)
    XCTAssertNil(start.moving(by: -1, in: edition))
    let second = try XCTUnwrap(edition.books.dropFirst().first)
    let end = BiblePosition(book: first.id, chapter: first.chapters.last!.number)
    XCTAssertEqual(end.moving(by: 1, in: edition), BiblePosition(book: second.id, chapter: second.chapters[0].number))
  }

  private func fixture(defect: String = "", changes: [String: Any] = [:]) throws -> (BibleEdition, Data) {
    let revision = String(repeating: "a", count: 64)
    let sourceOrder = defect.hasPrefix("sourceOrder")
    let book = sourceOrder ? "SIR" : "GEN", chapterNumber = sourceOrder ? 3 : 1
    var books: [[String: Any]] = [["id":book, "name":"Fixture", "transliteratedName":"ܒܪܝܬܐ",
      "chapters":[["number":chapterNumber,"verseCount":sourceOrder ? 5 : 2,"isComplete":false]]]]
    if ["introduction", "wrongIntroduction", "emptyIntroduction"].contains(defect) {
      books[0]["introduction"] = defect == "emptyIntroduction" ? " \n " : "פְּתִיחָה בְּלִי מִסְפָּר"
    }
    let manifest: [String: Any] = ["schemaVersion":1,"editionId":defect == "wrongManifest" ? "other" : "test", "revision":revision,"books":books]
    var verses: [[String: Any]] = [["chapter":1,"verse":1,"text":"אב","transliteratedText":"ܐܒ"],
      ["chapter":defect == "wrongChapter" ? 2 : 1,"verse":defect == "duplicate" ? 1 : 3,"text":"גד","transliteratedText":defect == "unpaired" ? "" : "ܓܕ"]]
    if ["combined", "overlap", "reversedRange"].contains(defect) {
      verses[0]["endVerse"] = defect == "combined" ? 2 : defect == "overlap" ? 3 : 0
    }
    if sourceOrder {
      verses = [24, 26, 27, 25, 28].map { ["chapter":3,"verse":$0,"text":"אב","transliteratedText":"ܐܒ"] }
      if defect == "sourceOrderOverlap" { verses[0]["endVerse"] = 25 }
    }
    let chapter: [String: Any] = ["schemaVersion":1,"editionId":"test","book":book,"chapter":chapterNumber,"verses":verses]
    var files = [("manifest.json", try JSONSerialization.data(withJSONObject: manifest)),
                 ("chapters/\(book)/\(chapterNumber).json", try JSONSerialization.data(withJSONObject: chapter))]
    if defect == "extra" { files.append(("extra.json", Data("{}".utf8))) }
    let data = Self.zip(files)
    if defect == "wrongIntroduction" { books[0]["introduction"] = "Different source opening" }
    var object: [String: Any] = ["id":"test","languageCode":"arc","name":"Test","attribution":"Fixture",
      "sourceURL":"https://example.com/source","textScript":"Hebr","transliteratedTextScript":"Syrc",
      "revision":revision,"downloadURL":"https://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/test.zip",
      "archiveSHA256":SHA256.hash(data: data).map { String(format:"%02x",$0) }.joined(),
      "archiveByteCount":data.count,"unpackedByteCount":files.reduce(0) { $0 + $1.1.count } + (defect == "size" ? 1 : 0),"books":books]
    object.merge(changes) { _, new in new }
    let edition = try JSONDecoder().decode(BibleEdition.self, from: JSONSerialization.data(withJSONObject: object))
    return (edition, data)
  }

  private static func zip(_ files: [(String, Data)]) -> Data {
    func n16(_ v: Int) -> Data { Data([UInt8(v & 255), UInt8((v >> 8) & 255)]) }
    func n32(_ v: Int) -> Data { n16(v) + n16(v >> 16) }
    func crc(_ data: Data) -> Int {
      var value: UInt32 = 0xffffffff
      for byte in data {
        value ^= UInt32(byte)
        for _ in 0..<8 { value = value & 1 == 1 ? (value >> 1) ^ 0xedb88320 : value >> 1 }
      }
      return Int(value ^ 0xffffffff)
    }
    var archive = Data(), directory = Data()
    for (name, body) in files {
      let offset = archive.count, bytes = Data(name.utf8), sum = crc(body)
      archive += n32(0x04034b50) + n16(20) + n16(0) + n16(0) + n16(0) + n16(0)
      archive += n32(sum) + n32(body.count) + n32(body.count) + n16(bytes.count) + n16(0) + bytes + body
      directory += n32(0x02014b50) + n16(20) + n16(20) + n16(0) + n16(0) + n16(0) + n16(0)
      directory += n32(sum) + n32(body.count) + n32(body.count) + n16(bytes.count)
      directory += n16(0) + n16(0) + n16(0) + n16(0) + n32(0) + n32(offset) + bytes
    }
    let offset = archive.count
    archive += directory
    archive += n32(0x06054b50) + n16(0) + n16(0) + n16(files.count) + n16(files.count)
    archive += n32(directory.count) + n32(offset) + n16(0)
    return archive
  }
}

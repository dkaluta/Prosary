import CryptoKit
import Foundation

nonisolated struct BibleChapterInfo: Codable, Equatable, Hashable, Sendable {
  let number: Int
  let verseCount: Int
  let isComplete: Bool
}

nonisolated struct BibleBook: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let name: String
  var transliteratedName: String? = nil
  var attribution: String? = nil
  var sourceURL: String? = nil
  var introduction: String? = nil
  let chapters: [BibleChapterInfo]
  var addressRoutes: [BibleAddressRoute]? = nil

  func displayedName(script: String) -> String {
    script == "Syrc" ? transliteratedName ?? name : name
  }

  func introduction(for chapter: Int) -> String? {
    chapter == chapters.first?.number ? introduction : nil
  }
}

extension BibleBook {
  private enum CodingKeys: String, CodingKey { case id, name, transliteratedName, attribution, sourceURL, introduction, chapters, addressRoutes }
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    name = try values.decode(String.self, forKey: .name)
    transliteratedName = try values.decodeIfPresent(String.self, forKey: .transliteratedName)
    attribution = try values.decodeIfPresent(String.self, forKey: .attribution)
    sourceURL = try values.decodeIfPresent(String.self, forKey: .sourceURL)
    introduction = try values.decodeIfPresent(String.self, forKey: .introduction)
    chapters = try values.decode([BibleChapterInfo].self, forKey: .chapters)
    addressRoutes = values.contains(.addressRoutes) ? try values.decode([BibleAddressRoute].self, forKey: .addressRoutes) : nil
  }
}

nonisolated struct BibleEdition: Decodable, Equatable, Identifiable, Sendable {
  let id: String
  let languageCode: String
  let name: String
  let attribution: String
  let sourceURL: String
  let textScript: String?
  let transliteratedTextScript: String?
  let revision: String
  let downloadURL: String
  let archiveSHA256: String
  let archiveByteCount: Int
  let unpackedByteCount: Int
  let books: [BibleBook]
  var archiveSchemaVersion: Int? = nil

  var resolvedArchiveSchemaVersion: Int { archiveSchemaVersion ?? 1 }

  var readingEdition: ReadingTextEdition {
    ReadingTextEdition(id: id, languageCode: languageCode, name: name, attribution: attribution,
                       sourceURL: sourceURL, textScript: textScript,
                       transliteratedTextScript: transliteratedTextScript)
  }
}

nonisolated struct BibleCatalog: Decodable, Sendable {
  let schemaVersion: Int
  let editions: [BibleEdition]
}

extension BibleEdition {
  private enum CodingKeys: String, CodingKey {
    case id, languageCode, name, attribution, sourceURL, textScript, transliteratedTextScript
    case revision, downloadURL, archiveSHA256, archiveByteCount, unpackedByteCount, books, archiveSchemaVersion
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    languageCode = try values.decode(String.self, forKey: .languageCode)
    name = try values.decode(String.self, forKey: .name)
    attribution = try values.decode(String.self, forKey: .attribution)
    sourceURL = try values.decode(String.self, forKey: .sourceURL)
    textScript = try values.decodeIfPresent(String.self, forKey: .textScript)
    transliteratedTextScript = try values.decodeIfPresent(String.self, forKey: .transliteratedTextScript)
    revision = try values.decode(String.self, forKey: .revision)
    downloadURL = try values.decode(String.self, forKey: .downloadURL)
    archiveSHA256 = try values.decode(String.self, forKey: .archiveSHA256)
    archiveByteCount = try values.decode(Int.self, forKey: .archiveByteCount)
    unpackedByteCount = try values.decode(Int.self, forKey: .unpackedByteCount)
    books = try values.decode([BibleBook].self, forKey: .books)
    archiveSchemaVersion = values.contains(.archiveSchemaVersion) ? try values.decode(Int.self, forKey: .archiveSchemaVersion) : nil
  }
}

nonisolated struct BibleManifest: Decodable, Sendable {
  let schemaVersion: Int
  let editionId: String
  let revision: String
  let books: [BibleBook]
}

nonisolated struct BibleChapter: Decodable, Sendable {
  let schemaVersion: Int
  let editionId: String
  let book: String
  let chapter: Int
  let verses: [ReadingTextVerse]
  var contentBlocks: [BibleContentBlock]? = nil

  func unitStart(containing verse: Int) -> Int? {
    verses.first { $0.contains(verse: verse) }?.verse
  }
}

extension BibleChapter {
  private enum CodingKeys: String, CodingKey { case schemaVersion, editionId, book, chapter, verses, contentBlocks }
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
    editionId = try values.decode(String.self, forKey: .editionId)
    book = try values.decode(String.self, forKey: .book)
    chapter = try values.decode(Int.self, forKey: .chapter)
    verses = try values.decode([ReadingTextVerse].self, forKey: .verses)
    contentBlocks = values.contains(.contentBlocks) ? try values.decode([BibleContentBlock].self, forKey: .contentBlocks) : nil
  }
}

nonisolated enum BibleStoreError: Error { case invalidCatalog, invalidArchive, notDownloaded }

/// Bible archives have an independent local lifetime. No prayer, preset, daily-reading
/// dataset or iCloud file is removed when a downloaded edition is removed.
actor BibleStore {
  static let shared = BibleStore()
  nonisolated static let maximumArchiveBytes = 32 * 1024 * 1024
  nonisolated static let maximumExpandedBytes = 128 * 1024 * 1024
  nonisolated static let maximumChapterBytes = 2 * 1024 * 1024
  private let catalogURL: URL?
  private let directory: URL
  private var cachedCatalog: [BibleEdition]?
  private var archives: [String: MinimalZipReader] = [:]

  init(catalogURL: URL? = Bundle.main.url(forResource: "bible-catalog", withExtension: "json"),
       directory: URL = URL.applicationSupportDirectory.appending(path: "Prosary/Bibles")) {
    self.catalogURL = catalogURL
    self.directory = directory
  }

  func editions() throws -> [BibleEdition] {
    if let cachedCatalog { return cachedCatalog }
    guard let catalogURL else { throw BibleStoreError.invalidCatalog }
    let catalog = try JSONDecoder().decode(BibleCatalog.self, from: Data(contentsOf: catalogURL))
    guard catalog.schemaVersion == 1, Set(catalog.editions.map(\.id)).count == catalog.editions.count else {
      throw BibleStoreError.invalidCatalog
    }
    for edition in catalog.editions { try Self.validate(edition) }
    cachedCatalog = catalog.editions
    return catalog.editions
  }

  nonisolated static func validate(_ edition: BibleEdition) throws {
    guard edition.id.range(of: "^[a-z0-9][a-z0-9-]*$", options: .regularExpression) != nil,
          isHash(edition.revision), isHash(edition.archiveSHA256),
          downloadURL(edition) != nil,
          (1...maximumArchiveBytes).contains(edition.archiveByteCount),
          (1...maximumExpandedBytes).contains(edition.unpackedByteCount),
          !edition.name.isEmpty, !edition.books.isEmpty,
          (1...3).contains(edition.resolvedArchiveSchemaVersion),
          (edition.resolvedArchiveSchemaVersion != 3 || edition.textScript == nil && edition.transliteratedTextScript == nil),
          Set(edition.books.map(\.id)).count == edition.books.count,
          (edition.textScript == nil) == (edition.transliteratedTextScript == nil) else {
      throw BibleStoreError.invalidCatalog
    }
    for book in edition.books {
      guard book.id.range(of: "^[A-Z0-9]+$", options: .regularExpression) != nil,
            !book.name.isEmpty, !book.chapters.isEmpty,
            book.introduction.map({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? true,
            book.chapters.map(\.number) == Array(Set(book.chapters.map(\.number))).sorted(),
            book.chapters.allSatisfy({ $0.number > 0 && $0.verseCount > 0 }) else {
        throw BibleStoreError.invalidCatalog
      }
      if let routes = book.addressRoutes {
        guard edition.resolvedArchiveSchemaVersion == 3, !routes.isEmpty,
              Set(routes.map { "\($0.chapter):\($0.verse)" }).count == routes.count,
              routes.allSatisfy({ route in route.chapter != route.displayChapter
                && book.chapters.contains { $0.number == route.chapter }
                && book.chapters.contains { $0.number == route.displayChapter } }) else { throw BibleStoreError.invalidCatalog }
      }
    }
  }

  nonisolated private static func isHash(_ value: String) -> Bool {
    value.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
  }

  nonisolated static func downloadURL(_ edition: BibleEdition) -> URL? {
    guard let url = URL(string: edition.downloadURL), url.scheme == "https",
          url.host == "raw.githubusercontent.com", url.user == nil, url.password == nil,
          url.port == nil, url.query == nil, url.fragment == nil,
          url.path.hasPrefix("/dkaluta/Prosary/main/Shared/dist/bibles/"),
          !url.pathComponents.contains(".."), url.pathExtension == "zip" else { return nil }
    return url
  }

  private func archiveURL(_ edition: BibleEdition) -> URL {
    directory.appending(path: edition.id).appending(path: edition.revision + ".zip")
  }

  func isInstalled(_ edition: BibleEdition) -> Bool {
    (try? archive(edition)) != nil
  }

  private func archive(_ edition: BibleEdition) throws -> MinimalZipReader {
    try Self.validate(edition)
    if let cached = archives[edition.id + "|" + edition.revision] { return cached }
    guard FileManager.default.fileExists(atPath: archiveURL(edition).path) else {
      throw BibleStoreError.notDownloaded
    }
    guard try archiveURL(edition).resourceValues(forKeys: [.fileSizeKey]).fileSize == edition.archiveByteCount else {
      throw BibleStoreError.invalidArchive
    }
    let data = try Data(contentsOf: archiveURL(edition), options: .mappedIfSafe)
    let reader = try Self.validatedArchive(data, edition: edition)
    archives[edition.id + "|" + edition.revision] = reader
    return reader
  }

  func install(_ data: Data, edition: BibleEdition) throws {
    _ = try Self.validatedArchive(data, edition: edition)
    try Task.checkCancellation()
    let url = archiveURL(edition)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
    // Map the installed file, not the temporary download buffer.
    archives[edition.id + "|" + edition.revision] = try MinimalZipReader(contentsOf: url)
  }

  func remove(_ edition: BibleEdition) throws {
    try Self.validate(edition)
    let folder = directory.appending(path: edition.id)
    if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) }
    archives = archives.filter { !$0.key.hasPrefix(edition.id + "|") }
    NotificationCenter.default.post(name: .bibleDownloadsChanged, object: nil)
  }

  func chapter(edition: BibleEdition, book: String, number: Int) throws -> BibleChapter {
    guard let info = edition.books.first(where: { $0.id == book })?.chapters.first(where: { $0.number == number }) else {
      throw BibleStoreError.invalidArchive
    }
    let reader = try archive(edition)
    let chapter = try Self.decodeChapter(reader, edition: edition, book: book, info: info)
    return chapter
  }

  nonisolated static func validatedArchive(_ data: Data, edition: BibleEdition) throws -> MinimalZipReader {
    try validate(edition)
    guard data.count == edition.archiveByteCount,
          SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == edition.archiveSHA256 else {
      throw BibleStoreError.invalidArchive
    }
    let reader = try MinimalZipReader(data: data)
    let expected = Set(["manifest.json"] + edition.books.flatMap { book in
      book.chapters.map { "chapters/\(book.id)/\($0.number).json" }
    })
    guard Set(reader.fileNames()) == expected else { throw BibleStoreError.invalidArchive }
    try reader.validateEntrySizes(names: Array(expected), maximumEntryBytes: maximumChapterBytes,
                                  maximumTotalBytes: maximumExpandedBytes)
    guard reader.expandedByteCount == edition.unpackedByteCount else { throw BibleStoreError.invalidArchive }
    let manifest = try JSONDecoder().decode(BibleManifest.self,
      from: reader.contents(of: "manifest.json", maximumBytes: maximumChapterBytes))
    guard manifest.schemaVersion == edition.resolvedArchiveSchemaVersion, manifest.editionId == edition.id,
          manifest.revision == edition.revision, manifest.books == edition.books else {
      throw BibleStoreError.invalidArchive
    }
    for book in edition.books {
      var chapters: [Int: BibleChapter] = [:]
      for info in book.chapters {
        chapters[info.number] = try decodeChapter(reader, edition: edition, book: book.id, info: info)
      }
      try validatePresentations(book: book, chapters: chapters)
    }
    return reader
  }

  nonisolated private static func decodeChapter(_ reader: MinimalZipReader, edition: BibleEdition,
                                               book: String, info: BibleChapterInfo) throws -> BibleChapter {
    let value = try JSONDecoder().decode(BibleChapter.self,
      from: reader.contents(of: "chapters/\(book)/\(info.number).json", maximumBytes: maximumChapterBytes))
    // Numbering may be displaced in the source (Sirach 3:26,27,25). Sort only
    // this validation copy; the reader and verse picker retain the printed order.
    let numbered = value.verses.sorted { $0.verse < $1.verse }
    guard value.schemaVersion == edition.resolvedArchiveSchemaVersion, value.editionId == edition.id, value.book == book,
          value.chapter == info.number, value.verses.count == info.verseCount,
          zip(numbered, numbered.dropFirst()).allSatisfy({ $1.verse > ($0.endVerse ?? $0.verse) }),
          value.verses.allSatisfy({ $0.chapter == info.number && $0.verse > 0 && ($0.endVerse ?? $0.verse) >= $0.verse
            && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && $0.hasValidSourceNotes
            && ($0.sourceNotes == nil || edition.resolvedArchiveSchemaVersion >= 2 && edition.transliteratedTextScript == nil)
            && (edition.transliteratedTextScript == nil || !($0.transliteratedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }) else {
      throw BibleStoreError.invalidArchive
    }
    if let blocks = value.contentBlocks {
      guard value.schemaVersion == 3, !blocks.isEmpty, edition.transliteratedTextScript == nil,
            value.verses.allSatisfy({ $0.transliteratedText == nil }) else { throw BibleStoreError.invalidArchive }
    }
    return value
  }

  /// Validate complete presentation before a single byte is installed. Implicit
  /// ordinary chapter rows count too, so a moved verse cannot also remain hidden there.
  nonisolated static func validatePresentations(book: BibleBook, chapters: [Int: BibleChapter]) throws {
    var expected = Set<String>(), seen = Set<String>(), blockIDs = Set<String>(), noteIDs = Set<String>()
    var routes = Set<BibleAddressRoute>()
    func address(_ chapter: Int, _ verse: Int) -> String { "\(chapter):\(verse)" }
    func recordNotes(_ notes: [ScriptureSourceNote]) throws {
      for note in notes where !noteIDs.insert(note.id).inserted { throw BibleStoreError.invalidArchive }
    }
    for chapter in chapters.values {
      for unit in chapter.verses {
        expected.insert(address(chapter.chapter, unit.verse))
        try recordNotes(unit.sourceNotes ?? [])
      }
    }
    for chapter in chapters.values {
      if let blocks = chapter.contentBlocks {
        for block in blocks {
          guard blockIDs.insert(block.id).inserted else { throw BibleStoreError.invalidArchive }
          if block.kind == .verse {
            guard let sourceChapter = block.chapter, let verse = block.verse,
                  expected.contains(address(sourceChapter, verse)), seen.insert(address(sourceChapter, verse)).inserted else {
              throw BibleStoreError.invalidArchive
            }
            if sourceChapter != chapter.chapter {
              routes.insert(BibleAddressRoute(chapter: sourceChapter, verse: verse, displayChapter: chapter.chapter, blockId: block.id))
            }
          } else {
            guard (block.addresses ?? []).allSatisfy({ chapters[$0.chapter] != nil }) else { throw BibleStoreError.invalidArchive }
            try recordNotes(block.sourceNotes ?? [])
          }
        }
      } else {
        for unit in chapter.verses where !seen.insert(address(chapter.chapter, unit.verse)).inserted { throw BibleStoreError.invalidArchive }
      }
    }
    guard seen == expected, routes == Set(book.addressRoutes ?? []) else { throw BibleStoreError.invalidArchive }
  }

  /// Load just the display chapter and its direct primary references, never the book.
  func displayChapter(edition: BibleEdition, book: String, number: Int) throws -> BibleDisplayChapter {
    let selected = try chapter(edition: edition, book: book, number: number)
    var primary = [number: selected]
    for referenced in Set((selected.contentBlocks ?? []).compactMap { $0.kind == .verse ? $0.chapter : nil }) where referenced != number {
      primary[referenced] = try chapter(edition: edition, book: book, number: referenced)
    }
    return try BibleDisplayChapter.resolve(selected, primaryChapters: primary)
  }

  func verseTarget(edition: BibleEdition, book: String, chapter number: Int, verse: Int) throws -> BibleVerseTarget? {
    guard let metadata = edition.books.first(where: { $0.id == book }) else { throw BibleStoreError.invalidArchive }
    let primary = try chapter(edition: edition, book: book, number: number)
    guard let start = primary.unitStart(containing: verse) else { return nil }
    if let route = metadata.addressRoutes?.first(where: { $0.chapter == number && $0.verse == start }) {
      return BibleVerseTarget(displayChapter: route.displayChapter, blockId: route.blockId)
    }
    if let blocks = primary.contentBlocks {
      guard let block = blocks.first(where: { $0.kind == .verse && $0.chapter == number && $0.verse == start }) else { throw BibleStoreError.invalidArchive }
      return BibleVerseTarget(displayChapter: number, blockId: block.id)
    }
    return BibleVerseTarget(displayChapter: number, blockId: "primary-\(number)-\(start)")
  }

  func download(_ edition: BibleEdition, progress: @escaping @Sendable (Double) -> Void) async throws {
    try Self.validate(edition)
    guard let url = Self.downloadURL(edition) else { throw BibleStoreError.invalidCatalog }
    let delegate = BibleDownloadProgress(expected: edition.archiveByteCount, progress: progress)
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let (file, response) = try await session.download(from: url, delegate: delegate)
    defer { try? FileManager.default.removeItem(at: file) }
    guard let response = response as? HTTPURLResponse, response.statusCode == 200,
          response.url == url,
          (try file.resourceValues(forKeys: [.fileSizeKey])).fileSize == edition.archiveByteCount else {
      throw BibleStoreError.invalidArchive
    }
    try Task.checkCancellation()
    try install(Data(contentsOf: file, options: .mappedIfSafe), edition: edition)
    NotificationCenter.default.post(name: .bibleDownloadsChanged, object: nil)
  }
}

extension Notification.Name {
  static let bibleDownloadsChanged = Notification.Name("Prosary.bibleDownloadsChanged")
}

nonisolated private final class BibleDownloadProgress: NSObject, URLSessionDownloadDelegate, Sendable {
  let expected: Int
  let progress: @Sendable (Double) -> Void
  init(expected: Int, progress: @escaping @Sendable (Double) -> Void) {
    self.expected = expected
    self.progress = progress
  }
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                  didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                  totalBytesExpectedToWrite: Int64) {
    guard totalBytesWritten <= expected,
          totalBytesExpectedToWrite <= expected else { downloadTask.cancel(); return }
    progress(min(1, Double(totalBytesWritten) / Double(expected)))
  }
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                  didFinishDownloadingTo location: URL) {}
  func urlSession(_ session: URLSession, task: URLSessionTask,
                  willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                  completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
    completionHandler(nil)
  }
}

nonisolated struct BiblePosition: Equatable, Sendable {
  let book: String
  let chapter: Int

  func moving(by delta: Int, in edition: BibleEdition) -> BiblePosition? {
    let positions = edition.books.flatMap { book in book.chapters.map { BiblePosition(book: book.id, chapter: $0.number) } }
    guard let index = positions.firstIndex(of: self), positions.indices.contains(index + delta) else { return nil }
    return positions[index + delta]
  }
}

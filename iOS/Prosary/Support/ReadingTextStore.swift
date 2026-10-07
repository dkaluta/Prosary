import Foundation

/// Build-time citation identities are opaque. New registry tables have their own namespace;
/// they must never borrow a same-numbered passage from the legacy Roman corpus.
nonisolated enum ReadingPassageIdentity {
  private static let legacyDatasets: Set<String> = ["roman", "roman1962", "ugcc", "ugcc-gregorian", "syriac", "maronite"]

  static func key(citation: String, isTorah: Bool, datasetID: String? = nil) -> String? {
    guard !citation.isEmpty, !citation.contains("|") else { return nil }
    if isTorah { return "torah|\(citation)" }
    guard let datasetID, !datasetID.isEmpty else { return "daily|\(citation)" }
    let normalized = datasetID == "lpj" ? "roman" : datasetID
    guard normalized.range(of: "^[a-z0-9][a-z0-9-]*$", options: .regularExpression) != nil else { return nil }
    return legacyDatasets.contains(normalized) ? "daily|\(citation)" : "daily|\(normalized)|\(citation)"
  }
}

nonisolated enum ReadingEditionSelection {
  static let defaultsKey = "readingsEditionId"

  static func selected(_ preference: String, interfaceLanguage: String,
                       editions: [ReadingTextEdition]) -> ReadingTextEdition? {
    if !preference.isEmpty { return editions.first { $0.id == preference } }
    return editions.first { normalized($0.languageCode) == normalized(interfaceLanguage) }
  }

  private static func normalized(_ code: String) -> String {
    let base = code.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? ""
    switch base {
    case "iw": return "he"
    case "fil": return "tl"
    default: return base
    }
  }
}

nonisolated struct ReadingTextVerse: Decodable, Equatable, Sendable {
  let chapter: Int
  let verse: Int
  let text: String
  var transliteratedText: String? = nil
  var endVerse: Int? = nil
  var sourceNotes: [ScriptureSourceNote]? = nil

  var hasValidSourceNotes: Bool {
    guard let sourceNotes else { return true }
    return !sourceNotes.isEmpty && transliteratedText == nil
      && Set(sourceNotes.map(\.id)).count == sourceNotes.count
      && sourceNotes.allSatisfy { $0.isValid(in: text) }
      && Set(sourceNotes.compactMap { $0.position(in: text) }).count == sourceNotes.count
  }

  var verseLabel: String {
    if let endVerse, endVerse > verse { return "\(verse)–\(endVerse)" }
    return String(verse)
  }

  func contains(verse number: Int) -> Bool {
    number >= verse && number <= (endVerse ?? verse)
  }

  func displayedText(script: String, edition: ReadingTextEdition) -> String {
    if edition.supportsAramaicScriptChoice, script == edition.transliteratedTextScript,
       let transliteratedText { return transliteratedText }
    return text
  }
}

extension ReadingTextVerse {
  private enum CodingKeys: String, CodingKey { case chapter, verse, text, transliteratedText, endVerse, sourceNotes }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    chapter = try values.decode(Int.self, forKey: .chapter)
    verse = try values.decode(Int.self, forKey: .verse)
    text = try values.decode(String.self, forKey: .text)
    transliteratedText = try values.decodeIfPresent(String.self, forKey: .transliteratedText)
    endVerse = try values.decodeIfPresent(Int.self, forKey: .endVerse)
    sourceNotes = values.contains(.sourceNotes) ? try values.decode([ScriptureSourceNote].self, forKey: .sourceNotes) : nil
    if sourceNotes != nil && values.contains(.transliteratedText) {
      throw DecodingError.dataCorruptedError(forKey: .sourceNotes, in: values, debugDescription: "Paired source-note anchors are unsupported")
    }
  }
}

nonisolated struct ReadingTextEdition: Decodable, Equatable, Sendable {
  let id: String
  let languageCode: String
  let name: String
  let attribution: String
  let sourceURL: String
  var textScript: String? = nil
  var transliteratedTextScript: String? = nil

  var supportsAramaicScriptChoice: Bool {
    languageCode == "arc" && textScript == "Hebr" && transliteratedTextScript == "Syrc"
  }

  var sourceLink: URL? {
    guard let url = URL(string: sourceURL), url.scheme?.lowercased() == "https", url.host != nil else { return nil }
    return url
  }
}

nonisolated struct ReadingTextPassage: Equatable, Sendable {
  let edition: ReadingTextEdition
  let verses: [ReadingTextVerse]
  var includesWholeVerses = false
  var source: ReadingPassageSource? = nil

  /// Contiguous runs retain the reviewed appointment order, including chapter revisits.
  /// Unnumbered source blocks inherit the surrounding primary chapter only for layout.
  var sourceDisplays: [BibleDisplayChapter]? {
    guard let source, let blocks = source.contentBlocks, let first = verses.first else { return nil }
    let primaryChapters = Dictionary(grouping: verses, by: \.chapter).mapValues { units in
      BibleChapter(schemaVersion: 3, editionId: edition.id, book: source.book, chapter: units[0].chapter, verses: units)
    }
    let container = BibleChapter(schemaVersion: 3, editionId: edition.id, book: source.book,
      chapter: first.chapter, verses: verses, contentBlocks: blocks)
    guard let resolved = try? BibleDisplayChapter.resolve(container, primaryChapters: primaryChapters) else { return nil }
    var runs: [(number: Int, blocks: [BibleDisplayBlock])] = []
    for block in resolved.blocks {
      let number = block.unit?.chapter ?? runs.last?.number ?? first.chapter
      if runs.last?.number == number { runs[runs.count - 1].blocks.append(block) }
      else { runs.append((number, [block])) }
    }
    return runs.map { run in
      BibleDisplayChapter(chapter: BibleChapter(schemaVersion: 3, editionId: edition.id, book: source.book,
        chapter: run.number, verses: run.blocks.compactMap(\.unit)), blocks: run.blocks,
        loadedChapterNumbers: Set(primaryChapters.keys))
    }
  }
}

/// The source of a reviewed excerpt may differ from its citation's book and the
/// edition's base credit. Never infer this redirect from matching verse numbers.
nonisolated struct ReadingPassageSource: Decodable, Equatable, Sendable {
  let book: String
  let name: String
  let attribution: String
  let sourceURL: String
  let isComplete: Bool
  let contentBlocks: [BibleContentBlock]?
  private enum CodingKeys: String, CodingKey { case book, name, attribution, sourceURL, isComplete, contentBlocks }

  var sourceLink: URL? {
    guard let url = URL(string: sourceURL), url.scheme?.lowercased() == "https",
          let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
    return url
  }

  init(from decoder: Decoder) throws {
    try BibleStructureKey.validate(decoder, required: ["book", "name", "attribution", "sourceURL", "isComplete"], optional: ["contentBlocks"])
    let values = try decoder.container(keyedBy: CodingKeys.self)
    book = try values.decode(String.self, forKey: .book)
    name = try values.decode(String.self, forKey: .name)
    attribution = try values.decode(String.self, forKey: .attribution)
    sourceURL = try values.decode(String.self, forKey: .sourceURL)
    isComplete = try values.decode(Bool.self, forKey: .isComplete)
    contentBlocks = values.contains(.contentBlocks) ? try values.decode([BibleContentBlock].self, forKey: .contentBlocks) : nil
    guard book.range(of: "^[A-Z0-9]{3}$", options: .regularExpression) != nil,
          !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !attribution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          sourceLink != nil, contentBlocks.map({ !$0.isEmpty }) ?? true else { throw BibleStoreError.invalidArchive }
  }

  func isValid(verses: [ReadingTextVerse], edition: ReadingTextEdition) -> Bool {
    guard edition.transliteratedTextScript == nil, verses.allSatisfy({ $0.transliteratedText == nil }) else { return false }
    let addresses = verses.map { BibleBlockAddress(chapter: $0.chapter, verse: $0.verse, endVerse: $0.endVerse) }
    for (index, address) in addresses.enumerated() where addresses[..<index].contains(where: { $0.overlaps(address) }) { return false }
    guard let contentBlocks else { return true }
    guard Set(contentBlocks.map(\.id)).count == contentBlocks.count else { return false }
    let references = contentBlocks.filter { $0.kind == .verse }.map { BibleBlockAddress(chapter: $0.chapter!, verse: $0.verse!) }
    let starts = verses.map { BibleBlockAddress(chapter: $0.chapter, verse: $0.verse) }
    // Flat units and visible primary references must agree exactly, including order.
    guard references == starts else { return false }
    let notes = verses.flatMap { $0.sourceNotes ?? [] } + contentBlocks.flatMap { $0.sourceNotes ?? [] }
    return Set(notes.map(\.id)).count == notes.count
  }
}

nonisolated enum ReadingTextScript {
  static func resolved(override: String?, defaultScript: String) -> String {
    (override ?? defaultScript) == "Syrc" ? "Syrc" : "Hebr"
  }
}

nonisolated struct ReadingEditionManifest: Decodable, Sendable {
  let schemaVersion: Int
  let editions: [ReadingTextEdition]
}

/// Citations are resolved by the canonical importer. Native clients use the exact
/// original citation and context; localized labels are never parsed or used as keys.
nonisolated struct ReadingTextDataset: Decodable, Sendable {
  let schemaVersion: Int
  let editions: [ReadingTextEdition]
  let passages: [String: [String: [ReadingTextVerse]]]
  var wholeVersePassages: [String]? = nil
  var passageSources: [String: [String: ReadingPassageSource]]? = nil
  var passageBooks: [String: [String: String]]? = nil

  func availableEditions(citation: String, isTorah: Bool, datasetID: String? = nil) -> [ReadingTextEdition] {
    editions.filter { passage(citation: citation, isTorah: isTorah, editionID: $0.id, datasetID: datasetID) != nil }
  }

  func passage(citation: String, isTorah: Bool, editionID: String, datasetID: String? = nil) -> ReadingTextPassage? {
    guard schemaVersion == 1,
          let key = ReadingPassageIdentity.key(citation: citation, isTorah: isTorah, datasetID: datasetID),
          let edition = editions.first(where: { $0.id == editionID }),
          let verses = passages[key]?[editionID],
          !verses.isEmpty,
          verses.allSatisfy({ $0.chapter > 0 && $0.verse > 0 && ($0.endVerse ?? $0.verse) >= $0.verse
            && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.hasValidSourceNotes }),
          Set(verses.flatMap { $0.sourceNotes ?? [] }.map(\.id)).count == verses.reduce(0, { $0 + ($1.sourceNotes?.count ?? 0) }),
          edition.transliteratedTextScript == nil || verses.allSatisfy({ $0.sourceNotes == nil }),
          !edition.supportsAramaicScriptChoice || verses.allSatisfy({
            !($0.transliteratedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          })
    else { return nil }
    let source = passageSources?[key]?[editionID]
    guard source?.isValid(verses: verses, edition: edition) ?? true else { return nil }
    return ReadingTextPassage(edition: edition, verses: verses,
      includesWholeVerses: wholeVersePassages?.contains(key) == true, source: source)
  }
}

extension ReadingTextDataset {
  private enum CodingKeys: String, CodingKey { case schemaVersion, editions, passages, wholeVersePassages, passageSources, passageBooks }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
    editions = try values.decode([ReadingTextEdition].self, forKey: .editions)
    passages = try values.decode([String: [String: [ReadingTextVerse]]].self, forKey: .passages)
    wholeVersePassages = try values.decodeIfPresent([String].self, forKey: .wholeVersePassages)
    passageSources = values.contains(.passageSources) ? try values.decode([String: [String: ReadingPassageSource]].self, forKey: .passageSources) : nil
    passageBooks = values.contains(.passageBooks) ? try values.decode([String: [String: String]].self, forKey: .passageBooks) : nil
    if let passageBooks {
      guard passageBooks.allSatisfy({ key, books in
        passages[key] != nil && !books.isEmpty && books.allSatisfy { edition, book in
          passages[key]?[edition] != nil && book.range(of: "^[A-Z0-9]{3}$", options: .regularExpression) != nil
            && (passageSources?[key]?[edition].map { $0.book == book } ?? true)
        }
      }) else { throw BibleStoreError.invalidArchive }
    }
    if let passageSources {
      guard !passageSources.isEmpty, passageSources.allSatisfy({ key, sources in
        key.range(of: "^(daily|torah)\\|.+$", options: .regularExpression) != nil
          && !sources.isEmpty && sources.keys.allSatisfy { edition in
          editions.contains(where: { $0.id == edition }) && passages[key]?[edition] != nil
        }
      }) else { throw BibleStoreError.invalidArchive }
    }
  }
}

actor ReadingTextStore {
  static let shared = ReadingTextStore()
  private var dataset: ReadingTextDataset?
  private var editionList: [ReadingTextEdition]?
  private var hasLoaded = false
  private let resourceURL: URL?
  private let editionsURL: URL?
  private let bibleStore: BibleStore?

  init(resourceURL: URL? = Bundle.main.url(forResource: "readings-texts", withExtension: "json"),
       editionsURL: URL? = Bundle.main.url(forResource: "readings-editions", withExtension: "json"),
       bibleStore: BibleStore? = .shared) {
    self.resourceURL = resourceURL
    self.editionsURL = editionsURL
    self.bibleStore = bibleStore
  }

  func passage(citation: String, isTorah: Bool, editionID: String, datasetID: String? = nil) async -> ReadingTextPassage? {
    loadPassages()
    guard var passage = dataset?.passage(citation: citation, isTorah: isTorah, editionID: editionID, datasetID: datasetID),
          let key = ReadingPassageIdentity.key(citation: citation, isTorah: isTorah, datasetID: datasetID) else { return nil }
    if let book = dataset?.passageBooks?[key]?[editionID], let bibleStore,
       let verses = try? await bibleStore.reviewedPassage(editionID: editionID, book: book, expected: passage.verses) {
      passage = ReadingTextPassage(edition: passage.edition, verses: verses,
        includesWholeVerses: passage.includesWholeVerses, source: passage.source)
    }
    return passage
  }

  func availableEditions(citation: String, isTorah: Bool, datasetID: String? = nil) -> [ReadingTextEdition] {
    loadPassages()
    return dataset?.availableEditions(citation: citation, isTorah: isTorah, datasetID: datasetID) ?? []
  }

  private func loadPassages() {
    if !hasLoaded {
      hasLoaded = true
      if let resourceURL, let data = try? Data(contentsOf: resourceURL) {
        dataset = try? JSONDecoder().decode(ReadingTextDataset.self, from: data)
      }
    }
  }

  func editions() -> [ReadingTextEdition] {
    if let editionList { return editionList }
    if let editionsURL, let data = try? Data(contentsOf: editionsURL),
       let manifest = try? JSONDecoder().decode(ReadingEditionManifest.self, from: data),
       manifest.schemaVersion == 1 {
      editionList = manifest.editions
    } else { editionList = [] }
    return editionList ?? []
  }
}

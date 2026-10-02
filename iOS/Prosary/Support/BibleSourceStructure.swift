import Foundation

/// Version-three source structures are deliberately closed shapes. Unknown payloads
/// must fail installation rather than leave scripture silently undisplayed.
nonisolated struct BibleStructureKey: CodingKey {
  let stringValue: String
  var intValue: Int? { nil }
  init?(stringValue: String) { self.stringValue = stringValue }
  init?(intValue: Int) { return nil }

  static func validate(_ decoder: Decoder, required: Set<String>, optional: Set<String> = []) throws {
    let values = try decoder.container(keyedBy: Self.self)
    let keys = Set(values.allKeys.map(\.stringValue))
    guard required.isSubset(of: keys), keys.isSubset(of: required.union(optional)) else {
      throw BibleStoreError.invalidArchive
    }
  }
}

nonisolated struct BibleBlockAddress: Decodable, Hashable, Sendable {
  let chapter: Int
  let verse: Int
  let endVerse: Int?
  let part: String?
  private enum CodingKeys: String, CodingKey { case chapter, verse, endVerse, part }

  init(chapter: Int, verse: Int, endVerse: Int? = nil, part: String? = nil) {
    self.chapter = chapter; self.verse = verse; self.endVerse = endVerse; self.part = part
  }

  init(from decoder: Decoder) throws {
    try BibleStructureKey.validate(decoder, required: ["chapter", "verse"], optional: ["endVerse", "part"])
    let values = try decoder.container(keyedBy: CodingKeys.self)
    chapter = try values.decode(Int.self, forKey: .chapter)
    verse = try values.decode(Int.self, forKey: .verse)
    endVerse = values.contains(.endVerse) ? try values.decode(Int.self, forKey: .endVerse) : nil
    part = values.contains(.part) ? try values.decode(String.self, forKey: .part) : nil
    guard (1...1000).contains(chapter), (1...1000).contains(verse),
          (verse...1000).contains(endVerse ?? verse), part.map({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? true else {
      throw BibleStoreError.invalidArchive
    }
  }

  func overlaps(_ other: Self) -> Bool {
    chapter == other.chapter && verse <= (other.endVerse ?? other.verse) && other.verse <= (endVerse ?? verse)
  }

  var normalized: Self { Self(chapter: chapter, verse: verse, endVerse: endVerse ?? verse, part: part) }
}

nonisolated struct BibleAddressRoute: Codable, Hashable, Sendable {
  let chapter: Int
  let verse: Int
  let displayChapter: Int
  let blockId: String
  private enum CodingKeys: String, CodingKey { case chapter, verse, displayChapter, blockId }

  init(chapter: Int, verse: Int, displayChapter: Int, blockId: String) {
    self.chapter = chapter; self.verse = verse; self.displayChapter = displayChapter; self.blockId = blockId
  }

  init(from decoder: Decoder) throws {
    try BibleStructureKey.validate(decoder, required: ["chapter", "verse", "displayChapter", "blockId"])
    let values = try decoder.container(keyedBy: CodingKeys.self)
    chapter = try values.decode(Int.self, forKey: .chapter)
    verse = try values.decode(Int.self, forKey: .verse)
    displayChapter = try values.decode(Int.self, forKey: .displayChapter)
    blockId = try values.decode(String.self, forKey: .blockId)
    guard (1...1000).contains(chapter), (1...1000).contains(verse), (1...1000).contains(displayChapter),
          blockId.range(of: "^[a-z0-9][a-z0-9-]*$", options: .regularExpression) != nil else { throw BibleStoreError.invalidArchive }
  }
}

nonisolated struct BibleContentBlock: Decodable, Sendable {
  enum Kind: String, Decodable, Sendable { case verse, witness, passage, heading, colophon }
  let id: String
  let kind: Kind
  let chapter: Int?
  let verse: Int?
  let printedLabel: String?
  let text: String?
  let addresses: [BibleBlockAddress]?
  let sourceNotes: [ScriptureSourceNote]?
  private enum CodingKeys: String, CodingKey { case id, kind, chapter, verse, printedLabel, text, addresses, sourceNotes }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    kind = try values.decode(Kind.self, forKey: .kind)
    let required: Set<String>, optional: Set<String>
    switch kind {
    case .verse: required = ["id", "kind", "chapter", "verse"]; optional = ["printedLabel"]
    case .witness: required = ["id", "kind", "text", "printedLabel", "addresses"]; optional = ["sourceNotes"]
    case .passage, .colophon: required = ["id", "kind", "text"]; optional = ["sourceNotes"]
    case .heading: required = ["id", "kind", "text"]; optional = []
    }
    try BibleStructureKey.validate(decoder, required: required, optional: optional)
    id = try values.decode(String.self, forKey: .id)
    chapter = values.contains(.chapter) ? try values.decode(Int.self, forKey: .chapter) : nil
    verse = values.contains(.verse) ? try values.decode(Int.self, forKey: .verse) : nil
    printedLabel = values.contains(.printedLabel) ? try values.decode(String.self, forKey: .printedLabel) : nil
    text = values.contains(.text) ? try values.decode(String.self, forKey: .text) : nil
    addresses = values.contains(.addresses) ? try values.decode([BibleBlockAddress].self, forKey: .addresses) : nil
    sourceNotes = values.contains(.sourceNotes) ? try values.decode([ScriptureSourceNote].self, forKey: .sourceNotes) : nil
    guard id.range(of: "^[a-z0-9][a-z0-9-]*$", options: .regularExpression) != nil,
          chapter.map({ (1...1000).contains($0) }) ?? true, verse.map({ (1...1000).contains($0) }) ?? true,
          printedLabel.map({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? true,
          text.map({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? true,
          addresses.map({ !$0.isEmpty && Set($0.map(\.normalized)).count == $0.count }) ?? true else { throw BibleStoreError.invalidArchive }
    if let sourceNotes, let text {
      let unit = ReadingTextVerse(chapter: 1, verse: 1, text: text, sourceNotes: sourceNotes)
      guard unit.hasValidSourceNotes else { throw BibleStoreError.invalidArchive }
    }
  }
}

nonisolated struct BibleDisplayBlock: Identifiable, Sendable {
  let id: String
  let kind: BibleContentBlock.Kind
  let unit: ReadingTextVerse?
  let text: String
  let printedLabel: String?
  let addresses: [BibleBlockAddress]
  let sourceNotes: [ScriptureSourceNote]
  var isScripture: Bool { kind == .verse || kind == .witness || kind == .passage }
  var hasVerseChoice: Bool { kind == .verse || kind == .witness }
}

nonisolated struct BibleDisplayChapter: Sendable {
  let chapter: BibleChapter
  let blocks: [BibleDisplayBlock]
  let loadedChapterNumbers: Set<Int>
  var choices: [BibleDisplayBlock] { blocks.filter(\.hasVerseChoice) }

  func occurrence(of block: BibleDisplayBlock) -> Int? {
    guard block.kind == .witness else { return nil }
    let related = choices.filter { other in other.addresses.contains { a in block.addresses.contains { a.overlaps($0) } } }
    guard related.count > 1, let index = related.firstIndex(where: { $0.id == block.id }) else { return nil }
    return index + 1
  }

  static func resolve(_ chapter: BibleChapter, primaryChapters: [Int: BibleChapter]) throws -> Self {
    var rows: [BibleDisplayBlock] = []
    if let blocks = chapter.contentBlocks {
      for block in blocks {
        if block.kind == .verse {
          guard let number = block.chapter, let verse = block.verse,
                let unit = primaryChapters[number]?.verses.first(where: { $0.verse == verse }) else { throw BibleStoreError.invalidArchive }
          rows.append(BibleDisplayBlock(id: block.id, kind: .verse, unit: unit, text: unit.text,
            printedLabel: block.printedLabel, addresses: [.init(chapter: unit.chapter, verse: unit.verse, endVerse: unit.endVerse)], sourceNotes: unit.sourceNotes ?? []))
        } else {
          rows.append(BibleDisplayBlock(id: block.id, kind: block.kind, unit: nil, text: block.text!,
            printedLabel: block.printedLabel, addresses: block.addresses ?? [], sourceNotes: block.sourceNotes ?? []))
        }
      }
    } else {
      rows = chapter.verses.map { unit in
        BibleDisplayBlock(id: "primary-\(unit.chapter)-\(unit.verse)", kind: .verse, unit: unit, text: unit.text,
          printedLabel: nil, addresses: [.init(chapter: unit.chapter, verse: unit.verse, endVerse: unit.endVerse)], sourceNotes: unit.sourceNotes ?? [])
      }
    }
    return Self(chapter: chapter, blocks: rows, loadedChapterNumbers: Set(primaryChapters.keys))
  }
}

nonisolated struct BibleVerseTarget: Equatable, Sendable {
  let displayChapter: Int
  let blockId: String
}

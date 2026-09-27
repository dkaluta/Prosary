import Foundation

nonisolated struct ScriptureSourceNote: Decodable, Equatable, Identifiable, Sendable {
  enum Kind: String, Decodable, Sendable { case unreadablePoint }
  enum Mark: String, Decodable, Sendable { case vowel, dagesh }
  let id: String
  let kind: Kind
  let anchor: String
  let occurrence: Int
  let letterIndex: Int
  let mark: Mark
  let sourcePages: [Int]
  let sourceURL: String
  let retainedVowels: [String]?

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case id, kind, anchor, occurrence, letterIndex, mark, sourcePages, sourceURL, retainedVowels
  }
  private struct AnyKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
  }

  init(from decoder: Decoder) throws {
    let all = try decoder.container(keyedBy: AnyKey.self)
    let keys = Set(all.allKeys.map(\.stringValue))
    let required = Set(CodingKeys.allCases.map(\.rawValue)).subtracting([CodingKeys.retainedVowels.rawValue])
    guard keys == required || keys == required.union([CodingKeys.retainedVowels.rawValue]) else {
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid source-note fields"))
    }
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    kind = try values.decode(Kind.self, forKey: .kind)
    anchor = try values.decode(String.self, forKey: .anchor)
    occurrence = try values.decode(Int.self, forKey: .occurrence)
    letterIndex = try values.decode(Int.self, forKey: .letterIndex)
    mark = try values.decode(Mark.self, forKey: .mark)
    sourcePages = try values.decode([Int].self, forKey: .sourcePages)
    sourceURL = try values.decode(String.self, forKey: .sourceURL)
    retainedVowels = values.contains(.retainedVowels) ? try values.decode([String].self, forKey: .retainedVowels) : nil
  }

  var sourceLink: URL? {
    guard !sourceURL.contains(where: \.isWhitespace),
          let url = URL(string: sourceURL), url.scheme?.lowercased() == "https",
          let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
    return url
  }

  /// Scalar counting deliberately ignores niqqud, punctuation and Swift grapheme length.
  private var anchorLetterOffset: Int? {
    let scalars = Array(anchor.unicodeScalars)
    let positions = scalars.indices.filter { (0x05D0...0x05EA).contains(scalars[$0].value) }
    guard letterIndex > 0, letterIndex <= positions.count else { return nil }
    return positions[letterIndex - 1]
  }

  private static func letterScalars(in scalars: [Unicode.Scalar], at start: Int) -> [Unicode.Scalar] {
    var end = start + 1
    while end < scalars.count {
      switch scalars[end].properties.generalCategory {
      case .nonspacingMark, .spacingMark, .enclosingMark: end += 1
      default: return Array(scalars[start..<end])
      }
    }
    return Array(scalars[start..<end])
  }

  var affectedLetter: String? {
    anchorLetterOffset.map { String(String.UnicodeScalarView(Self.letterScalars(in: Array(anchor.unicodeScalars), at: $0))) }
  }

  struct Position: Hashable { let scalarOffset: Int; let mark: Mark }

  func position(in text: String) -> Position? {
    let source = Array(text.unicodeScalars), quote = Array(anchor.unicodeScalars)
    guard !quote.isEmpty, occurrence > 0, let letter = anchorLetterOffset else { return nil }
    var offset = 0, found = 0
    while offset + quote.count <= source.count {
      if source[offset..<(offset + quote.count)].elementsEqual(quote) {
        found += 1
        if found == occurrence { return Position(scalarOffset: offset + letter, mark: mark) }
        offset += quote.count
      } else { offset += 1 }
    }
    return nil
  }

  func isValid(in text: String) -> Bool {
    guard id.range(of: "^[a-z0-9][a-z0-9-]*$", options: .regularExpression) != nil,
          !anchor.isEmpty, occurrence > 0, sourceLink != nil,
          !sourcePages.isEmpty, sourcePages.allSatisfy({ $0 > 0 }),
          sourcePages == Array(Set(sourcePages)).sorted(), let position = position(in: text) else { return false }
    // Inspect the source, not only a shortened quote that might omit its trailing marks.
    let letters = Self.letterScalars(in: Array(text.unicodeScalars), at: position.scalarOffset)
    if mark == .dagesh {
      return retainedVowels == nil && !letters.contains { $0.value == 0x05BC }
    }
    func isVowel(_ scalar: Unicode.Scalar) -> Bool { (0x05B0...0x05BB).contains(scalar.value) || scalar.value == 0x05C7 }
    if let retainedVowels {
      guard retainedVowels.count == 1, retainedVowels[0].unicodeScalars.count == 1,
            retainedVowels[0].unicodeScalars.allSatisfy(isVowel) else { return false }
    }
    let actual = Set(letters.filter(isVowel).map { String($0) })
    return actual == Set(retainedVowels ?? [])
  }
}

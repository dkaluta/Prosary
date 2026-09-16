import Foundation

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

  func displayedText(script: String, edition: ReadingTextEdition) -> String {
    if edition.supportsAramaicScriptChoice, script == edition.transliteratedTextScript,
       let transliteratedText { return transliteratedText }
    return text
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

  func availableEditions(citation: String, isTorah: Bool) -> [ReadingTextEdition] {
    editions.filter { passage(citation: citation, isTorah: isTorah, editionID: $0.id) != nil }
  }

  func passage(citation: String, isTorah: Bool, editionID: String) -> ReadingTextPassage? {
    guard schemaVersion == 1,
          let edition = editions.first(where: { $0.id == editionID }),
          let verses = passages["\(isTorah ? "torah" : "daily")|\(citation)"]?[editionID],
          !verses.isEmpty,
          verses.allSatisfy({ $0.chapter > 0 && $0.verse > 0 && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
          !edition.supportsAramaicScriptChoice || verses.allSatisfy({
            !($0.transliteratedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          })
    else { return nil }
    return ReadingTextPassage(edition: edition, verses: verses,
      includesWholeVerses: wholeVersePassages?.contains("\(isTorah ? "torah" : "daily")|\(citation)") == true)
  }
}

actor ReadingTextStore {
  static let shared = ReadingTextStore()
  private var dataset: ReadingTextDataset?
  private var editionList: [ReadingTextEdition]?
  private var hasLoaded = false
  private let resourceURL: URL?
  private let editionsURL: URL?

  init(resourceURL: URL? = Bundle.main.url(forResource: "readings-texts", withExtension: "json"),
       editionsURL: URL? = Bundle.main.url(forResource: "readings-editions", withExtension: "json")) {
    self.resourceURL = resourceURL
    self.editionsURL = editionsURL
  }

  func passage(citation: String, isTorah: Bool, editionID: String) -> ReadingTextPassage? {
    loadPassages()
    return dataset?.passage(citation: citation, isTorah: isTorah, editionID: editionID)
  }

  func availableEditions(citation: String, isTorah: Bool) -> [ReadingTextEdition] {
    loadPassages()
    return dataset?.availableEditions(citation: citation, isTorah: isTorah) ?? []
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

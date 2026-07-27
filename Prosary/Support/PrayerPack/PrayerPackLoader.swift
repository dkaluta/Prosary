//
//  PrayerPackLoader.swift
//  Prosary
//
//  Loads the bundled .prosaryprayer packs (currently Rosary + Angelus — see
//  Shared/ARCHITECTURE.md's "Content bundles" section) and merges their content into
//  PrayerTranslations/MysteryTranslations as an override layer. PrayerKey/mystery imageKey
//  entries are a shared pool across devotions (e.g. "our_father" is used by Rosary, Angelus,
//  Franciscan Crown, Seven Sorrows, and Divine Mercy alike), so a pack can only ever add to the
//  hardcoded tables, never replace them wholesale — devotions without a shipped pack keep
//  resolving 100% from hardcoded source, unaffected.
//

import Foundation

private struct PackManifest: Decodable {
  let id: String
  let languages: [String]
  let hasCatalog: Bool
}

private struct PackContent: Decodable {
  let prayers: [String: String]
  let mysteries: [String: MysteryText]
}

/// Loaded lazily on first access and cached for the process lifetime — pack files are small
/// (a few KB of JSON; images are read on demand, not pre-extracted) so there's no benefit to
/// loading eagerly at launch.
@MainActor
enum PrayerPackStore {
  private static var prayerOverrides: [String: [PrayerKey: String]] = [:]
  private static var mysteryOverrides: [String: [String: MysteryText]] = [:]
  private static var imageDataByKey: [String: Data] = [:]
  private static var didLoad = false

  static func prayerOverride(languageCode: String, key: PrayerKey) -> String? {
    ensureLoaded()
    return prayerOverrides[languageCode]?[key]
  }

  static func mysteryOverride(languageCode: String, imageKey: String) -> MysteryText? {
    ensureLoaded()
    return mysteryOverrides[languageCode]?[imageKey]
  }

  static func imageData(for imageKey: String) -> Data? {
    ensureLoaded()
    return imageDataByKey[imageKey]
  }

  private static func ensureLoaded() {
    guard !didLoad else { return }
    didLoad = true

    for packName in ["rosary", "angelus"] {
      guard let url = Bundle.main.url(forResource: packName, withExtension: "prosaryprayer") else { continue }
      do {
        try load(packAt: url)
      } catch {
        assertionFailure("Failed to load \(packName).prosaryprayer: \(error)")
      }
    }
  }

  private static func load(packAt url: URL) throws {
    let data = try Data(contentsOf: url)
    let zip = try MinimalZipReader(data: data)

    let decoder = JSONDecoder()
    let manifest = try decoder.decode(PackManifest.self, from: zip.contents(of: "manifest.json"))

    for language in manifest.languages {
      let content = try decoder.decode(PackContent.self, from: zip.contents(of: "content/\(language).json"))

      var prayers = prayerOverrides[language] ?? [:]
      for (key, text) in content.prayers {
        guard let prayerKey = PrayerKey(rawValue: key) else { continue }
        prayers[prayerKey] = text
      }
      prayerOverrides[language] = prayers

      guard manifest.hasCatalog, !content.mysteries.isEmpty else { continue }
      var mysteries = mysteryOverrides[language] ?? [:]
      for (key, text) in content.mysteries {
        mysteries[key] = text
      }
      mysteryOverrides[language] = mysteries
    }

    for name in zip.fileNames() where name.hasPrefix("images/") {
      let imageKey = String(name.dropFirst("images/".count).dropLast(4))  // strip "images/" and ".jpg"
      imageDataByKey[imageKey] = try zip.contents(of: name)
    }
  }
}

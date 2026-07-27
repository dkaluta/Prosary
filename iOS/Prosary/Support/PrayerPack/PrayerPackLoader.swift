//
//  PrayerPackLoader.swift
//  Prosary
//
//  Loads the bundled .prosaryprayer packs (Rosary, Angelus, and any generic bundle-driven
//  devotion such as Trisagion — see Shared/ARCHITECTURE.md's "Content bundles" section) and
//  merges their content into PrayerTranslations/MysteryTranslations as an override layer.
//  PrayerKey/mystery imageKey entries are a shared pool across devotions (e.g. "our_father" is
//  used by Rosary, Angelus, Franciscan Crown, Seven Sorrows, and Divine Mercy alike), so a pack
//  can only ever add to the hardcoded tables, never replace them wholesale — devotions without a
//  shipped pack keep resolving 100% from hardcoded source, unaffected.
//
//  A bundle with a `steps.json` is a *generic devotion*: `PrayerKind.custom` + a
//  `customDevotionId` are the only engine/model plumbing it needs (see `PrayerEngine.
//  buildCustomDevotionSteps`) — its actual step sequence and per-step body text are entirely
//  data-driven from here, via `steps(for:)`/`resolveBodyText`.
//

import Foundation

private struct PackManifest: Decodable {
  let id: String
  let displayName: String
  let languages: [String]
  let hasCatalog: Bool
  let accentColorHex: String?
  let iconSystemName: String?
}

private struct PackContent: Decodable {
  let prayers: [String: String]
  let mysteries: [String: MysteryText]
}

private struct PackSteps: Decodable {
  let steps: [CustomDevotionStep]
}

/// One entry in a generic (bundle-driven) devotion's `steps.json` — see
/// `Shared/ARCHITECTURE.md`'s "Content bundles" section. `title` is a literal display string, not
/// a translation key, matching the existing convention that every devotion's step titles are
/// English-only UI labels. `bodyKey`/`imageKey` are resolved via `PrayerPackStore.resolveBodyText`
/// / the ordinary image-override lookup, exactly like a hardcoded devotion's `RosaryStep`.
struct CustomDevotionStep: Decodable {
  let title: String
  let bodyKey: String
  let imageKey: String
}

/// Metadata a generic devotion's Home card / Favorites row needs, sourced from its bundle's
/// `manifest.json` rather than any hardcoded per-kind table.
struct CustomDevotionInfo {
  let displayName: String
  let accentColorHex: String?
  let iconSystemName: String?
}

/// Loaded lazily on first access and cached for the process lifetime — pack files are small
/// (a few KB of JSON; images are read on demand, not pre-extracted) so there's no benefit to
/// loading eagerly at launch.
@MainActor
enum PrayerPackStore {
  private static var prayerOverrides: [String: [PrayerKey: String]] = [:]
  private static var mysteryOverrides: [String: [String: MysteryText]] = [:]
  private static var imageDataByKey: [String: Data] = [:]
  /// Unfiltered per-bundle content, keyed bundleId -> language -> raw key -> text — unlike
  /// `prayerOverrides`, this retains keys with no matching `PrayerKey` case (e.g.
  /// "trisagionAcclamation"), which is how a generic devotion's `steps.json` resolves bundle-local
  /// body text. See `resolveBodyText`.
  private static var rawContentByBundle: [String: [String: [String: String]]] = [:]
  private static var stepsByBundle: [String: [CustomDevotionStep]] = [:]
  private static var infoByBundle: [String: CustomDevotionInfo] = [:]
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

  /// The ordered step sequence for a generic (bundle-driven) devotion, e.g. `"trisagion"`. Empty
  /// for any bundle with no `steps.json` (Rosary/Angelus, which stay hardcoded).
  static func steps(for bundleId: String) -> [CustomDevotionStep] {
    ensureLoaded()
    return stepsByBundle[bundleId] ?? []
  }

  /// Every loaded bundle id that has a `steps.json` — i.e. every generic devotion discovered at
  /// load time, without hardcoding devotion names anywhere in view code.
  static func customDevotionIds() -> [String] {
    ensureLoaded()
    return Array(stepsByBundle.keys)
  }

  static func info(for bundleId: String) -> CustomDevotionInfo? {
    ensureLoaded()
    return infoByBundle[bundleId]
  }

  /// Resolves a `steps.json` entry's `bodyKey` to display text: (1) the bundle's own raw content
  /// for this key, if present — this is how bundle-local-only keys (e.g. "trisagionAcclamation")
  /// resolve; (2) else, if the key happens to match an existing `PrayerKey` case, the ordinary
  /// hardcoded/override lookup — this is how shared "main" keys (e.g. "gloriaPatri") resolve; (3)
  /// else the raw key string, matching `PrayerTranslations.get`'s own last-resort fallback.
  static func resolveBodyText(bundleId: String, languageCode: String?, key: String) -> String {
    ensureLoaded()
    if let languageCode, let text = rawContentByBundle[bundleId]?[languageCode]?[key] {
      return text
    }
    if let prayerKey = PrayerKey(rawValue: key) {
      return PrayerTranslations.get(languageCode: languageCode, key: prayerKey)
    }
    return key
  }

  private static func ensureLoaded() {
    guard !didLoad else { return }
    didLoad = true

    for packName in ["rosary", "angelus", "trisagion"] {
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

    infoByBundle[manifest.id] = CustomDevotionInfo(
      displayName: manifest.displayName, accentColorHex: manifest.accentColorHex,
      iconSystemName: manifest.iconSystemName)

    for language in manifest.languages {
      let content = try decoder.decode(PackContent.self, from: zip.contents(of: "content/\(language).json"))

      var rawContent = rawContentByBundle[manifest.id]?[language] ?? [:]
      var prayers = prayerOverrides[language] ?? [:]
      for (key, text) in content.prayers {
        rawContent[key] = text
        guard let prayerKey = PrayerKey(rawValue: key) else { continue }
        prayers[prayerKey] = text
      }
      rawContentByBundle[manifest.id, default: [:]][language] = rawContent
      prayerOverrides[language] = prayers

      guard manifest.hasCatalog, !content.mysteries.isEmpty else { continue }
      var mysteries = mysteryOverrides[language] ?? [:]
      for (key, text) in content.mysteries {
        mysteries[key] = text
      }
      mysteryOverrides[language] = mysteries
    }

    if zip.fileNames().contains("steps.json") {
      let parsedSteps = try decoder.decode(PackSteps.self, from: zip.contents(of: "steps.json"))
      stepsByBundle[manifest.id] = parsedSteps.steps
    }

    for name in zip.fileNames() where name.hasPrefix("images/") {
      let imageKey = String(name.dropFirst("images/".count).dropLast(4))  // strip "images/" and ".jpg"
      imageDataByKey[imageKey] = try zip.contents(of: name)
    }
  }
}

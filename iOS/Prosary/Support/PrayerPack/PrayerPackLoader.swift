//
//  PrayerPackLoader.swift
//  Prosary
//
//  Loads the bundled .prosaryprayer packs (Rosary, Angelus, and every generic bundle-driven
//  devotion — see Shared/ARCHITECTURE.md's "Content bundles" section) and merges their content
//  into PrayerTranslations/MysteryTranslations as an override layer. PrayerKey/mystery imageKey
//  entries are a shared pool across devotions (e.g. "our_father" is used by Rosary and several
//  bundle devotions alike), so a pack can only ever add to the hardcoded tables, never replace
//  them wholesale.
//
//  A bundle with a `devotion.json` is a *generic devotion*: `PrayerKind.custom` + a
//  `customDevotionId` are the only engine/model plumbing it needs (see `PrayerEngine.
//  buildCustomDevotionSteps`) — its step sequence (flat "steps" type, or decade/bead-structured
//  "rosary" type) and per-step body text are entirely data-driven from here, via
//  `definition(for:)`/`resolveBodyText`.
//

import Foundation

private struct PackManifest: Decodable {
  let id: String
  let displayName: String
  let languages: [String]
  let hasCatalog: Bool
  let accentColorHex: String?
  let accentColorDarkHex: String?
  let iconSystemName: String?
  let displayNameByLanguage: [String: String]?
  let reminderBody: [String: String]?
  let reminderPresetHours: [Int]?
  let reminderPresetFooter: [String: String]?
}

private struct PackContent: Decodable {
  let prayers: [String: String]
  let mysteries: [String: MysteryText]
}

/// One entry in a generic devotion's `devotion.json` — a step of the flat "steps" type, an
/// opening/closing step of the "rosary" type, or (closing only) a `kind`-tagged special step.
/// `title` is a literal display string (the app-wide convention that step titles are English-only
/// UI labels); `titleKey` is the alternative for devotions whose step titles are themselves
/// translated content (e.g. the Stations' station names). `repeat` expands into n steps titled
/// "Title (h of n)" — deliberately without bead fields, matching the hardcoded devotions'
/// closing Hail Marys.
struct CustomDevotionStep: Decodable {
  let title: String?
  let titleKey: String?
  let subtitle: String?
  let bodyKey: String?
  let imageKey: String?
  let repeatCount: Int?
  let kind: SpecialKind?

  enum SpecialKind: String, Decodable {
    /// The seasonal Marian antiphon (Franciscan Crown) — calendar-dependent, so it stays
    /// runtime-composed by the engine's shared antiphon builder rather than data-driven.
    case seasonalMarianAntiphon
  }

  private enum CodingKeys: String, CodingKey {
    case title, titleKey, subtitle, bodyKey, imageKey, kind
    case repeatCount = "repeat"
  }
}

/// Parsed `devotion.json` — the complete structural description of a generic devotion.
/// Field validity per type is enforced at authoring time by `Shared/tools/validate-devotion.py`;
/// the decoder is deliberately lenient (all optionals) so the engine can switch on `type` alone.
struct CustomDevotionDefinition: Decodable {
  enum DevotionType: String, Decodable {
    /// A flat, fixed step list (Angelus, Stations, Trisagion).
    case steps
    /// A decade/bead-structured devotion (Franciscan Crown, Seven Sorrows, Divine Mercy).
    case rosary
  }

  struct Decades: Decodable {
    /// "Joy" / "Sorrow" / "Decade" — combined with the engine's ordinal array into "1st Joy" etc.
    let ordinalNoun: String
    /// True: each decade opens with an announcement step whose title/body come from the mystery
    /// text of that decade's catalog entry (via the merged MysteryTranslations path).
    let announceMystery: Bool
    /// Per-decade catalog (Franciscan Crown/Seven Sorrows). Mutually exclusive with
    /// `count`+`fixedImageKey` (Divine Mercy).
    let entries: [CatalogEntry]?
    let count: Int?
    let fixedImageKey: String?
    let majorStep: FixedStep
    let minorStep: FixedStep
    let minorCount: Int

    struct CatalogEntry: Decodable {
      let imageKey: String
      /// Announcement steps are scripture by default; the one traditional non-Gospel scene
      /// (the Seven Sorrows' meeting on the way) opts out.
      let isScripture: Bool?
    }

    struct FixedStep: Decodable {
      let title: String
      let bodyKey: String
    }
  }

  let type: DevotionType
  // steps type
  let steps: [CustomDevotionStep]?
  /// Whole-sequence swap during Eastertide (the Angelus → Regina Caeli substitution).
  let eastertideSteps: [CustomDevotionStep]?
  // rosary type
  let opening: [CustomDevotionStep]?
  let decades: Decades?
  let closing: [CustomDevotionStep]?
  let hasClosingCross: Bool?
}

/// Metadata a generic devotion's Home card / Favorites row / reminders need, sourced from its
/// bundle's `manifest.json` rather than any hardcoded per-kind table.
struct CustomDevotionInfo {
  let displayName: String
  let accentColorHex: String?
  let accentColorDarkHex: String?
  let iconSystemName: String?
  let displayNameByLanguage: [String: String]
  let reminderBody: [String: String]
  let reminderPresetHours: [Int]?
  let reminderPresetFooter: [String: String]

  /// The display name in the app's active UI localization (falling back to the manifest's
  /// base `displayName`) — preserves e.g. the Hebrew devotion names that used to live in
  /// Localizable.xcstrings.
  var localizedDisplayName: String {
    guard let uiLanguage = Bundle.main.preferredLocalizations.first?.prefix(2) else { return displayName }
    return displayNameByLanguage[String(uiLanguage)] ?? displayName
  }

  var localizedReminderBody: String? {
    guard let uiLanguage = Bundle.main.preferredLocalizations.first?.prefix(2) else {
      return reminderBody["en"]
    }
    return reminderBody[String(uiLanguage)] ?? reminderBody["en"]
  }

  var localizedReminderPresetFooter: String? {
    guard let uiLanguage = Bundle.main.preferredLocalizations.first?.prefix(2) else {
      return reminderPresetFooter["en"]
    }
    return reminderPresetFooter[String(uiLanguage)] ?? reminderPresetFooter["en"]
  }
}

/// Loaded lazily on first access and cached for the process lifetime — pack files are small
/// (a few KB of JSON; images are read on demand, not pre-extracted) so there's no benefit to
/// loading eagerly at launch.
@MainActor
enum PrayerPackStore {
  /// Load order — also the display order of generic-devotion cards/rows (Home, Favorites), so
  /// this list is deliberately an ordered array, never a dictionary's unordered keys.
  private static let packNames = ["rosary", "angelus", "trisagion"]

  private static var prayerOverrides: [String: [PrayerKey: String]] = [:]
  private static var mysteryOverrides: [String: [String: MysteryText]] = [:]
  private static var imageDataByKey: [String: Data] = [:]
  /// Unfiltered per-bundle content, keyed bundleId -> language -> raw key -> text — unlike
  /// `prayerOverrides`, this retains keys with no matching `PrayerKey` case (e.g.
  /// "trisagionAcclamation"), which is how a generic devotion's `devotion.json` resolves
  /// bundle-local body text. See `resolveBodyText`.
  private static var rawContentByBundle: [String: [String: [String: String]]] = [:]
  private static var definitionByBundle: [String: CustomDevotionDefinition] = [:]
  /// Bundle ids with a devotion.json, in pack-load order.
  private static var orderedCustomIds: [String] = []
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

  /// The parsed `devotion.json` for a generic (bundle-driven) devotion, e.g. `"trisagion"`.
  /// Nil for any bundle without one (Rosary/Angelus while they remain override-only).
  static func definition(for bundleId: String) -> CustomDevotionDefinition? {
    ensureLoaded()
    return definitionByBundle[bundleId]
  }

  /// Every loaded bundle id that has a `devotion.json` — i.e. every generic devotion discovered
  /// at load time, in pack-load order, without hardcoding devotion names anywhere in view code.
  static func customDevotionIds() -> [String] {
    ensureLoaded()
    return orderedCustomIds
  }

  static func info(for bundleId: String) -> CustomDevotionInfo? {
    ensureLoaded()
    return infoByBundle[bundleId]
  }

  /// Resolves a `devotion.json` entry's `bodyKey`/`titleKey` to display text: (1) the bundle's
  /// own raw content for this key, if present — this is how bundle-local-only keys (e.g.
  /// "trisagionAcclamation") resolve; (2) else, if the key happens to match an existing
  /// `PrayerKey` case, the ordinary hardcoded/override lookup — this is how shared "main" keys
  /// (e.g. "gloriaPatri") resolve; (3) else the raw key string, matching
  /// `PrayerTranslations.get`'s own last-resort fallback.
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

    for packName in packNames {
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
      displayName: manifest.displayName,
      accentColorHex: manifest.accentColorHex,
      accentColorDarkHex: manifest.accentColorDarkHex,
      iconSystemName: manifest.iconSystemName,
      displayNameByLanguage: manifest.displayNameByLanguage ?? [:],
      reminderBody: manifest.reminderBody ?? [:],
      reminderPresetHours: manifest.reminderPresetHours,
      reminderPresetFooter: manifest.reminderPresetFooter ?? [:])

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

      // Mysteries merge whenever a bundle ships any — `hasCatalog` strictly means "has a
      // catalog.json authoring file" (the Rosary), not "may contribute mystery text": generic
      // rosary-type devotions (Seven Sorrows, Franciscan Crown) ship their per-decade texts in
      // the mysteries map without any catalog.json.
      guard !content.mysteries.isEmpty else { continue }
      var mysteries = mysteryOverrides[language] ?? [:]
      for (key, text) in content.mysteries {
        mysteries[key] = text
      }
      mysteryOverrides[language] = mysteries
    }

    if zip.fileNames().contains("devotion.json") {
      let definition = try decoder.decode(CustomDevotionDefinition.self, from: zip.contents(of: "devotion.json"))
      definitionByBundle[manifest.id] = definition
      orderedCustomIds.append(manifest.id)
    }

    for name in zip.fileNames() where name.hasPrefix("images/") {
      let imageKey = String(name.dropFirst("images/".count).dropLast(4))  // strip "images/" and ".jpg"
      imageDataByKey[imageKey] = try zip.contents(of: name)
    }
  }
}

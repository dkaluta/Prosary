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
  let isScripture: Bool?
  /// Gates this entry on one of the bundle's `options.json` options: `"key"` (toggle on),
  /// `"!key"` (toggle off), or `"key=caseId"` (choice equals) — see
  /// `PrayerEngine.evaluateCondition`. Nil = always included.
  let condition: String?
  let kind: SpecialKind?

  enum SpecialKind: String, Decodable {
    /// The seasonal Marian antiphon (Franciscan Crown) — calendar-dependent, so it stays
    /// runtime-composed by the engine's shared antiphon builder rather than data-driven.
    case seasonalMarianAntiphon
  }

  private enum CodingKeys: String, CodingKey {
    case title, titleKey, subtitle, bodyKey, imageKey, isScripture, kind
    case repeatCount = "repeat"
    case condition = "if"
  }
}

/// One user-configurable setting a bundle declares in its `options.json` — a toggle or a
/// multi-case choice. Entry-level `"if"` expressions gate steps on the resulting values; the
/// favorite's choices persist in `Prayer.customOptions` (only overrides — an absent key means
/// this option's `defaultValue`). Structure is enforced at authoring time by
/// `Shared/tools/validate-devotion.py`.
struct CustomDevotionOption: Decodable {
  enum Kind: String, Decodable {
    case toggle, choice
  }

  struct Case: Decodable {
    let id: String
    let name: String
    let nameByLanguage: [String: String]?

    var localizedName: String {
      guard let uiLanguage = Bundle.main.preferredLocalizations.first?.prefix(2) else { return name }
      return nameByLanguage?[String(uiLanguage)] ?? name
    }
  }

  let key: String
  let kind: Kind
  /// English UI label; `nameByLanguage` overrides it per UI localization.
  let name: String
  let nameByLanguage: [String: String]?
  /// Canonical string form of the authored `default`: "true"/"false" for a toggle, a case id
  /// for a choice — the same encoding `Prayer.customOptions` stores.
  let defaultValue: String
  let cases: [Case]?

  var localizedName: String {
    guard let uiLanguage = Bundle.main.preferredLocalizations.first?.prefix(2) else { return name }
    return nameByLanguage?[String(uiLanguage)] ?? name
  }

  private enum CodingKeys: String, CodingKey {
    case key, kind, name, nameByLanguage, cases
    case defaultValue = "default"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    key = try container.decode(String.self, forKey: .key)
    kind = try container.decode(Kind.self, forKey: .kind)
    name = try container.decode(String.self, forKey: .name)
    nameByLanguage = try container.decodeIfPresent([String: String].self, forKey: .nameByLanguage)
    cases = try container.decodeIfPresent([Case].self, forKey: .cases)
    if let flag = try? container.decode(Bool.self, forKey: .defaultValue) {
      defaultValue = flag ? "true" : "false"
    } else {
      defaultValue = try container.decode(String.self, forKey: .defaultValue)
    }
  }
}

private struct PackOptions: Decodable {
  let options: [CustomDevotionOption]
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

  /// One named alternate step-set of a steps-type devotion (e.g. the Stations' traditional vs.
  /// scriptural forms). The first variant is the default.
  struct Variant: Decodable {
    let id: String
    /// English UI label (the app-wide step-title convention); `nameByLanguage` overrides it per
    /// UI localization, mirroring the manifest's `displayNameByLanguage`.
    let name: String
    let nameByLanguage: [String: String]?
    let steps: [CustomDevotionStep]
    let eastertideSteps: [CustomDevotionStep]?

    var localizedName: String {
      guard let uiLanguage = Bundle.main.preferredLocalizations.first?.prefix(2) else { return name }
      return nameByLanguage?[String(uiLanguage)] ?? name
    }
  }

  let type: DevotionType
  // steps type
  let steps: [CustomDevotionStep]?
  /// Whole-sequence swap during Eastertide (the Angelus → Regina Caeli substitution).
  let eastertideSteps: [CustomDevotionStep]?
  /// Alternate step-sets (steps type only), mutually exclusive with `steps`. Nil for
  /// single-form devotions.
  let variants: [Variant]?
  // rosary type
  let opening: [CustomDevotionStep]?
  let decades: Decades?
  let closing: [CustomDevotionStep]?
  let hasClosingCross: Bool?

  /// The step lists to build for `variantId` — the matching variant, else the default (first)
  /// variant, else the top-level lists (single-form devotions).
  func resolvedSteps(variantId: String?) -> (steps: [CustomDevotionStep], eastertideSteps: [CustomDevotionStep]?) {
    if let variants, !variants.isEmpty {
      let variant = variants.first { $0.id == variantId } ?? variants[0]
      return (variant.steps, variant.eastertideSteps)
    }
    return (steps ?? [], eastertideSteps)
  }
}

/// Metadata a generic devotion's Home card / Favorites row / reminders need, sourced from its
/// bundle's `manifest.json` rather than any hardcoded per-kind table.
struct CustomDevotionInfo {
  let displayName: String
  /// The languages this bundle ships content for (manifest `languages`).
  let languages: [String]
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
  /// this list is deliberately an ordered array, never a dictionary's unordered keys. The rosary
  /// pack loads first so its shared mystery texts/images are the base other bundles build on.
  private static let packNames = [
    "rosary", "angelus", "stationsOfTheCross", "franciscanCrown", "sevenSorrows",
    "divineMercyChaplet", "trisagion",
  ]

  private static var prayerOverrides: [String: [PrayerKey: String]] = [:]
  private static var mysteryOverrides: [String: [String: MysteryText]] = [:]
  private static var imageDataByKey: [String: Data] = [:]
  /// Unfiltered per-bundle content, keyed bundleId -> language -> raw key -> text — unlike
  /// `prayerOverrides`, this retains keys with no matching `PrayerKey` case (e.g.
  /// "trisagionAcclamation"), which is how a generic devotion's `devotion.json` resolves
  /// bundle-local body text. See `resolveBodyText`.
  private static var rawContentByBundle: [String: [String: [String: String]]] = [:]
  private static var definitionByBundle: [String: CustomDevotionDefinition] = [:]
  private static var optionsByBundle: [String: [CustomDevotionOption]] = [:]
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
  /// The options a bundle's `options.json` declares, in authored order (the editor's display
  /// order). Empty for bundles without one.
  static func options(for bundleId: String) -> [CustomDevotionOption] {
    ensureLoaded()
    return optionsByBundle[bundleId] ?? []
  }

  static func customDevotionIds() -> [String] {
    ensureLoaded()
    return orderedCustomIds
  }

  static func info(for bundleId: String) -> CustomDevotionInfo? {
    ensureLoaded()
    return infoByBundle[bundleId]
  }

  /// Resolves a `devotion.json` entry's `bodyKey`/`titleKey` to display text: (1) the bundle's
  /// own raw content for this key — the requested language, else the bundle's Latin (mirroring
  /// `PrayerTranslations.get`'s Latin fallback, so e.g. the sentinel/unknown language prays in
  /// Latin, not raw keys); (2) else, if the key happens to match an existing `PrayerKey` case,
  /// the ordinary hardcoded/override lookup — this is how shared "main" keys (e.g. "gloriaPatri")
  /// resolve; (3) else the raw key string, matching `PrayerTranslations.get`'s own last resort.
  static func resolveBodyText(bundleId: String, languageCode: String?, key: String) -> String {
    ensureLoaded()
    if let languageCode, let text = rawContentByBundle[bundleId]?[languageCode]?[key] {
      return text
    }
    if let latinText = rawContentByBundle[bundleId]?["la"]?[key] {
      return latinText
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
      languages: manifest.languages,
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

    if zip.fileNames().contains("options.json") {
      optionsByBundle[manifest.id] =
        try decoder.decode(PackOptions.self, from: zip.contents(of: "options.json")).options
    }

    for name in zip.fileNames() where name.hasPrefix("images/") {
      let imageKey = String(name.dropFirst("images/".count).dropLast(4))  // strip "images/" and ".jpg"
      imageDataByKey[imageKey] = try zip.contents(of: name)
    }
  }
}

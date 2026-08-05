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
  /// Set ("rosary") when this bundle's devotion.json backs a dedicated PrayerKind rather than
  /// a generic .custom devotion — the definition loads, but the bundle stays out of
  /// `customDevotionIds()` so Home/Favorites don't list it twice.
  let builtinKind: String?
  let displayName: String
  let languages: [String]
  let hasCatalog: Bool
  let accentColorHex: String?
  let accentColorDarkHex: String?
  let iconSystemName: String?
  /// One grapheme (letter or emoji) drawn as the icon instead of `iconSystemName` — the
  /// Compose "your own" icon (v0.7, Gamaliel item 6).
  let iconGlyph: String?
  let displayNameByLanguage: [String: String]?
  let reminderBody: [String: String]?
  let reminderPresetHours: [Int]?
  let reminderPresetFooter: [String: String]?
  let tags: [String]?
}

private struct PackContent: Decodable {
  let prayers: [String: String]
  let mysteries: [String: MysteryText]
  /// Optional reading aid (v0.7): prayer key → the same text in another script.
  let transliterations: [String: String]?
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
  /// Like `titleKey` for the subtitle — for subtitles that are themselves translated content
  /// (the Rosary's opening Hail Marys "for Faith/Hope/Charity"). Mutually exclusive with the
  /// literal `subtitle`.
  let subtitleKey: String?
  let bodyKey: String?
  /// Resolved like `bodyKey`; emitted as the step's regular-typeface acclamation above the
  /// body (the Stations' versicle/response).
  let acclamationKey: String?
  let imageKey: String?
  let repeatCount: Int?
  let isScripture: Bool?
  /// Per-language override of `isScripture` — for bodies that are quoted scripture in some
  /// languages but composed prose in others (the traditional Stations: Liguori meditations in
  /// la/en, scripture meditations in ar/he/ru/tl).
  let isScriptureByLanguage: [String: Bool]?
  /// Gates this entry on one of the bundle's `options.json` options: `"key"` (toggle on),
  /// `"!key"` (toggle off), or `"key=caseId"` (choice equals) — see
  /// `PrayerEngine.evaluateCondition`. Nil = always included.
  let condition: String?
  let kind: SpecialKind?
  /// For `kind == .marianAntiphon`: the choice option whose value names the antiphon to build
  /// ("seasonal" resolves via the liturgical calendar, "none" drops the step).
  let optionKey: String?

  enum SpecialKind: String, Decodable {
    /// The seasonal Marian antiphon (Franciscan Crown) — calendar-dependent, so it stays
    /// runtime-composed by the engine's shared antiphon builder rather than data-driven.
    case seasonalMarianAntiphon
    /// An option-selected Marian antiphon (the Rosary) — `optionKey` names a choice option
    /// whose cases are antiphon ids plus "seasonal" and "none".
    case marianAntiphon
  }

  private enum CodingKeys: String, CodingKey {
    case title, titleKey, subtitle, subtitleKey, bodyKey, acclamationKey, imageKey, isScripture, isScriptureByLanguage, kind, optionKey
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

/// One narrated recording a bundle declares in its `audio.json` (an optional bundle file, staged
/// by both packers like options.json — see Shared/ARCHITECTURE.md's "Audio").
/// AudioPlaybackController plays these through the prayer flow's transport bar — metadata loads
/// eagerly here, bytes are served on demand via `PrayerPackStore.audioData` and extracted to a
/// cache file at load. Files are Ogg Opus (RFC 7845, `.opus`) under the bundle's `audio/` directory;
/// structure is enforced at authoring time by `Shared/tools/validate-devotion.py`.
struct DevotionAudioTrack: Decodable {
  /// One seek point. `start` is seconds from the track's beginning (the first chapter starts at
  /// 0, starts strictly increase); `title` XOR `titleKey` per the step-entry convention
  /// (`titleKey` resolves through the track language's ordinary content chain); `stepIndex` is
  /// an *advisory* link into the built default-options step sequence — the built sequence is
  /// option/calendar-dependent, so the playback UI treats it as a step-syncing hint,
  /// never an invariant.
  struct Chapter: Decodable {
    let start: Double
    let title: String?
    let titleKey: String?
    let stepIndex: Int?
  }

  /// Unique within the bundle — what a persisted playback position would key against (persistence itself is future work).
  let id: String
  /// The single language this recording is in (one of the manifest's languages).
  let language: String
  /// Bundle-relative path, always `audio/<name>.opus`.
  let file: String
  /// The steps-type variant this recording follows (a traditional vs. scriptural Stations
  /// recording differ). Nil for single-form devotions.
  let variantId: String?
  /// English UI label; `nameByLanguage` overrides it per UI localization. Nil = platforms label
  /// the track by its language.
  let name: String?
  let nameByLanguage: [String: String]?
  let chapters: [Chapter]

  var localizedName: String? {
    guard let uiLanguage = Bundle.main.preferredLocalizations.first?.prefix(2) else { return name }
    return nameByLanguage?[String(uiLanguage)] ?? name
  }
}

private struct PackAudio: Decodable {
  let tracks: [DevotionAudioTrack]
}

/// Parsed `devotion.json` — the complete structural description of a generic devotion.
/// Field validity per type is enforced at authoring time by `Shared/tools/validate-devotion.py`;
/// the decoder is deliberately lenient (all optionals) so the engine can switch on `type` alone.
struct CustomDevotionDefinition: Decodable {
  enum DayProgression: String, Decodable {
    case series, free
  }

  enum DevotionType: String, Decodable {
    /// A flat, fixed step list (Angelus, Stations, Trisagion).
    case steps
    /// A decade/bead-structured devotion (Franciscan Crown, Seven Sorrows, Divine Mercy).
    case rosary
    /// A multi-day devotion (novenas, the 33-day Montfort consecration): one step list per
    /// day, with optional shared opening/closing prayed every day. The engine builds one day's
    /// sequence per session; per-favorite day progress is a planned follow-up (see
    /// ARCHITECTURE.md's "Multi-day devotions" section) — until it lands, sessions pray day 1.
    case days
  }

  /// One day of a days-type devotion.
  struct Day: Decodable {
    /// English UI label ("Day 1", "Feast of the Consecration"); `nameByLanguage` overrides it
    /// per UI localization.
    let name: String
    let nameByLanguage: [String: String]?
    /// Optional grouping label for the Montfort-style structure ("First Week: Knowledge of
    /// Self"), shown as period context by the day picker.
    let period: String?
    let steps: [CustomDevotionStep]

    var localizedName: String {
      guard let uiLanguage = Bundle.main.preferredLocalizations.first?.prefix(2) else { return name }
      return nameByLanguage?[String(uiLanguage)] ?? name
    }
  }

  struct Decades: Decodable {
    /// "Joy" / "Sorrow" / "Decade" — combined with the engine's ordinal array into "1st Joy" etc.
    /// The noun a decade is counted in — a literal, or a key so it reads in the language
    /// being prayed ("Mystery" / "רז" / "Тайна").
    let ordinalNoun: String?
    let ordinalNounKey: String?
    /// True: each decade opens with an announcement step whose title/body come from the mystery
    /// text of that decade's catalog entry (via the merged MysteryTranslations path).
    let announceMystery: Bool
    /// "mysteryGroups" (the Rosary): the decade catalog is resolved at build time from the
    /// engine's mystery-group machinery (RosaryOptions selection mode + liturgical calendar,
    /// group-labelled ordinals, single-mystery true ordinal) instead of `entries`/`count` —
    /// steps carry real `Mystery` values so the flow renders exactly as the hardcoded builder
    /// did. Nil for bundle-cataloged devotions.
    let source: String?
    /// Per-decade catalog (Franciscan Crown/Seven Sorrows). Mutually exclusive with
    /// `count`+`fixedImageKey` (Divine Mercy) and with `source`.
    let entries: [CatalogEntry]?
    let count: Int?
    let fixedImageKey: String?
    let majorStep: FixedStep
    let minorStep: FixedStep
    let minorCount: Int
    /// Entries emitted after each decade's minors, carrying the decade's subtitle/index (the
    /// Rosary's Glory Be / Fatima Prayer / per-decade eternal rest), each usually gated with
    /// an `"if"`.
    let postMinor: [CustomDevotionStep]?
    /// Presenter-mode alternate decade tail: when the gating option is on, the minors (and any
    /// postMinor entry gated `"!presenterMode"`) collapse into one combined step with
    /// `hailMaryIndexInDecade = minorCount` so the bead track still renders a full decade.
    let presenter: Presenter?

    struct CatalogEntry: Decodable {
      let imageKey: String
      /// Announcement steps are scripture by default; the one traditional non-Gospel scene
      /// (the Seven Sorrows' meeting on the way) opts out.
      let isScripture: Bool?
    }

    struct FixedStep: Decodable {
      /// A decade's Our Father/Hail Mary heading — carries a literal title or a translatable titleKey, exactly like every other step,
      /// so it reads in the language being prayed.
      let title: String?
      let titleKey: String?
      let bodyKey: String
      /// Fixed illustration for this step (the Rosary's Our Father icon between
      /// mystery-specific images). Nil = the decade's own image.
      let imageKey: String?
    }

    struct Presenter: Decodable {
      let combinedTitle: String?
      let combinedTitleKey: String?
      /// Bodies joined with a blank line (Hail Mary + Glory Be).
      let bodyKeys: [String]
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
  // days type
  let days: [Day]?
  /// How the days relate: a series is worked through on consecutive days (a novena, a triduum,
  /// a 33-day consecration) and gets a tracked run; "free" days are a set to pick from, like a
  /// prayer for each day of the week, where there is nothing to be behind on. Absent means
  /// series — a numbered list of days is sequential unless its author says otherwise.
  let dayProgression: DayProgression?
  /// Advisory "HH:mm" for the daily reminder; the user's own times always win.
  let suggestedReminderTime: String?
  /// Annual "MM-DD" the series traditionally begins on, so a pinned devotion can announce
  /// itself before its first day. Advisory — starting it any day always works.
  let suggestedStart: String?
  /// A devotion to offer once the last day is prayed. May name one this device does not have —
  /// resolved at runtime, and quietly dropped when it cannot be, so a dangling suggestion never
  /// breaks the bundle carrying it.
  let suggestedNext: String?
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
  /// One grapheme (letter or emoji) drawn as the icon instead of `iconSystemName` — the
  /// Compose "your own" icon (v0.7, Gamaliel item 6).
  let iconGlyph: String?
  let displayNameByLanguage: [String: String]
  let reminderBody: [String: String]
  let reminderPresetHours: [Int]?
  let reminderPresetFooter: [String: String]
  /// Lowercase category labels from the manifest ("marian", "passion") — what the Categories
  /// tab groups by.
  let tags: [String]

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
    "rosary", "angelus", "stationsOfTheCross", "viaLucis", "franciscanCrown", "sevenSorrows",
    "divineMercyChaplet", "trisagion", "oAntiphons",
  ]

  private static var prayerOverrides: [String: [PrayerKey: String]] = [:]
  private static var mysteryOverrides: [String: [String: MysteryText]] = [:]
  private static var imageDataByKey: [String: Data] = [:]
  /// Unfiltered per-bundle content, keyed bundleId -> language -> raw key -> text — unlike
  /// `prayerOverrides`, this retains keys with no matching `PrayerKey` case (e.g.
  /// "trisagionAcclamation"), which is how a generic devotion's `devotion.json` resolves
  /// bundle-local body text. See `resolveBodyText`.
  private static var rawContentByBundle: [String: [String: [String: String]]] = [:]
  /// bundleId → language → prayer key → transliterated text (v0.7 reading aid).
  private static var transliterationsByBundle: [String: [String: [String: String]]] = [:]
  private static var definitionByBundle: [String: CustomDevotionDefinition] = [:]
  private static var optionsByBundle: [String: [CustomDevotionOption]] = [:]
  private static var audioTracksByBundle: [String: [DevotionAudioTrack]] = [:]
  /// Each loaded bundle's pack file — audio bytes are re-read from here on demand rather than
  /// held in the load-time cache the way images are (a recording dwarfs every other bundle
  /// asset). See `audioData`.
  private static var packUrlByBundle: [String: URL] = [:]
  /// Bundle ids with a devotion.json, in pack-load order.
  private static var orderedCustomIds: [String] = []
  private static var infoByBundle: [String: CustomDevotionInfo] = [:]
  /// Bundle ids installed by the user (files in `installedPacksDirectory`), in load order.
  private static var installedIds: [String] = []
  private static var didLoad = false

  /// Where user-imported .prosaryprayer files live — scanned (sorted by filename) after the
  /// built-in packs on every load, so installs survive restarts. Overridable for tests.
  /// When iCloud Drive is available this is re-pointed at the ubiquity container before the
  /// first scan — see `adoptUbiquityDirectoryIfAvailable`.
  static var installedPacksDirectory: URL = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("PrayerPacks", isDirectory: true)

  private static var didAdoptUbiquity = false

  /// Groundwork for installed-pack sync: when the user's iCloud Drive is available, installed
  /// packs live in the app's ubiquity container (`Documents/PrayerPacks`) so manual imports
  /// follow the user across their devices. Packs installed before this existed migrate in
  /// (`setUbiquitous` moves them); with iCloud signed out or disabled the local directory keeps
  /// working exactly as before. Files another device added but this one hasn't materialized
  /// yet appear as ".….prosaryprayer.icloud" placeholders — `ensureLoaded` kicks off their
  /// download so they load on a later launch. Deliberately not yet shipped: NSFileCoordinator
  /// wrapping and live NSMetadataQuery updates (mid-session appearance); those land with a
  /// visible sync UI.
  private static func adoptUbiquityDirectoryIfAvailable() {
    guard !didAdoptUbiquity else { return }
    didAdoptUbiquity = true
    // First call after launch can do daemon I/O; subsequent launches are fast. Acceptable next
    // to the pack-zip reads this same lazy load already does.
    guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return }
    let cloudPacks = container.appendingPathComponent("Documents/PrayerPacks", isDirectory: true)
    try? FileManager.default.createDirectory(at: cloudPacks, withIntermediateDirectories: true)

    let localDirectory = installedPacksDirectory
    if localDirectory != cloudPacks,
       let localFiles = try? FileManager.default.contentsOfDirectory(at: localDirectory, includingPropertiesForKeys: nil) {
      for file in localFiles where file.pathExtension == "prosaryprayer" {
        let destination = cloudPacks.appendingPathComponent(file.lastPathComponent)
        if !FileManager.default.fileExists(atPath: destination.path) {
          try? FileManager.default.setUbiquitous(true, itemAt: file, destinationURL: destination)
        }
      }
    }
    installedPacksDirectory = cloudPacks
  }

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

  /// The narrated recordings a bundle's `audio.json` declares, in authored order. Empty for
  /// bundles without audio (see Shared/ARCHITECTURE.md's "Audio").
  static func audioTracks(for bundleId: String) -> [DevotionAudioTrack] {
    ensureLoaded()
    return audioTracksByBundle[bundleId] ?? []
  }

  /// The raw Ogg Opus bytes of one of a bundle's *declared* audio files
  /// (`DevotionAudioTrack.file`), re-read from the pack on demand. Nil for a file no track
  /// declares. AudioPlaybackController extracts these bytes to a cache file for the OS player
  /// rather than keep whole recordings in memory.
  static func audioData(bundleId: String, file: String) -> Data? {
    ensureLoaded()
    guard audioTracksByBundle[bundleId]?.contains(where: { $0.file == file }) == true,
          let url = packUrlByBundle[bundleId],
          let data = try? Data(contentsOf: url),
          let zip = try? MinimalZipReader(data: data) else { return nil }
    return try? zip.contents(of: file)
  }

  static func info(for bundleId: String) -> CustomDevotionInfo? {
    ensureLoaded()
    return infoByBundle[bundleId]
  }

  /// The language a session actually prays a bundle in: the chosen (or app-default) language
  /// when the bundle ships it, else the bundle's own first (manifest-order) language — never a
  /// language the bundle lacks, which would degrade bundle-local text into fallback chains or
  /// raw keys.
  static func effectiveLanguage(for bundleId: String, chosen rawChoice: String?) -> String {
    let resolved = LanguageCatalog.resolve(rawChoice ?? LanguageCatalog.defaultSentinel).code
    let available = info(for: bundleId)?.languages ?? []
    if available.isEmpty || available.contains(resolved) { return resolved }
    // A community variant ("he-x-gamliel") prays a bundle that only ships the base language
    // in the variant: bundle text falls back per-key, so keep the variant code alive here.
    if let base = LanguageCatalog.baseLanguage(of: resolved), available.contains(base) {
      return resolved
    }
    return available[0]
  }

  /// The on-disk .prosaryprayer file of an *installed* bundle — the export seam: sharing this
  /// file is how a devotion travels back to Compose for editing (v0.7, Gamaliel item 7).
  /// Nil for shipped bundles, whose packs live inside the app bundle.
  static func installedPackURL(for bundleId: String) -> URL? {
    ensureLoaded()
    guard installedIds.contains(bundleId) else { return nil }
    return packUrlByBundle[bundleId]
  }

  /// Bundle ids the user has imported (subset of `customDevotionIds()`), in load order.
  static func installedBundleIds() -> [String] {
    ensureLoaded()
    return installedIds
  }

  enum InstallError: LocalizedError {
    case unreadable
    case notADevotion
    case duplicateId(String)

    var errorDescription: String? {
      switch self {
      case .unreadable:
        return String(localized: "packInstall.error.unreadable", defaultValue: "This file is not a readable .prosaryprayer bundle.")
      case .notADevotion:
        return String(localized: "packInstall.error.notADevotion", defaultValue: "This bundle does not contain a devotion.")
      case .duplicateId(let id):
        return String(localized: "packInstall.error.duplicate", defaultValue: "A devotion named \"\(id)\" is already installed.")
      }
    }
  }

  /// Imports a user-provided bundle: validates it (readable zip, parseable manifest +
  /// devotion.json, content for every declared language, not a builtin-kind pack, no id
  /// collision), copies it into `installedPacksDirectory`, and loads it live. Returns the
  /// installed bundle id.
  @discardableResult
  static func installPack(from data: Data) throws -> String {
    ensureLoaded()
    let decoder = JSONDecoder()
    guard let zip = try? MinimalZipReader(data: data),
          let manifestData = try? zip.contents(of: "manifest.json"),
          let manifest = try? decoder.decode(PackManifest.self, from: manifestData) else {
      throw InstallError.unreadable
    }
    guard zip.fileNames().contains("devotion.json"),
          (try? decoder.decode(CustomDevotionDefinition.self, from: zip.contents(of: "devotion.json"))) != nil,
          manifest.builtinKind == nil else {
      throw InstallError.notADevotion
    }
    for language in manifest.languages {
      guard let contentData = try? zip.contents(of: "content/\(language).json"),
            (try? decoder.decode(PackContent.self, from: contentData)) != nil else {
        throw InstallError.unreadable
      }
    }
    guard infoByBundle[manifest.id] == nil else {
      throw InstallError.duplicateId(manifest.id)
    }

    try FileManager.default.createDirectory(at: installedPacksDirectory, withIntermediateDirectories: true)
    let destination = installedPacksDirectory.appendingPathComponent("\(manifest.id).prosaryprayer")
    try data.write(to: destination, options: .atomic)
    try load(packAt: destination)
    installedIds.append(manifest.id)
    return manifest.id
  }

  /// Convenience for user-picked files (fileImporter, the File menu): resolves the security
  /// scope, reads the bytes, and installs. Shared by the Favorites import button and the menu
  /// bar command.
  @discardableResult
  static func installPack(fromUserSelected url: URL) throws -> String {
    let accessing = url.startAccessingSecurityScopedResource()
    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
    return try installPack(from: try Data(contentsOf: url))
  }

  /// Deletes an installed bundle's file and unregisters its devotion. Its merged prayer/image
  /// content stays in memory until the next launch — harmless, since nothing references it once
  /// the devotion is gone from `customDevotionIds()`.
  static func removeInstalledPack(id: String) {
    ensureLoaded()
    guard installedIds.contains(id) else { return }
    try? FileManager.default.removeItem(
      at: installedPacksDirectory.appendingPathComponent("\(id).prosaryprayer"))
    installedIds.removeAll { $0 == id }
    orderedCustomIds.removeAll { $0 == id }
    definitionByBundle[id] = nil
    infoByBundle[id] = nil
    optionsByBundle[id] = nil
    audioTracksByBundle[id] = nil
    transliterationsByBundle[id] = nil
    packUrlByBundle[id] = nil
  }

  /// Resolves a `devotion.json` entry's `bodyKey`/`titleKey` to display text: (1) the bundle's
  /// own raw content for this key — the requested language, else the bundle's Latin (mirroring
  /// `PrayerTranslations.get`'s Latin fallback, so e.g. the sentinel/unknown language prays in
  /// Latin, not raw keys); (2) else, if the key happens to match an existing `PrayerKey` case,
  /// the ordinary hardcoded/override lookup — this is how shared "main" keys (e.g. "gloriaPatri")
  /// resolve; (3) else the raw key string, matching `PrayerTranslations.get`'s own last resort.
  /// The v0.7 reading aid: this key's text transliterated into another script, if the
  /// bundle's language file carries one. No fallback chain — a transliteration belongs to
  /// exactly the language it transliterates.
  static func transliteration(bundleId: String, languageCode: String?, key: String) -> String? {
    ensureLoaded()
    guard let languageCode else { return nil }
    return transliterationsByBundle[bundleId]?[languageCode]?[key]
  }

  static func resolveBodyText(bundleId: String, languageCode: String?, key: String) -> String {
    ensureLoaded()
    if let languageCode,
       let text = rawContentByBundle[bundleId]?[languageCode]?[key]
         ?? LanguageCatalog.baseLanguage(of: languageCode).flatMap({ rawContentByBundle[bundleId]?[$0]?[key] }) {
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

    // User-installed bundles load after the built-ins (so shipped content always wins the
    // shared merges) and are skipped on id collision with anything already loaded.
    adoptUbiquityDirectoryIfAvailable()
    let directoryContents = (try? FileManager.default.contentsOfDirectory(
      at: installedPacksDirectory, includingPropertiesForKeys: nil)) ?? []
    // Undownloaded iCloud placeholders can't load this launch — start their download so a
    // pack imported on another device appears on a later one.
    for placeholder in directoryContents where placeholder.lastPathComponent.hasSuffix(".prosaryprayer.icloud") {
      try? FileManager.default.startDownloadingUbiquitousItem(at: placeholder)
    }
    let installedFiles = directoryContents
      .filter { $0.pathExtension == "prosaryprayer" }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
    for url in installedFiles {
      let id = url.deletingPathExtension().lastPathComponent
      guard infoByBundle[id] == nil else { continue }
      if (try? load(packAt: url)) != nil {
        installedIds.append(id)
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
      iconGlyph: manifest.iconGlyph,
      displayNameByLanguage: manifest.displayNameByLanguage ?? [:],
      reminderBody: manifest.reminderBody ?? [:],
      reminderPresetHours: manifest.reminderPresetHours,
      reminderPresetFooter: manifest.reminderPresetFooter ?? [:],
      tags: manifest.tags ?? [])

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
      if let transliterations = content.transliterations, !transliterations.isEmpty {
        transliterationsByBundle[manifest.id, default: [:]][language] = transliterations
      }
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
      if manifest.builtinKind == nil {
        orderedCustomIds.append(manifest.id)
      }
    }

    if zip.fileNames().contains("options.json") {
      optionsByBundle[manifest.id] =
        try decoder.decode(PackOptions.self, from: zip.contents(of: "options.json")).options
    }

    if zip.fileNames().contains("audio.json") {
      audioTracksByBundle[manifest.id] =
        try decoder.decode(PackAudio.self, from: zip.contents(of: "audio.json")).tracks
    }
    packUrlByBundle[manifest.id] = url

    for name in zip.fileNames() where name.hasPrefix("images/") {
      let imageKey = String(name.dropFirst("images/".count).dropLast(4))  // strip "images/" and ".jpg"
      imageDataByKey[imageKey] = try zip.contents(of: name)
    }
  }
}

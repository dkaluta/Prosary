//
//  PrayerRunProgress.swift
//  Prosary
//
//  A deliberately small, device-local bookmark for an interrupted prayer. Authored content
//  and configuration remain in the prayer preset/bundle; this stores only the current step,
//  the language actually used inside the flow, and the local civil day needed by the Rosary's
//  same-day continuation rule.
//

import Foundation

struct PrayerRunProgress: Codable, Equatable {
  /// A stable description of the sequence-producing options. An old bookmark must not land
  /// on an unrelated prayer after its preset, variant, day, or repeat target changes.
  let configurationSignature: String?
  let stepIndex: Int
  let languageCode: String
  /// ISO local date without a timezone. A Rosary expires when the user's local calendar turns
  /// over, irrespective of what date that instant represents in another timezone.
  let savedLocalDate: String

  init(
    configurationSignature: String? = nil,
    stepIndex: Int,
    languageCode: String,
    savedLocalDate: String
  ) {
    self.configurationSignature = configurationSignature
    self.stepIndex = stepIndex
    self.languageCode = languageCode
    self.savedLocalDate = savedLocalDate
  }

  func canResume(
    stepCount: Int,
    today: Date = Date(),
    calendar: Calendar = .current,
    sameLocalDayOnly: Bool = false,
    expectedConfigurationSignature: String? = nil
  ) -> Bool {
    stepIndex > 0 && stepIndex < stepCount
      && (expectedConfigurationSignature == nil
        || configurationSignature == expectedConfigurationSignature)
      && (!sameLocalDayOnly || savedLocalDate == Self.localDateString(for: today, calendar: calendar))
  }

  static func localDateString(for date: Date, calendar: Calendar = .current) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(
      format: "%04d-%02d-%02d",
      locale: Locale(identifier: "en_US_POSIX"),
      components.year ?? 0,
      components.month ?? 0,
      components.day ?? 0)
  }
}

/// Platform-local transient storage. Keys are stable prayer identities (`rosary:<uuid>`,
/// `custom:<bundle>:<variant>:<day>`, `jesus:<uuid-or-target>`), allowing multiple Rosary presets
/// to retain independent places without applying a bookmark to another form/day of a devotion.
struct PrayerRunProgressStore {
  static let defaultsKey = "prayerRunProgress"

  private let defaults: UserDefaults
  private let defaultsKey: String
  private let namespace: String?

  init(defaults: UserDefaults = .standard, defaultsKey: String = Self.defaultsKey, namespace: String? = nil) {
    self.defaults = defaults
    self.defaultsKey = defaultsKey
    self.namespace = namespace
  }

  func progress(for runKey: String) -> PrayerRunProgress? {
    var runs = all()
    let key = storageKey(runKey)
    if let ownProgress = runs[key] { return ownProgress }
    // Existing installs and newly opened windows resume the most recently saved session.
    // Claim a copy once; later sibling-window saves must not move this window's bookmark.
    guard namespace != nil, let latestProgress = runs[runKey] else { return nil }
    runs[key] = latestProgress
    save(runs)
    return latestProgress
  }

  func save(
    runKey: String,
    stepIndex: Int,
    languageCode: String,
    configurationSignature: String? = nil,
    today: Date = Date(),
    calendar: Calendar = .current
  ) {
    guard stepIndex > 0 else {
      clear(runKey: runKey)
      return
    }
    var runs = all()
    let progress = PrayerRunProgress(
      configurationSignature: configurationSignature,
      stepIndex: stepIndex,
      languageCode: languageCode,
      savedLocalDate: PrayerRunProgress.localDateString(for: today, calendar: calendar))
    runs[storageKey(runKey)] = progress
    // Retain a shared continuation for an explicitly closed window, whose scene namespace
    // won't return when the person later chooses File → New Window.
    if namespace != nil { runs[runKey] = progress }
    save(runs)
  }

  func clear(runKey: String) {
    var runs = all()
    let removedProgress = runs.removeValue(forKey: storageKey(runKey))
    // Finishing an older window must not erase the continuation most recently saved by a
    // sibling. The shared copy belongs to this window only while its checkpoint still matches.
    if namespace != nil, let removedProgress, runs[runKey] == removedProgress {
      runs.removeValue(forKey: runKey)
    }
    save(runs)
  }

  /// A restored Mac scene retains this namespace; sibling windows never share a bookmark.
  /// Mobile keeps the existing prayer-identity keys.
  private func storageKey(_ runKey: String) -> String {
    namespace.map { "window:\($0):\(runKey)" } ?? runKey
  }

  private func all() -> [String: PrayerRunProgress] {
    guard let data = defaults.data(forKey: defaultsKey) else { return [:] }
    return (try? JSONDecoder().decode([String: PrayerRunProgress].self, from: data)) ?? [:]
  }

  private func save(_ runs: [String: PrayerRunProgress]) {
    guard !runs.isEmpty else {
      defaults.removeObject(forKey: defaultsKey)
      return
    }
    guard let data = try? JSONEncoder().encode(runs) else { return }
    defaults.set(data, forKey: defaultsKey)
  }
}

enum PrayerRunKey {
  static func rosary(_ prayer: Prayer) -> String { "rosary:\(prayer.id.uuidString)" }
  static func custom(_ devotionId: String, variantId: String?, dayIndex: Int) -> String {
    "custom:\(devotionId):\(variantId ?? ""):\(dayIndex)"
  }

  static func jesus(_ prayer: Prayer?, target: JesusPrayerTarget) -> String {
    if let prayer { return "jesus:\(prayer.id.uuidString)" }
    switch target {
    case .count(let count): return "jesus:\(count)"
    case .unbounded: return "jesus:unbounded"
    }
  }
}

/// The raw language choice is persisted separately in `PrayerRunProgress`. A custom devotion's
/// resolved form is included because some languages own a structurally different default form;
/// everything here can change the generated sequence or its visual identity.
enum PrayerRunSignature {
  static func rosary(_ options: RosaryOptions) -> String {
    var fields = [
      "rosary",
      options.mysterySelectionMode.rawValue,
      options.specificMysteryGroup.rawValue,
      String(options.specificMysteryOrder),
      flag(options.includeApostlesCreed),
      flag(options.includeOpeningPrayers),
      flag(options.includeOpeningFatimaPrayer),
      flag(options.includeFatimaPrayer),
      options.eternalRestForDeceased.rawValue,
      options.marianAntiphon.rawValue,
      flag(options.effectiveClosingIntentions),
      flag(options.includeStMichaelPrayer),
      flag(options.includeFinalSignOfCross),
      options.aramaicSignOfCrossForm,
      flag(options.presenterMode),
      options.mysteryImageStyle.rawValue,
    ]
    // Preserve whole-group bookmarks; former partial groups now have a different sequence.
    if options.effectiveClosingIntentions {
      fields.append("closing-v2:1,1,1")
    }
    if options.includeOpeningPrayers && options.includeOpeningFatimaPrayer {
      fields.append("opening-fatima-v2")
    }
    return fields.joined(separator: "|")
  }

  static func custom(
    _ devotionId: String,
    effectiveVariantId: String?,
    dayIndex: Int,
    options: [String: String]
  ) -> String {
    let options = RosaryOptions.normalizedCustomOptions(options, bundleId: devotionId)
    let optionText = options.keys.sorted().map { "\($0)=\(options[$0] ?? "")" }.joined(separator: "|")
    var signature = "custom|\(devotionId)|\(effectiveVariantId ?? "")|\(dayIndex)|\(optionText)"
    if devotionId == "rosary", options["closingIntentions"] == "true" {
      signature += "|closing-v2:1,1,1"
    }
    if devotionId == "rosary", options["openingPrayers"] != "false", options["openingFatimaPrayer"] == "true" {
      signature += "|opening-fatima-v2"
    }
    return signature
  }

  static func jesus(_ target: JesusPrayerTarget) -> String {
    switch target {
    case .count(let count): return "jesus|count|\(count)"
    case .unbounded: return "jesus|unbounded"
    }
  }

  private static func flag(_ value: Bool) -> String { value ? "1" : "0" }
}

/// Pure navigation targets for the Rosary toolbar. Moving between mysteries changes only the
/// current step index, leaving the ordinary bead-by-bead Back/Next controls and BeadLayout intact.
enum RosaryMysteryNavigation {
  static func announcementIndices(in steps: [RosaryStep]) -> [Int] {
    var seen: Set<Int> = []
    return steps.indices.filter { index in
      guard let decadeIndex = steps[index].decadeIndex else { return false }
      return seen.insert(decadeIndex).inserted
    }
  }

  static func previousIndex(in steps: [RosaryStep], from currentIndex: Int) -> Int? {
    let starts = announcementIndices(in: steps)
    if let currentDecade = steps.indices.contains(currentIndex) ? steps[currentIndex].decadeIndex : nil {
      guard currentDecade > 0 else { return nil }
      return starts.first { steps[$0].decadeIndex == currentDecade - 1 }
    }
    return starts.last { $0 < currentIndex }
  }

  static func nextIndex(in steps: [RosaryStep], from currentIndex: Int) -> Int? {
    let starts = announcementIndices(in: steps)
    if let currentDecade = steps.indices.contains(currentIndex) ? steps[currentIndex].decadeIndex : nil {
      return starts.first { steps[$0].decadeIndex == currentDecade + 1 }
    }
    return starts.first { $0 > currentIndex }
  }
}

/// A language normally changes only text. Some devotions, however, declare a different default
/// form for a language; carrying a numeric position into that other sequence would open an
/// unrelated prayer.
enum CustomDevotionLanguageSwitch {
  static func indexAfterSwitch(
    currentIndex: Int,
    previousEffectiveVariantId: String?,
    nextEffectiveVariantId: String?,
    nextStepCount: Int
  ) -> Int {
    guard previousEffectiveVariantId == nextEffectiveVariantId else { return 0 }
    return min(currentIndex, max(nextStepCount - 1, 0))
  }
}

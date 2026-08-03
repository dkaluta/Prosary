//
//  PrayerEngine.swift
//  Prosary
//
//  The single production step-builder for every devotion. `buildSteps(for:)` dispatches on
//  `Prayer.kind`: the Jesus Prayer has no steps at all (a repetition counter — see
//  JesusPrayerFlowView); everything else — the Rosary included — is data-driven from a
//  .prosaryprayer bundle's devotion.json via `buildCustomDevotionSteps` (flat "steps" type) and
//  `buildCustomRosarySteps` (decade/bead-structured "rosary" type). The Rosary's
//  option/calendar-driven pieces stay engine-side behind the bundle's
//  `decades.source: "mysteryGroups"` (see `buildMysteryGroupDecades`), with `RosaryOptions`
//  mapped onto the bundle's options.json values by `rosaryOptionValues` — no data migration.
//  The retired hardcoded builder's output was pinned byte-for-byte before deletion
//  (RosaryEngineTests' one-time parity sweep, kept in git history).
//

import Foundation

struct PrayerEngine {
  private static let ordinals = [
    "1st", "2nd", "3rd", "4th", "5th", "6th", "7th",
    "8th", "9th", "10th", "11th", "12th", "13th", "14th",
  ]

  private let calendar: LiturgicalCalendarProviding

  init(calendar: LiturgicalCalendarProviding = StubLiturgicalCalendar()) {
    self.calendar = calendar
  }

  func buildSteps(for prayer: Prayer) -> [RosaryStep] {
    switch prayer.kind {
    case .rosary:
      // The Rosary builds from the rosary bundle's devotion.json like every other devotion —
      // RosaryOptions stays the persisted shape (no data migration; the bespoke editor keeps
      // writing it) and is mapped onto the bundle's option values here.
      return buildCustomDevotionSteps(
        bundleId: "rosary", languageCode: prayer.resolvedLanguageCode,
        optionOverrides: Self.rosaryOptionValues(prayer.rosary), rosaryOptions: prayer.rosary)
    case .jesusPrayer:
      // The Jesus Prayer has no engine — every repetition prays the same fixed line, so a
      // single synthesized step plus a JesusPrayerProgress counter is the whole model; see
      // JesusPrayerFlowView, which never calls this engine at all.
      return []
    case .custom:
      guard let bundleId = prayer.customDevotionId else { return [] }
      return buildCustomDevotionSteps(
        bundleId: bundleId,
        languageCode: PrayerPackStore.effectiveLanguage(for: bundleId, chosen: prayer.languageCode),
        variantId: prayer.variantId,
        optionOverrides: prayer.customOptions, dayIndex: prayer.dayIndex ?? 0)
    }
  }

  // MARK: - Rosary

  func resolveMysteryGroups(for prayer: Prayer) -> [MysteryGroup] {
    resolveMysteryGroups(rosary: prayer.rosary)
  }

  func resolveMysteryGroups(rosary: RosaryOptions) -> [MysteryGroup] {
    switch rosary.mysterySelectionMode {
    case .specific, .singleMystery:
      return [rosary.specificMysteryGroup]
    case .fifteenMystery:
      return [.joyful, .sorrowful, .glorious]
    case .twentyMystery:
      return [.joyful, .luminous, .sorrowful, .glorious]
    case .todaysMysteries:
      return [calendar.mysteryGroupToday()]
    }
  }

  /// Maps the persisted `RosaryOptions` onto the rosary bundle's options.json values — the
  /// no-data-migration seam: favorites keep their typed columns and bespoke editor, while the
  /// engine speaks the bundle's generic option encoding.
  static func rosaryOptionValues(_ rosary: RosaryOptions) -> [String: String] {
    [
      "apostlesCreed": rosary.includeApostlesCreed ? "true" : "false",
      "openingPrayers": rosary.includeOpeningPrayers ? "true" : "false",
      "presenterMode": rosary.presenterMode ? "true" : "false",
      "fatimaPrayer": rosary.includeFatimaPrayer ? "true" : "false",
      "eternalRest": rosary.eternalRestForDeceased.rawValue,
      "antiphon": rosary.marianAntiphon.rawValue,
      "stMichael": rosary.includeStMichaelPrayer ? "true" : "false",
      "finalSignOfCross": rosary.includeFinalSignOfCross ? "true" : "false",
    ]
  }

  // MARK: - Marian antiphon (shared by Rosary and Franciscan Crown)

  private enum AntiphonStyle { case standard, paschal, standalone }

  private func buildMarianAntiphonStep(_ antiphon: MarianAntiphonOption, languageCode: String?) -> RosaryStep {
    func text(_ key: PrayerKey) -> String {
      PrayerTranslations.get(languageCode: languageCode, key: key)
    }

    let (titleKey, style): (PrayerKey, AntiphonStyle) = {
      switch antiphon {
      case .salveRegina:          return (.salveRegina, .standard)
      case .almaRedemptorisMater: return (.almaRedemptorisMater, .standard)
      case .aveReginaCaelorum:    return (.aveReginaCaelorum, .standard)
      case .reginaCaeli:          return (.reginaCaeli, .paschal)
      case .subTuumPraesidium:    return (.subTuumPraesidium, .standalone)
      case .none, .seasonal:      return (.salveRegina, .standard)
      }
    }()

    let body: String
    switch style {
    case .standalone:
      body = text(titleKey)
    case .standard:
      body = "\(text(titleKey))\n\n\(text(.versiculumStandard))\n**\(text(.responsiumStandard))**\n\n\(text(.collectaStandard))"
    case .paschal:
      body = "\(text(titleKey))\n\n\(text(.versiculumPaschale))\n**\(text(.responsiumPaschale))**\n\n\(text(.collectaPaschale))"
    }

    var step = RosaryStep(title: marianAntiphonHeader(for: antiphon), subtitle: nil, body: body)
    step.isAntiphon = true
    step.imageOverrideKey = "madonna_and_child"
    return step
  }

  private func marianAntiphonHeader(for antiphon: MarianAntiphonOption) -> String {
    switch antiphon {
    case .salveRegina:          return "Salve Regina"
    case .almaRedemptorisMater: return "Alma Redemptoris Mater"
    case .aveReginaCaelorum:    return "Ave Regina Caelorum"
    case .reginaCaeli:          return "Regina Caeli"
    case .subTuumPraesidium:    return "Sub Tuum Praesidium"
    case .none, .seasonal:      return "Marian Antiphon"
    }
  }

  // MARK: - Custom (bundle-driven) devotions

  /// The only builder for every `PrayerKind.custom` devotion — reads `bundleId`'s parsed
  /// `devotion.json` and produces the full step sequence with no devotion-specific code. The
  /// flat "steps" type covers Angelus/Stations/Trisagion-shaped devotions (including the
  /// Angelus's Eastertide whole-sequence swap); the decade/bead-structured "rosary" type covers
  /// Franciscan Crown/Seven Sorrows/Divine Mercy-shaped ones.
  private func buildCustomDevotionSteps(
    bundleId: String, languageCode: String?, variantId: String? = nil,
    optionOverrides: [String: String] = [:], rosaryOptions: RosaryOptions? = nil,
    dayIndex: Int = 0
  ) -> [RosaryStep] {
    guard let definition = PrayerPackStore.definition(for: bundleId) else { return [] }
    // Effective option values: the bundle's declared defaults overlaid with the favorite's
    // stored choices. Overrides for keys the bundle no longer declares are ignored, so a stale
    // favorite can't gate on options that stopped existing.
    var optionValues: [String: String] = [:]
    for option in PrayerPackStore.options(for: bundleId) {
      optionValues[option.key] = optionOverrides[option.key] ?? option.defaultValue
    }
    switch definition.type {
    case .steps:
      let (baseSteps, eastertideSteps) = definition.resolvedSteps(variantId: variantId)
      let entries = (calendar.isEasterSeasonToday() ? eastertideSteps : nil) ?? baseSteps
      return entries.flatMap {
        expand($0, bundleId: bundleId, languageCode: languageCode, optionValues: optionValues)
      }
    case .rosary:
      return buildCustomRosarySteps(
        definition, bundleId: bundleId, languageCode: languageCode, optionValues: optionValues,
        rosaryOptions: rosaryOptions)
    case .days:
      // Multi-day devotions: shared opening + the day's own steps + shared closing. `dayIndex`
      // is clamped, so a finished novena keeps praying its last day rather than crashing.
      // Per-favorite progress drives it: Prayer.dayIndex advances when a day's session
      // finishes, and the flow's day picker jumps anywhere.
      guard let days = definition.days, !days.isEmpty else { return [] }
      let day = days[min(max(dayIndex, 0), days.count - 1)]
      let entries = (definition.opening ?? []) + day.steps + (definition.closing ?? [])
      return entries.flatMap {
        expand($0, bundleId: bundleId, languageCode: languageCode, optionValues: optionValues)
      }
    }
  }

  /// Evaluates an entry's `"if"` gate against the effective option values: `"key"` — toggle
  /// on; `"!key"` — toggle off; `"key=caseId"` — choice equals. The validator guarantees every
  /// authored expression references a declared option, so a missing key (impossible for shipped
  /// bundles) simply reads as "not on".
  static func evaluateCondition(_ expression: String, values: [String: String]) -> Bool {
    if let equals = expression.firstIndex(of: "=") {
      return values[String(expression[..<equals])] == String(expression[expression.index(after: equals)...])
    }
    if expression.hasPrefix("!") {
      return values[String(expression.dropFirst())] != "true"
    }
    return values[expression] == "true"
  }

  /// Expands one `devotion.json` entry into its step(s): resolves the title (literal or
  /// translated `titleKey`) and body, and unrolls `repeat` into "(h of n)"-suffixed copies —
  /// deliberately without bead fields, matching the hardcoded devotions' closing Hail Marys.
  private func expand(
    _ entry: CustomDevotionStep, bundleId: String, languageCode: String?,
    optionValues: [String: String] = [:]
  ) -> [RosaryStep] {
    if let condition = entry.condition, !Self.evaluateCondition(condition, values: optionValues) {
      return []
    }
    if entry.kind == .seasonalMarianAntiphon {
      return [buildMarianAntiphonStep(calendar.seasonalMarianAntiphonToday(), languageCode: languageCode)]
    }
    if entry.kind == .marianAntiphon {
      // Option-selected antiphon (the Rosary): the named choice's value is an antiphon id,
      // "seasonal" (calendar-resolved) or "none" (no step).
      guard let optionKey = entry.optionKey,
            let chosen = MarianAntiphonOption(rawValue: optionValues[optionKey] ?? "seasonal"),
            chosen != .none else { return [] }
      let antiphon = chosen == .seasonal ? calendar.seasonalMarianAntiphonToday() : chosen
      return [buildMarianAntiphonStep(antiphon, languageCode: languageCode)]
    }
    let title = entry.titleKey.map {
      PrayerPackStore.resolveBodyText(bundleId: bundleId, languageCode: languageCode, key: $0)
    } ?? entry.title ?? ""
    let subtitle = entry.subtitleKey.map {
      PrayerPackStore.resolveBodyText(bundleId: bundleId, languageCode: languageCode, key: $0)
    } ?? entry.subtitle
    let body = entry.bodyKey.map {
      PrayerPackStore.resolveBodyText(bundleId: bundleId, languageCode: languageCode, key: $0)
    } ?? ""

    let isScripture = languageCode.flatMap { entry.isScriptureByLanguage?[$0] }
      ?? entry.isScripture ?? false
    let acclamation = entry.acclamationKey.map {
      PrayerPackStore.resolveBodyText(bundleId: bundleId, languageCode: languageCode, key: $0)
    }
    let transliteratedBody = entry.bodyKey.flatMap {
      PrayerPackStore.transliteration(bundleId: bundleId, languageCode: languageCode, key: $0)
    }
    guard let count = entry.repeatCount, count > 1 else {
      return [
        RosaryStep(
          title: title, subtitle: subtitle, body: body, acclamation: acclamation,
          isScripture: isScripture, transliteratedBody: transliteratedBody,
          imageOverrideKey: entry.imageKey)
      ]
    }
    return (1...count).map { h in
      RosaryStep(
        title: "\(title) (\(h) of \(count))", subtitle: subtitle, body: body, acclamation: acclamation,
        isScripture: isScripture, transliteratedBody: transliteratedBody,
        imageOverrideKey: entry.imageKey)
    }
  }

  /// The decade/bead-structured generic builder ("rosary" type) — announcement → major → N
  /// minors (dense global `decadeIndex`, `hailMaryIndexInDecade` on minors only,
  /// "ordinal — title" subtitles), matching the retired hardcoded decade devotions' emission
  /// exactly so the bead track and step chrome behave identically everywhere.
  private func buildCustomRosarySteps(
    _ definition: CustomDevotionDefinition, bundleId: String, languageCode: String?,
    optionValues: [String: String] = [:], rosaryOptions: RosaryOptions? = nil
  ) -> [RosaryStep] {
    guard let decades = definition.decades else { return [] }
    func resolve(_ key: String) -> String {
      PrayerPackStore.resolveBodyText(bundleId: bundleId, languageCode: languageCode, key: key)
    }

    var steps: [RosaryStep] = []
    for entry in definition.opening ?? [] {
      steps.append(contentsOf: expand(
        entry, bundleId: bundleId, languageCode: languageCode, optionValues: optionValues))
    }

    if decades.source == "mysteryGroups" {
      steps.append(contentsOf: buildMysteryGroupDecades(
        decades, bundleId: bundleId, languageCode: languageCode, optionValues: optionValues,
        rosary: rosaryOptions ?? RosaryOptions()))
    } else {
      let fruitLabel = PrayerTranslations.get(languageCode: languageCode, key: .fructusMysteriiLabel)
      let majorBody = resolve(decades.majorStep.bodyKey)
      let minorBody = resolve(decades.minorStep.bodyKey)
      let decadeCount = decades.entries?.count ?? decades.count ?? 0

      for d in 0..<decadeCount {
        let entry = decades.entries?[d]
        let imageKey = entry?.imageKey ?? decades.fixedImageKey
        let ordinalLabel = "\(Self.ordinals[d]) \(decades.ordinalNoun)"
        var decadeSubtitle = ordinalLabel

        if decades.announceMystery, let entry {
          let mysteryText = MysteryTranslations.get(languageCode: languageCode, imageKey: entry.imageKey)
          var body = mysteryText.description
          if !mysteryText.fruit.isEmpty {
            body += "\n\n\(fruitLabel): \(mysteryText.fruit)"
          }
          steps.append(RosaryStep(
            title: mysteryText.title, subtitle: ordinalLabel, body: body,
            isScripture: entry.isScripture ?? true, decadeIndex: d, imageOverrideKey: entry.imageKey))
          decadeSubtitle = "\(ordinalLabel) — \(mysteryText.title)"
        }

        steps.append(RosaryStep(
          title: decades.majorStep.title, subtitle: decadeSubtitle, body: majorBody,
          decadeIndex: d, imageOverrideKey: decades.majorStep.imageKey ?? imageKey))

        for h in 1...decades.minorCount {
          steps.append(RosaryStep(
            title: "\(decades.minorStep.title) (\(h) of \(decades.minorCount))",
            subtitle: decadeSubtitle, body: minorBody,
            decadeIndex: d, hailMaryIndexInDecade: h, imageOverrideKey: imageKey))
        }

        steps.append(contentsOf: postMinorSteps(
          decades, bundleId: bundleId, languageCode: languageCode, optionValues: optionValues,
          decadeSubtitle: decadeSubtitle, decadeIndex: d))
      }
    }

    for entry in definition.closing ?? [] {
      steps.append(contentsOf: expand(
        entry, bundleId: bundleId, languageCode: languageCode, optionValues: optionValues))
    }
    return steps
  }

  /// The Rosary's decade section — driven by the bundle's decades block but cataloged by the
  /// mystery-group machinery (`source: "mysteryGroups"`: selection mode + liturgical calendar)
  /// instead of bundle entries. Reproduces the retired hardcoded builder byte-for-byte: real
  /// `Mystery` values on announcement/minor steps (no image overrides), group-labelled ordinals
  /// when multiple groups are prayed, the single-mystery mode's true ordinal, and presenter
  /// mode's combined minors step with `hailMaryIndexInDecade = minorCount` for the bead track.
  private func buildMysteryGroupDecades(
    _ decades: CustomDevotionDefinition.Decades, bundleId: String, languageCode: String?,
    optionValues: [String: String], rosary: RosaryOptions
  ) -> [RosaryStep] {
    func resolve(_ key: String) -> String {
      PrayerPackStore.resolveBodyText(bundleId: bundleId, languageCode: languageCode, key: key)
    }

    let groups = resolveMysteryGroups(rosary: rosary)
    let fruitLabel = PrayerTranslations.get(languageCode: languageCode, key: .fructusMysteriiLabel)
    let majorBody = resolve(decades.majorStep.bodyKey)
    let minorBody = resolve(decades.minorStep.bodyKey)
    let presenterOn = optionValues["presenterMode"] == "true"
    let showGroupName = groups.count > 1

    var steps: [RosaryStep] = []
    var decadeIndex = 0
    for group in groups {
      let mysteries = MysteryCatalog.forGroup(group)
      let indices = rosary.mysterySelectionMode == .singleMystery
        ? [rosary.specificMysteryOrder - 1]
        : Array(mysteries.indices)

      for d in indices {
        let mystery = mysteries[d]
        let mysteryText = MysteryTranslations.get(languageCode: languageCode, imageKey: mystery.imageKey)
        let ordinalLabel = showGroupName
          ? "\(group.displayName) — \(Self.ordinals[d]) \(decades.ordinalNoun)"
          : "\(Self.ordinals[d]) \(decades.ordinalNoun)"
        let decadeSubtitle = "\(ordinalLabel) — \(mysteryText.title)"

        steps.append(RosaryStep(
          title: mysteryText.title, subtitle: ordinalLabel,
          body: "\(mysteryText.description)\n\n\(fruitLabel): \(mysteryText.fruit)",
          mystery: mystery, isScripture: true, decadeIndex: decadeIndex))
        steps.append(RosaryStep(
          title: decades.majorStep.title, subtitle: decadeSubtitle, body: majorBody,
          decadeIndex: decadeIndex, imageOverrideKey: decades.majorStep.imageKey))

        if presenterOn, let presenter = decades.presenter {
          steps.append(RosaryStep(
            title: presenter.combinedTitle, subtitle: decadeSubtitle,
            body: presenter.bodyKeys.map(resolve).joined(separator: "\n\n"),
            mystery: mystery, decadeIndex: decadeIndex, hailMaryIndexInDecade: decades.minorCount))
        } else {
          for h in 1...decades.minorCount {
            steps.append(RosaryStep(
              title: "\(decades.minorStep.title) (\(h) of \(decades.minorCount))",
              subtitle: decadeSubtitle, body: minorBody,
              mystery: mystery, decadeIndex: decadeIndex, hailMaryIndexInDecade: h))
          }
        }

        steps.append(contentsOf: postMinorSteps(
          decades, bundleId: bundleId, languageCode: languageCode, optionValues: optionValues,
          decadeSubtitle: decadeSubtitle, decadeIndex: decadeIndex))
        decadeIndex += 1
      }
    }
    return steps
  }

  /// Expands the decades' `postMinor` entries for one decade — the same option gating as
  /// `expand`, but every emitted step carries the decade's subtitle and index (the Rosary's
  /// per-decade Glory Be / Fatima Prayer / eternal rest).
  private func postMinorSteps(
    _ decades: CustomDevotionDefinition.Decades, bundleId: String, languageCode: String?,
    optionValues: [String: String], decadeSubtitle: String, decadeIndex: Int
  ) -> [RosaryStep] {
    (decades.postMinor ?? []).compactMap { entry in
      if let condition = entry.condition, !Self.evaluateCondition(condition, values: optionValues) {
        return nil
      }
      let title = entry.titleKey.map {
        PrayerPackStore.resolveBodyText(bundleId: bundleId, languageCode: languageCode, key: $0)
      } ?? entry.title ?? ""
      let body = entry.bodyKey.map {
        PrayerPackStore.resolveBodyText(bundleId: bundleId, languageCode: languageCode, key: $0)
      } ?? ""
      return RosaryStep(
        title: title, subtitle: decadeSubtitle, body: body,
        decadeIndex: decadeIndex, imageOverrideKey: entry.imageKey)
    }
  }
}

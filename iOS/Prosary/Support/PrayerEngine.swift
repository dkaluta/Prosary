//
//  PrayerEngine.swift
//  Prosary
//
//  The single production step-builder for every devotion. `buildSteps(for:)` dispatches on
//  `Prayer.kind`: the Rosary keeps its own hardcoded, options/calendar-driven builder (it is the
//  one deeply configurable devotion); the Jesus Prayer has no steps at all (a repetition counter
//  — see JesusPrayerFlowView); and every other devotion is `.custom` — fully data-driven from its
//  .prosaryprayer bundle's devotion.json via `buildCustomDevotionSteps` (flat "steps" type) and
//  `buildCustomRosarySteps` (decade/bead-structured "rosary" type). `buildDecadeSteps` and
//  `buildMarianAntiphonStep` remain as the Rosary's own helpers; the generic rosary-type builder
//  mirrors their emission so bead tracks behave identically everywhere.
//

import Foundation

struct PrayerEngine {
  private static let ordinals = [
    "1st", "2nd", "3rd", "4th", "5th", "6th", "7th",
    "8th", "9th", "10th", "11th", "12th", "13th", "14th",
  ]

  private static let virtues: [(key: PrayerKey, imageKey: String)] = [
    (.aveMariaProFide, "virtue_faith"),
    (.aveMariaProSpe, "virtue_hope"),
    (.aveMariaProCaritate, "virtue_charity"),
  ]

  private let calendar: LiturgicalCalendarProviding

  init(calendar: LiturgicalCalendarProviding = StubLiturgicalCalendar()) {
    self.calendar = calendar
  }

  func buildSteps(for prayer: Prayer) -> [RosaryStep] {
    switch prayer.kind {
    case .rosary:
      return buildRosarySteps(prayer)
    case .jesusPrayer:
      // The Jesus Prayer has no engine — every repetition prays the same fixed line, so a
      // single synthesized step plus a JesusPrayerProgress counter is the whole model; see
      // JesusPrayerFlowView, which never calls this engine at all.
      return []
    case .custom:
      guard let bundleId = prayer.customDevotionId else { return [] }
      return buildCustomDevotionSteps(bundleId: bundleId, languageCode: prayer.languageCode)
    }
  }

  // MARK: - Rosary

  func resolveMysteryGroups(for prayer: Prayer) -> [MysteryGroup] {
    switch prayer.rosary.mysterySelectionMode {
    case .specific, .singleMystery:
      return [prayer.rosary.specificMysteryGroup]
    case .fifteenMystery:
      return [.joyful, .sorrowful, .glorious]
    case .twentyMystery:
      return [.joyful, .luminous, .sorrowful, .glorious]
    case .todaysMysteries:
      return [calendar.mysteryGroupToday()]
    }
  }

  private func buildRosarySteps(_ prayer: Prayer) -> [RosaryStep] {
    let lang = prayer.resolvedLanguageCode
    let rosary = prayer.rosary
    let groups = resolveMysteryGroups(for: prayer)
    var steps: [RosaryStep] = []

    func text(_ key: PrayerKey) -> String {
      PrayerTranslations.get(languageCode: lang, key: key)
    }

    steps.append(RosaryStep(title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis), imageOverrideKey: "crucifix"))

    if rosary.includeApostlesCreed {
      steps.append(RosaryStep(title: "Apostles' Creed", subtitle: nil, body: text(.symbolumApostolorum), imageOverrideKey: "crucifix"))
    }

    if rosary.includeOpeningPrayers {
      steps.append(RosaryStep(title: "Our Father", subtitle: nil, body: text(.paterNoster), imageOverrideKey: "our_father"))
      for virtue in Self.virtues {
        steps.append(RosaryStep(title: "Hail Mary", subtitle: text(virtue.key), body: text(.aveMaria), imageOverrideKey: virtue.imageKey))
      }
      steps.append(RosaryStep(title: "Glory Be", subtitle: nil, body: text(.gloriaPatri), imageOverrideKey: "glory_be"))
    }

    let fruitLabel = text(.fructusMysteriiLabel)
    let showGroupName = groups.count > 1
    var decadeIndex = 0

    for group in groups {
      let mysteries = MysteryCatalog.forGroup(group)
      let indices = rosary.mysterySelectionMode == .singleMystery
        ? [rosary.specificMysteryOrder - 1]
        : Array(mysteries.indices)

      for d in indices {
        let mystery = mysteries[d]
        let mysteryText = MysteryTranslations.get(languageCode: lang, imageKey: mystery.imageKey)
        let ordinalLabel = showGroupName ? "\(group.displayName) — \(Self.ordinals[d]) Mystery" : "\(Self.ordinals[d]) Mystery"
        let decadeSubtitle = "\(ordinalLabel) — \(mysteryText.title)"

        if rosary.presenterMode {
          steps.append(RosaryStep(
            title: mysteryText.title, subtitle: ordinalLabel,
            body: "\(mysteryText.description)\n\n\(fruitLabel): \(mysteryText.fruit)",
            mystery: mystery, isScripture: true, decadeIndex: decadeIndex))
          steps.append(RosaryStep(
            title: "Our Father", subtitle: decadeSubtitle, body: text(.paterNoster),
            decadeIndex: decadeIndex, imageOverrideKey: "our_father"))
          steps.append(RosaryStep(
            title: "Hail Mary & Glory Be", subtitle: decadeSubtitle,
            body: "\(text(.aveMaria))\n\n\(text(.gloriaPatri))",
            mystery: mystery, decadeIndex: decadeIndex, hailMaryIndexInDecade: 10))
        } else {
          steps.append(contentsOf: buildDecadeSteps(
            decadeIndex: decadeIndex,
            announcementTitle: mysteryText.title, ordinalLabel: ordinalLabel,
            announcementBody: "\(mysteryText.description)\n\n\(fruitLabel): \(mysteryText.fruit)",
            mystery: mystery, decadeImageKey: nil, isScripture: true,
            ourFatherImageKey: "our_father", hailMarysPerDecade: 10, languageCode: lang))

          steps.append(RosaryStep(
            title: "Glory Be", subtitle: decadeSubtitle, body: text(.gloriaPatri),
            decadeIndex: decadeIndex, imageOverrideKey: "glory_be"))
        }

        if rosary.includeFatimaPrayer {
          steps.append(RosaryStep(
            title: "Fatima Prayer", subtitle: decadeSubtitle, body: text(.oratioFatimae),
            decadeIndex: decadeIndex, imageOverrideKey: "jesus_portrait"))
        }

        if rosary.eternalRestForDeceased == .afterEachDecade {
          steps.append(RosaryStep(
            title: "For the Faithful Departed", subtitle: decadeSubtitle, body: text(.requiemAeternam),
            decadeIndex: decadeIndex, imageOverrideKey: "eternal_rest"))
        }

        decadeIndex += 1
      }
    }

    if let antiphon = resolveMarianAntiphon(for: rosary) {
      steps.append(buildMarianAntiphonStep(antiphon, languageCode: lang))
    }

    if rosary.includeStMichaelPrayer {
      steps.append(RosaryStep(title: "St. Michael the Archangel", subtitle: nil, body: text(.sanctusMichael), imageOverrideKey: "st_michael"))
    }

    if rosary.eternalRestForDeceased == .atEndOnly {
      steps.append(RosaryStep(title: "For the Faithful Departed", subtitle: nil, body: text(.requiemAeternam), imageOverrideKey: "eternal_rest"))
    }

    if rosary.includeFinalSignOfCross {
      steps.append(RosaryStep(title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis), imageOverrideKey: "crucifix"))
    }

    return steps
  }

  private func resolveMarianAntiphon(for rosary: RosaryOptions) -> MarianAntiphonOption? {
    switch rosary.marianAntiphon {
    case .none: return nil
    case .seasonal: return calendar.seasonalMarianAntiphonToday()
    case let chosen: return chosen
    }
  }

  // MARK: - Shared decade-building helper (the Rosary's inner loop)

  /// Builds one decade: an announcement step, an Our Father step, and `hailMarysPerDecade` Hail
  /// Mary steps. `mystery`/`decadeImageKey` together control each step's illustration — pass a
  /// real `Mystery` (Rosary) to let steps fall through to its own `imageKey`, or `nil` mystery
  /// plus an explicit `decadeImageKey` (Franciscan Crown/Seven Sorrows, whose catalogs are plain
  /// imageKey strings, not `Mystery`-typed). `ourFatherImageKey` is separate from
  /// `decadeImageKey` because the Rosary's Our Father step always shows a fixed generic icon
  /// ("our_father") between mystery-specific images, while Franciscan Crown/Seven Sorrows keep
  /// showing that decade's own illustration straight through — a real, deliberate difference
  /// between how these devotions render, not an inconsistency to paper over.
  private func buildDecadeSteps(
    decadeIndex: Int,
    announcementTitle: String, ordinalLabel: String, announcementBody: String,
    mystery: Mystery?, decadeImageKey: String?, isScripture: Bool,
    ourFatherImageKey: String?, hailMarysPerDecade: Int, languageCode: String?
  ) -> [RosaryStep] {
    func text(_ key: PrayerKey) -> String {
      PrayerTranslations.get(languageCode: languageCode, key: key)
    }

    let decadeSubtitle = "\(ordinalLabel) — \(announcementTitle)"

    var steps: [RosaryStep] = [
      RosaryStep(
        title: announcementTitle, subtitle: ordinalLabel, body: announcementBody,
        mystery: mystery, isScripture: isScripture, decadeIndex: decadeIndex, imageOverrideKey: decadeImageKey),
      RosaryStep(
        title: "Our Father", subtitle: decadeSubtitle, body: text(.paterNoster),
        decadeIndex: decadeIndex, imageOverrideKey: ourFatherImageKey),
    ]

    for h in 1...hailMarysPerDecade {
      steps.append(RosaryStep(
        title: "Hail Mary (\(h) of \(hailMarysPerDecade))", subtitle: decadeSubtitle, body: text(.aveMaria),
        mystery: mystery, decadeIndex: decadeIndex, hailMaryIndexInDecade: h, imageOverrideKey: decadeImageKey))
    }

    return steps
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
  private func buildCustomDevotionSteps(bundleId: String, languageCode: String?) -> [RosaryStep] {
    guard let definition = PrayerPackStore.definition(for: bundleId) else { return [] }
    switch definition.type {
    case .steps:
      let entries = (calendar.isEasterSeasonToday() ? definition.eastertideSteps : nil)
        ?? definition.steps ?? []
      return entries.flatMap { expand($0, bundleId: bundleId, languageCode: languageCode) }
    case .rosary:
      return buildCustomRosarySteps(definition, bundleId: bundleId, languageCode: languageCode)
    }
  }

  /// Expands one `devotion.json` entry into its step(s): resolves the title (literal or
  /// translated `titleKey`) and body, and unrolls `repeat` into "(h of n)"-suffixed copies —
  /// deliberately without bead fields, matching the hardcoded devotions' closing Hail Marys.
  private func expand(_ entry: CustomDevotionStep, bundleId: String, languageCode: String?) -> [RosaryStep] {
    if entry.kind == .seasonalMarianAntiphon {
      return [buildMarianAntiphonStep(calendar.seasonalMarianAntiphonToday(), languageCode: languageCode)]
    }
    let title = entry.titleKey.map {
      PrayerPackStore.resolveBodyText(bundleId: bundleId, languageCode: languageCode, key: $0)
    } ?? entry.title ?? ""
    let body = entry.bodyKey.map {
      PrayerPackStore.resolveBodyText(bundleId: bundleId, languageCode: languageCode, key: $0)
    } ?? ""

    guard let count = entry.repeatCount, count > 1 else {
      return [RosaryStep(title: title, subtitle: entry.subtitle, body: body, imageOverrideKey: entry.imageKey)]
    }
    return (1...count).map { h in
      RosaryStep(
        title: "\(title) (\(h) of \(count))", subtitle: entry.subtitle, body: body,
        imageOverrideKey: entry.imageKey)
    }
  }

  /// The decade/bead-structured generic builder ("rosary" type) — mirrors `buildDecadeSteps`'s
  /// emission exactly (announcement → major → N minors, dense global `decadeIndex`,
  /// `hailMaryIndexInDecade` on minors only, "ordinal — title" subtitles) so the bead track and
  /// step chrome behave identically to the previously hardcoded decade devotions.
  private func buildCustomRosarySteps(
    _ definition: CustomDevotionDefinition, bundleId: String, languageCode: String?
  ) -> [RosaryStep] {
    guard let decades = definition.decades else { return [] }
    func resolve(_ key: String) -> String {
      PrayerPackStore.resolveBodyText(bundleId: bundleId, languageCode: languageCode, key: key)
    }

    var steps: [RosaryStep] = []
    for entry in definition.opening ?? [] {
      steps.append(contentsOf: expand(entry, bundleId: bundleId, languageCode: languageCode))
    }

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
        decadeIndex: d, imageOverrideKey: imageKey))

      for h in 1...decades.minorCount {
        steps.append(RosaryStep(
          title: "\(decades.minorStep.title) (\(h) of \(decades.minorCount))",
          subtitle: decadeSubtitle, body: minorBody,
          decadeIndex: d, hailMaryIndexInDecade: h, imageOverrideKey: imageKey))
      }
    }

    for entry in definition.closing ?? [] {
      steps.append(contentsOf: expand(entry, bundleId: bundleId, languageCode: languageCode))
    }
    return steps
  }
}

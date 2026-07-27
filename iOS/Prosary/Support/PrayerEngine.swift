//
//  PrayerEngine.swift
//  Prosary
//
//  The single production step-builder for every devotion. `buildSteps(for:)` dispatches on
//  `Prayer.kind` to one of 6 private builders. Angelus/Stations have no decades and a different
//  per-item template each, so they keep their own builders rather than being forced through the
//  decade-shaped helper below; Divine Mercy Chaplet has no catalog (it repeats the same 2 lines
//  every decade, not per-decade content), so it doesn't fit the catalog-driven shape either.
//  Rosary's per-group decade loop and Franciscan Crown/Seven Sorrows' single decade loop DO share
//  the same underlying shape (announce → Our Father → N Hail Marys) — that shared shape is
//  `buildDecadeSteps`, the one genuine algorithmic unification here, not just an interface merge.
//
//  Replaces 6 protocols (RosaryEngine/AngelusEngine/StationsEngine/FranciscanCrownEngine/
//  SevenSorrowsEngine/DivineMercyEngine) and their Stub (production) + Mock (thin
//  calendar-injecting wrapper for Previews/tests) implementations. Calendar injection — the
//  reason the Stub/Mock split existed — is preserved via this type's own initializer instead, the
//  same way `StubRosaryEngine`/`StubFranciscanCrownEngine` already did it.
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
    case .angelus:
      return buildAngelusSteps(languageCode: prayer.languageCode)
    case .jesusPrayer:
      // The Jesus Prayer has no engine — every repetition prays the same fixed line, so a
      // single synthesized step plus a JesusPrayerProgress counter is the whole model; see
      // JesusPrayerFlowView, which never calls this engine at all.
      return []
    case .stationsOfTheCross:
      return buildStationsSteps(languageCode: prayer.languageCode)
    case .franciscanCrown:
      return buildFranciscanCrownSteps(languageCode: prayer.languageCode)
    case .sevenSorrows:
      return buildSevenSorrowsSteps(languageCode: prayer.languageCode)
    case .divineMercyChaplet:
      return buildDivineMercySteps(languageCode: prayer.languageCode)
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

  // MARK: - Shared decade-building helper (Rosary's inner loop, Franciscan Crown, Seven Sorrows)

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

  // MARK: - Franciscan Crown

  private func buildFranciscanCrownSteps(languageCode: String?) -> [RosaryStep] {
    func text(_ key: PrayerKey) -> String {
      PrayerTranslations.get(languageCode: languageCode, key: key)
    }

    var steps: [RosaryStep] = []

    steps.append(RosaryStep(title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis), imageOverrideKey: "crucifix"))

    let fruitLabel = text(.fructusMysteriiLabel)

    for (d, imageKey) in FranciscanCrownCatalog.sevenJoys.enumerated() {
      let joyText = MysteryTranslations.get(languageCode: languageCode, imageKey: imageKey)
      let ordinalLabel = "\(Self.ordinals[d]) Joy"

      steps.append(contentsOf: buildDecadeSteps(
        decadeIndex: d, announcementTitle: joyText.title, ordinalLabel: ordinalLabel,
        announcementBody: "\(joyText.description)\n\n\(fruitLabel): \(joyText.fruit)",
        mystery: nil, decadeImageKey: imageKey, isScripture: true,
        ourFatherImageKey: imageKey, hailMarysPerDecade: 10, languageCode: languageCode))
    }

    for h in 1...2 {
      steps.append(RosaryStep(
        title: "Hail Mary (\(h) of 2)", subtitle: "For the years of Our Lady's life",
        body: text(.aveMaria), imageOverrideKey: "madonna_and_child"))
    }

    steps.append(RosaryStep(
      title: "Our Father", subtitle: "For the intentions of the Holy Father",
      body: text(.paterNoster), imageOverrideKey: "our_father"))

    steps.append(buildMarianAntiphonStep(calendar.seasonalMarianAntiphonToday(), languageCode: languageCode))

    steps.append(RosaryStep(title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis), imageOverrideKey: "crucifix"))

    return steps
  }

  // MARK: - Seven Sorrows

  private func buildSevenSorrowsSteps(languageCode: String?) -> [RosaryStep] {
    func text(_ key: PrayerKey) -> String {
      PrayerTranslations.get(languageCode: languageCode, key: key)
    }

    var steps: [RosaryStep] = []

    steps.append(RosaryStep(title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis), imageOverrideKey: "crucifix"))

    let fruitLabel = text(.fructusMysteriiLabel)

    for (d, imageKey) in SevenSorrowsCatalog.sevenSorrows.enumerated() {
      let sorrowText = MysteryTranslations.get(languageCode: languageCode, imageKey: imageKey)
      let ordinalLabel = "\(Self.ordinals[d]) Sorrow"

      steps.append(contentsOf: buildDecadeSteps(
        decadeIndex: d, announcementTitle: sorrowText.title, ordinalLabel: ordinalLabel,
        announcementBody: "\(sorrowText.description)\n\n\(fruitLabel): \(sorrowText.fruit)",
        mystery: nil, decadeImageKey: imageKey, isScripture: d != SevenSorrowsCatalog.meetingOnTheWayIndex,
        ourFatherImageKey: imageKey, hailMarysPerDecade: 7, languageCode: languageCode))
    }

    for h in 1...3 {
      steps.append(RosaryStep(
        title: "Hail Mary (\(h) of 3)", subtitle: "For the tears of Our Lady",
        body: text(.aveMaria), imageOverrideKey: "madonna_and_child"))
    }

    steps.append(RosaryStep(
      title: "Our Lady of Sorrows", subtitle: nil,
      body: "V. \(text(.sevenSorrowsVersicle))\nR. \(text(.sevenSorrowsResponse))\n\n\(text(.sevenSorrowsCollect))",
      imageOverrideKey: "madonna_and_child"))

    steps.append(RosaryStep(title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis), imageOverrideKey: "crucifix"))

    return steps
  }

  // MARK: - Divine Mercy Chaplet

  private func buildDivineMercySteps(languageCode: String?) -> [RosaryStep] {
    let imageKey = "divine_mercy_image"

    func text(_ key: PrayerKey) -> String {
      PrayerTranslations.get(languageCode: languageCode, key: key)
    }

    var steps: [RosaryStep] = []

    steps.append(RosaryStep(title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis), imageOverrideKey: imageKey))
    steps.append(RosaryStep(title: "Our Father", subtitle: nil, body: text(.paterNoster), imageOverrideKey: imageKey))
    steps.append(RosaryStep(title: "Hail Mary", subtitle: nil, body: text(.aveMaria), imageOverrideKey: imageKey))
    steps.append(RosaryStep(title: "The Apostles' Creed", subtitle: nil, body: text(.symbolumApostolorum), imageOverrideKey: imageKey))

    for d in 0..<5 {
      let decadeSubtitle = "\(Self.ordinals[d]) Decade"

      steps.append(RosaryStep(
        title: "Eternal Father, I Offer You...", subtitle: decadeSubtitle, body: text(.divineMercyOffering),
        decadeIndex: d, imageOverrideKey: imageKey))

      for h in 1...10 {
        steps.append(RosaryStep(
          title: "For the Sake of His Sorrowful Passion (\(h) of 10)", subtitle: decadeSubtitle,
          body: text(.divineMercyPetition), decadeIndex: d, hailMaryIndexInDecade: h, imageOverrideKey: imageKey))
      }
    }

    for h in 1...3 {
      steps.append(RosaryStep(
        title: "Holy God, Holy Mighty One, Holy Immortal One (\(h) of 3)", subtitle: nil,
        body: text(.divineMercyClosingAcclamation), imageOverrideKey: imageKey))
    }

    steps.append(RosaryStep(title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis), imageOverrideKey: imageKey))

    return steps
  }

  // MARK: - Angelus

  private func buildAngelusSteps(languageCode: String?) -> [RosaryStep] {
    func text(_ key: PrayerKey) -> String {
      PrayerTranslations.get(languageCode: languageCode, key: key)
    }

    if calendar.isEasterSeasonToday() {
      // During Eastertide the Angelus is traditionally replaced entirely by the Regina Caeli.
      let body = "\(text(.reginaCaeli))\n\nV. \(text(.versiculumPaschale))\nR. \(text(.responsiumPaschale))\n\n\(text(.collectaPaschale))"
      return [RosaryStep(title: "Regina Caeli", subtitle: nil, body: body, imageOverrideKey: "madonna_and_child")]
    }

    return [
      RosaryStep(
        title: "The Annunciation", subtitle: nil,
        body: "V. \(text(.versiculumAngelusPrimus))\nR. \(text(.responsiumAngelusPrimus))",
        imageOverrideKey: "joyful_01_annunciation"),
      RosaryStep(title: "Hail Mary", subtitle: nil, body: text(.aveMaria), imageOverrideKey: "joyful_01_annunciation"),

      RosaryStep(
        title: "The Fiat", subtitle: nil,
        body: "V. \(text(.versiculumAngelusSecundus))\nR. \(text(.responsiumAngelusSecundus))",
        imageOverrideKey: "joyful_01_annunciation"),
      RosaryStep(title: "Hail Mary", subtitle: nil, body: text(.aveMaria), imageOverrideKey: "joyful_01_annunciation"),

      RosaryStep(
        title: "The Incarnation", subtitle: nil,
        body: "V. \(text(.versiculumAngelusTertius))\nR. \(text(.responsiumAngelusTertius))",
        imageOverrideKey: "joyful_01_annunciation"),
      RosaryStep(title: "Hail Mary", subtitle: nil, body: text(.aveMaria), imageOverrideKey: "joyful_01_annunciation"),

      RosaryStep(
        title: "Let Us Pray", subtitle: nil,
        body: "V. \(text(.versiculumStandard))\nR. \(text(.responsiumStandard))\n\n\(text(.collectaAngelus))",
        imageOverrideKey: "joyful_01_annunciation"),
    ]
  }

  // MARK: - Stations of the Cross

  private func buildStationsSteps(languageCode: String?) -> [RosaryStep] {
    func text(_ key: PrayerKey) -> String {
      PrayerTranslations.get(languageCode: languageCode, key: key)
    }

    var steps: [RosaryStep] = []

    steps.append(RosaryStep(
      title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis),
      imageOverrideKey: "crucifix"))

    steps.append(RosaryStep(
      title: "Opening Prayer", subtitle: nil, body: text(.stationsOpeningPrayer),
      imageOverrideKey: "crucifix"))

    for station in StationsCatalog.all {
      let stationText = StationsTranslations.get(languageCode: languageCode, imageKey: station.imageKey)
      let ordinalLabel = "\(Self.ordinals[station.order - 1]) Station"
      let body = "V. \(text(.stationsVersicle))\nR. \(text(.stationsResponse))\n\n\(stationText.meditation)"

      steps.append(RosaryStep(
        title: stationText.title, subtitle: ordinalLabel, body: body,
        imageOverrideKey: station.imageKey))
    }

    steps.append(RosaryStep(
      title: "Closing Prayer", subtitle: nil, body: text(.stationsClosingPrayer),
      imageOverrideKey: "crucifix"))

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
      body = "\(text(titleKey))\n\nV. \(text(.versiculumStandard))\nR. \(text(.responsiumStandard))\n\n\(text(.collectaStandard))"
    case .paschal:
      body = "\(text(titleKey))\n\nV. \(text(.versiculumPaschale))\nR. \(text(.responsiumPaschale))\n\n\(text(.collectaPaschale))"
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
}

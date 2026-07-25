
//
//  StubRosaryEngine.swift
//  Prosary
//
//  Production RosaryEngine — builds the full, ordered sequence of steps for a Rosary session
//  from a Prayer's RosaryOptions and language. Used by AppServices.shared; MockRosaryEngine
//  delegates here so previews and tests use the same logic.
//

import Foundation

struct StubRosaryEngine: RosaryEngine {
  private static let ordinals = ["1st", "2nd", "3rd", "4th", "5th"]

  private static let virtues: [(key: PrayerKey, imageKey: String)] = [
    (.aveMariaProFide, "virtue_faith"),
    (.aveMariaProSpe, "virtue_hope"),
    (.aveMariaProCaritate, "virtue_charity"),
  ]

  private let calendar: LiturgicalCalendarProviding

  init(calendar: LiturgicalCalendarProviding = StubLiturgicalCalendar()) {
    self.calendar = calendar
  }

  func resolveMysteryGroups(for prayer: Prayer) -> [MysteryGroup] {
    switch prayer.rosary.mysterySelectionMode {
    case .specific:
      return [prayer.rosary.specificMysteryGroup]
    case .fifteenMystery:
      return [.joyful, .sorrowful, .glorious]
    case .twentyMystery:
      return [.joyful, .luminous, .sorrowful, .glorious]
    case .todaysMysteries:
      return [calendar.mysteryGroupToday()]
    }
  }

  func buildSteps(for prayer: Prayer) -> [RosaryStep] {
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

      for (d, mystery) in mysteries.enumerated() {
        let mysteryText = MysteryTranslations.get(languageCode: lang, imageKey: mystery.imageKey)
        let ordinalLabel = showGroupName ? "\(group.displayName) — \(Self.ordinals[d]) Mystery" : "\(Self.ordinals[d]) Mystery"
        let decadeSubtitle = "\(ordinalLabel) — \(mysteryText.title)"
        let thisDecade = decadeIndex

        steps.append(RosaryStep(
          title: mysteryText.title, subtitle: ordinalLabel,
          body: "\(mysteryText.description)\n\n\(fruitLabel): \(mysteryText.fruit)",
          mystery: mystery, isScripture: true, decadeIndex: thisDecade))

        steps.append(RosaryStep(
          title: "Our Father", subtitle: decadeSubtitle, body: text(.paterNoster),
          decadeIndex: thisDecade, imageOverrideKey: "our_father"))

        for h in 1...10 {
          steps.append(RosaryStep(
            title: "Hail Mary (\(h) of 10)", subtitle: decadeSubtitle, body: text(.aveMaria),
            mystery: mystery, decadeIndex: thisDecade, hailMaryIndexInDecade: h))
        }

        steps.append(RosaryStep(
          title: "Glory Be", subtitle: decadeSubtitle, body: text(.gloriaPatri),
          decadeIndex: thisDecade, imageOverrideKey: "glory_be"))

        if rosary.includeFatimaPrayer {
          steps.append(RosaryStep(
            title: "Fatima Prayer", subtitle: decadeSubtitle, body: text(.oratioFatimae),
            decadeIndex: thisDecade, imageOverrideKey: "jesus_portrait"))
        }

        if rosary.eternalRestForDeceased == .afterEachDecade {
          steps.append(RosaryStep(
            title: "For the Faithful Departed", subtitle: decadeSubtitle, body: text(.requiemAeternam),
            decadeIndex: thisDecade, imageOverrideKey: "eternal_rest"))
        }

        decadeIndex += 1
      }
    }

    if let antiphon = resolveMarianAntiphon(for: rosary) {
      var antiphonStep = buildAntiphonStep(antiphon, text: text)
      antiphonStep.isAntiphon = true
      antiphonStep.imageOverrideKey = "madonna_and_child"
      steps.append(antiphonStep)
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

  private enum AntiphonStyle { case standard, paschal, standalone }

  private func buildAntiphonStep(_ antiphon: MarianAntiphonOption, text: (PrayerKey) -> String) -> RosaryStep {
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

    return RosaryStep(title: antiphonHeader(for: antiphon), subtitle: nil, body: body)
  }

  private func antiphonHeader(for antiphon: MarianAntiphonOption) -> String {
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

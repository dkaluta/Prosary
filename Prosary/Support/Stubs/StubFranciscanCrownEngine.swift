//
//  StubFranciscanCrownEngine.swift
//  Prosary
//
//  Production FranciscanCrownEngine — builds the fixed sequence of steps for a Franciscan Crown
//  session: Sign of the Cross, the Seven Joys of Mary (each a decade of an Our Father + 10 Hail
//  Marys), 2 additional Hail Marys (for the 72 years traditionally attributed to Our Lady's
//  life) + an Our Father (for the Pope's intentions), the seasonal Marian antiphon, and a closing
//  Sign of the Cross. Used by AppServices.shared; MockFranciscanCrownEngine delegates here.
//

import Foundation

struct StubFranciscanCrownEngine: FranciscanCrownEngine {
  private static let ordinals = ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th"]

  private let calendar: LiturgicalCalendarProviding

  init(calendar: LiturgicalCalendarProviding = StubLiturgicalCalendar()) {
    self.calendar = calendar
  }

  func buildSteps(languageCode: String?) -> [RosaryStep] {
    func text(_ key: PrayerKey) -> String {
      PrayerTranslations.get(languageCode: languageCode, key: key)
    }

    var steps: [RosaryStep] = []

    steps.append(RosaryStep(title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis), imageOverrideKey: "crucifix"))

    let fruitLabel = text(.fructusMysteriiLabel)

    for (d, imageKey) in FranciscanCrownCatalog.sevenJoys.enumerated() {
      let joyText = MysteryTranslations.get(languageCode: languageCode, imageKey: imageKey)
      let ordinalLabel = "\(Self.ordinals[d]) Joy"
      let decadeSubtitle = "\(ordinalLabel) — \(joyText.title)"

      steps.append(RosaryStep(
        title: joyText.title, subtitle: ordinalLabel,
        body: "\(joyText.description)\n\n\(fruitLabel): \(joyText.fruit)",
        isScripture: true, decadeIndex: d, imageOverrideKey: imageKey))

      steps.append(RosaryStep(
        title: "Our Father", subtitle: decadeSubtitle, body: text(.paterNoster),
        decadeIndex: d, imageOverrideKey: imageKey))

      for h in 1...10 {
        steps.append(RosaryStep(
          title: "Hail Mary (\(h) of 10)", subtitle: decadeSubtitle, body: text(.aveMaria),
          decadeIndex: d, hailMaryIndexInDecade: h, imageOverrideKey: imageKey))
      }
    }

    for h in 1...2 {
      steps.append(RosaryStep(
        title: "Hail Mary (\(h) of 2)", subtitle: "For the years of Our Lady's life",
        body: text(.aveMaria), imageOverrideKey: "madonna_and_child"))
    }

    steps.append(RosaryStep(
      title: "Our Father", subtitle: "For the intentions of the Holy Father",
      body: text(.paterNoster), imageOverrideKey: "our_father"))

    steps.append(MarianAntiphonBuilder.buildStep(calendar.seasonalMarianAntiphonToday(), languageCode: languageCode))

    steps.append(RosaryStep(title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis), imageOverrideKey: "crucifix"))

    return steps
  }
}

//
//  StubSevenSorrowsEngine.swift
//  Prosary
//
//  Production SevenSorrowsEngine — builds the fixed sequence of steps for a Seven Sorrows
//  session: Sign of the Cross, the Seven Sorrows of Mary (each a decade of an Our Father + 7
//  Hail Marys — 7, not 10, per traditional practice), 3 additional Hail Marys (for Our Lady's
//  tears), a fixed closing versicle/response/collect (unlike the Rosary/Franciscan Crown, this
//  isn't a user choice — the Seven Sorrows always closes the same way), and a closing Sign of the
//  Cross. Used by AppServices.shared; MockSevenSorrowsEngine delegates here.
//

import Foundation

struct StubSevenSorrowsEngine: SevenSorrowsEngine {
  private static let ordinals = ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th"]

  func buildSteps(languageCode: String?) -> [RosaryStep] {
    func text(_ key: PrayerKey) -> String {
      PrayerTranslations.get(languageCode: languageCode, key: key)
    }

    var steps: [RosaryStep] = []

    steps.append(RosaryStep(title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis), imageOverrideKey: "crucifix"))

    let fruitLabel = text(.fructusMysteriiLabel)

    for (d, imageKey) in SevenSorrowsCatalog.sevenSorrows.enumerated() {
      let sorrowText = MysteryTranslations.get(languageCode: languageCode, imageKey: imageKey)
      let ordinalLabel = "\(Self.ordinals[d]) Sorrow"
      let decadeSubtitle = "\(ordinalLabel) — \(sorrowText.title)"

      steps.append(RosaryStep(
        title: sorrowText.title, subtitle: ordinalLabel,
        body: "\(sorrowText.description)\n\n\(fruitLabel): \(sorrowText.fruit)",
        isScripture: d != SevenSorrowsCatalog.meetingOnTheWayIndex, decadeIndex: d, imageOverrideKey: imageKey))

      steps.append(RosaryStep(
        title: "Our Father", subtitle: decadeSubtitle, body: text(.paterNoster),
        decadeIndex: d, imageOverrideKey: imageKey))

      for h in 1...7 {
        steps.append(RosaryStep(
          title: "Hail Mary (\(h) of 7)", subtitle: decadeSubtitle, body: text(.aveMaria),
          decadeIndex: d, hailMaryIndexInDecade: h, imageOverrideKey: imageKey))
      }
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
}

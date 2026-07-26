//
//  StubStationsEngine.swift
//  Prosary
//
//  Production StationsEngine — builds the opening prayer, the fourteen stations (each announced
//  with the traditional versicle/response before its meditation), and the closing prayer. Used
//  by AppServices.shared; MockStationsEngine delegates here. Unlike the Rosary/Franciscan Crown/
//  Seven Sorrows/Divine Mercy Chaplet, there's no decade/bead math at all — every step leaves
//  `mystery`/`decadeIndex`/`hailMaryIndexInDecade` at their nil defaults, same as StubAngelusEngine.
//

import Foundation

struct StubStationsEngine: StationsEngine {
  private static let ordinals = [
    "1st", "2nd", "3rd", "4th", "5th", "6th", "7th",
    "8th", "9th", "10th", "11th", "12th", "13th", "14th",
  ]

  func buildSteps(languageCode: String?) -> [RosaryStep] {
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
}

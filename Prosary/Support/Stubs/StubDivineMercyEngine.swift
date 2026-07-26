//
//  StubDivineMercyEngine.swift
//  Prosary
//
//  Production DivineMercyEngine — builds the fixed sequence of steps for a Divine Mercy Chaplet
//  session: Sign of the Cross, Our Father, Hail Mary, the Apostles' Creed (the traditional
//  opening, reusing existing PrayerKeys — nothing new needed there), 5 decades each of one
//  offering ("Eternal Father, I offer You...") at the Our-Father-bead position and 10 petitions
//  ("For the sake of His sorrowful Passion...") at the Hail-Mary-bead positions — the same two
//  lines every decade, unlike the Rosary/Franciscan Crown/Seven Sorrows — closing with the
//  acclamation ("Holy God, Holy Mighty One, Holy Immortal One...") prayed three times, and a
//  closing Sign of the Cross. Every step reuses the single `divine_mercy_image` illustration, the
//  same reuse pattern the Angelus uses for `joyful_01_annunciation`. Used by AppServices.shared;
//  MockDivineMercyEngine delegates here.
//

import Foundation

struct StubDivineMercyEngine: DivineMercyEngine {
  private static let imageKey = "divine_mercy_image"

  func buildSteps(languageCode: String?) -> [RosaryStep] {
    func text(_ key: PrayerKey) -> String {
      PrayerTranslations.get(languageCode: languageCode, key: key)
    }

    var steps: [RosaryStep] = []

    steps.append(RosaryStep(title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis), imageOverrideKey: Self.imageKey))
    steps.append(RosaryStep(title: "Our Father", subtitle: nil, body: text(.paterNoster), imageOverrideKey: Self.imageKey))
    steps.append(RosaryStep(title: "Hail Mary", subtitle: nil, body: text(.aveMaria), imageOverrideKey: Self.imageKey))
    steps.append(RosaryStep(title: "The Apostles' Creed", subtitle: nil, body: text(.symbolumApostolorum), imageOverrideKey: Self.imageKey))

    let ordinals = ["1st", "2nd", "3rd", "4th", "5th"]
    for d in 0..<5 {
      let decadeSubtitle = "\(ordinals[d]) Decade"

      steps.append(RosaryStep(
        title: "Eternal Father, I Offer You...", subtitle: decadeSubtitle, body: text(.divineMercyOffering),
        decadeIndex: d, imageOverrideKey: Self.imageKey))

      for h in 1...10 {
        steps.append(RosaryStep(
          title: "For the Sake of His Sorrowful Passion (\(h) of 10)", subtitle: decadeSubtitle,
          body: text(.divineMercyPetition), decadeIndex: d, hailMaryIndexInDecade: h, imageOverrideKey: Self.imageKey))
      }
    }

    for h in 1...3 {
      steps.append(RosaryStep(
        title: "Holy God, Holy Mighty One, Holy Immortal One (\(h) of 3)", subtitle: nil,
        body: text(.divineMercyClosingAcclamation), imageOverrideKey: Self.imageKey))
    }

    steps.append(RosaryStep(title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis), imageOverrideKey: Self.imageKey))

    return steps
  }
}

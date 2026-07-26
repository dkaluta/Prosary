//
//  FranciscanCrownCatalog.swift
//  Prosary
//
//  The fixed, ordered list of the Seven Joys of Mary prayed in the Franciscan Crown. Deliberately
//  a plain list of imageKey strings rather than `Mystery`/`MysteryGroup`-typed data (unlike
//  MysteryCatalog) — the Seven Joys aren't a Rosary "mystery group" and adding one as a case on
//  MysteryGroup would pollute a type that's otherwise exclusively about the 4 traditional Rosary
//  sets. Six of the seven reuse existing Rosary mystery imageKeys/content outright (Annunciation,
//  Visitation, Nativity, Finding in the Temple, Resurrection, Coronation); only the Adoration of
//  the Magi is genuinely new content — see MysteryTranslations+English.swift/+Latin.swift.
//

import Foundation

enum FranciscanCrownCatalog {
  static let sevenJoys: [String] = [
    "joyful_01_annunciation",
    "joyful_02_visitation",
    "joyful_03_nativity",
    "franciscan_04_adoration_of_the_magi",
    "joyful_05_finding_in_the_temple",
    "glorious_01_resurrection",
    "glorious_05_coronation",
  ]
}

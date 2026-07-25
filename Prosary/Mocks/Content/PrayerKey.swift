//
//  PrayerKey.swift
//  Prosary
//
//  Stable, language-independent identifiers for each fixed prayer text, used by the mock
//  content layer (Mocks/Content) that drives Previews and interactive testing today.
//

import Foundation

enum PrayerKey: String, CaseIterable {
  case signumCrucis
  case symbolumApostolorum
  case paterNoster
  case aveMaria
  case gloriaPatri

  /// "For thine is the kingdom..." — not currently used in the Rosary flow itself; kept for future use.
  case doxologiaMinor

  case oratioFatimae
  case requiemAeternam
  case sanctusMichael

  case salveRegina
  case almaRedemptorisMater
  case aveReginaCaelorum
  case reginaCaeli

  /// The oldest known Marian prayer; traditionally recited on its own, without a versicle/collect.
  case subTuumPraesidium

  case versiculumStandard
  case responsiumStandard
  case collectaStandard
  case versiculumPaschale
  case responsiumPaschale
  case collectaPaschale

  /// The opening Hail Mary said for an increase of Faith.
  case aveMariaProFide
  /// The opening Hail Mary said for an increase of Hope.
  case aveMariaProSpe
  /// The opening Hail Mary said for an increase of Charity.
  case aveMariaProCaritate

  case fructusMysteriiLabel

  // The Angelus's three versicle/response pairs (Annunciation / Fiat / Incarnation) and its own
  // closing collect — distinct from `collectaStandard` (the Rosary's collect) and
  // `collectaPaschale` (reused verbatim for the Angelus's Eastertide/Regina Caeli substitution).
  case versiculumAngelusPrimus
  case responsiumAngelusPrimus
  case versiculumAngelusSecundus
  case responsiumAngelusSecundus
  case versiculumAngelusTertius
  case responsiumAngelusTertius
  case collectaAngelus

  /// The Jesus Prayer ("Lord Jesus Christ, Son of God, have mercy on me, a sinner.").
  case oratioIesu
}

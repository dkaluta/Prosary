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

  // Stations of the Cross — the versicle/response repeated before each of the 14 stations, plus
  // its own opening and closing prayers. Per-station meditation text lives in StationsTranslations
  // (mirroring how MysteryTranslations holds per-mystery text), not here.
  case stationsOpeningPrayer
  case stationsVersicle
  case stationsResponse
  case stationsClosingPrayer

  // Seven Sorrows (Servite Rosary) — the versicle/response and closing collect prayed after the
  // 3 closing Hail Marys for Our Lady's tears. Unlike the Rosary's Marian antiphon, this closing
  // is fixed, not a user choice (see PrayerEngine). Per-sorrow meditation text lives in
  // MysteryTranslations (reusing the same imageKey-keyed lookup Franciscan Crown's Adoration of
  // the Magi uses), not here.
  case sevenSorrowsVersicle
  case sevenSorrowsResponse
  case sevenSorrowsCollect

  // The Divine Mercy Chaplet — the Our-Father-bead offering, the Hail-Mary-bead petition (each
  // repeated identically across all 5 decades, unlike the Rosary/Franciscan Crown/Seven Sorrows,
  // which vary per decade), and the closing acclamation (repeated 3 times). The opening (Sign of
  // the Cross, Our Father, Hail Mary, Apostles' Creed) reuses existing keys — see
  // PrayerEngine.
  case divineMercyOffering
  case divineMercyPetition
  case divineMercyClosingAcclamation
}

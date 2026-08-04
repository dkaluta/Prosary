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

  /// Headings for the antiphon step — the antiphon named in the praying language
  /// (Latin keeps the incipit the antiphons are known by).
  case salveReginaTitle
  case almaRedemptorisMaterTitle
  case aveReginaCaelorumTitle
  case reginaCaeliTitle
  case subTuumPraesidiumTitle

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

  /// The connector in a repeated step's "(3 of 10)" counter — in the language being prayed,
  /// so a Hebrew Hail Mary reads "(3 מתוך 10)" instead of splicing an English word into
  /// right-to-left text (where bidi reordered it into nonsense).
  case repetitionCounterConnector

  /// How a decade's ordinal reads: "{n}" is the number (an English ordinal word for English,
  /// a digit elsewhere — English is the only one of the six that inflects it) and "{noun}" is
  /// the bundle's own `decadeOrdinalNoun`. A template rather than a printf format so all three
  /// platforms carry the identical string.
  case decadeOrdinalFormat

  /// The Jesus Prayer ("Lord Jesus Christ, Son of God, have mercy on me, a sinner.").
  case oratioIesu

  /// Anima Christi ("Soul of Christ") — traditionally prayed after Communion and at the close
  /// of the Way of the Cross. A shared "main" prayer: hardcoded in every language, deliberately
  /// absent from bundles.
  case animaChristi
}

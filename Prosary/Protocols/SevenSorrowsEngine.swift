//
//  SevenSorrowsEngine.swift
//  Prosary
//
//  What the UI needs from the backend to build the Seven Sorrows (Servite Rosary/Chaplet of Our
//  Lady of Sorrows). Like the Franciscan Crown, it isn't user-configurable — there's no config to
//  pass, just a language — it's always the same fixed sequence: the Seven Sorrows of Mary, each a
//  decade of an Our Father and 7 Hail Marys, closing with 3 additional Hail Marys (for Our Lady's
//  tears) and a fixed versicle/response/collect (not the Rosary's Marian-antiphon picker).
//  Implement `StubSevenSorrowsEngine` (see Support/Stubs/StubSevenSorrowsEngine.swift) with your
//  real rules.
//

import Foundation

protocol SevenSorrowsEngine {
  /// Builds the full, ordered sequence of prayer steps for a Seven Sorrows session in the given
  /// language.
  func buildSteps(languageCode: String?) -> [RosaryStep]
}

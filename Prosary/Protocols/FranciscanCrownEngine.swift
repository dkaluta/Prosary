//
//  FranciscanCrownEngine.swift
//  Prosary
//
//  What the UI needs from the backend to build the Franciscan Crown. Like the Angelus/Stations,
//  the Franciscan Crown isn't user-configurable — there's no config to pass, just a language —
//  it's always the same fixed sequence: the Seven Joys of Mary, each a decade of an Our Father
//  and 10 Hail Marys, closing with 2 additional Hail Marys and an Our Father. Implement
//  `StubFranciscanCrownEngine` (see Support/Stubs/StubFranciscanCrownEngine.swift) with your real
//  rules.
//

import Foundation

protocol FranciscanCrownEngine {
  /// Builds the full, ordered sequence of prayer steps for a Franciscan Crown session in the
  /// given language.
  func buildSteps(languageCode: String?) -> [RosaryStep]
}

//
//  StationsEngine.swift
//  Prosary
//
//  What the UI needs from the backend to build the Stations of the Cross. Like the Angelus,
//  the Stations aren't user-configurable — there's no config to pass, just a language — so this
//  is the prayer-flow business logic boundary for a fixed devotion. Implement
//  `StubStationsEngine` (see Support/Stubs/StubStationsEngine.swift) with your real rules.
//

import Foundation

protocol StationsEngine {
  /// Builds the full, ordered sequence of prayer steps for a Stations of the Cross session in
  /// the given language — an opening prayer, each of the fourteen stations in order, and a
  /// closing prayer.
  func buildSteps(languageCode: String?) -> [RosaryStep]
}

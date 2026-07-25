//
//  RosaryEngine.swift
//  Prosary
//
//  Prayer-flow business logic boundary for the Rosary. Implement `StubRosaryEngine`
//  (see Support/Stubs/StubRosaryEngine.swift) with your real rules.
//

import Foundation

protocol RosaryEngine {
  /// Builds the full, ordered sequence of prayer steps for a Rosary session.
  func buildSteps(for prayer: Prayer) -> [RosaryStep]
}

//
//  RosaryEngine.swift
//  Prosary
//
//  What the UI needs from the backend to turn a saved preset into an actual, ordered prayer
//  session. This is the prayer-flow business logic boundary — implement `StubRosaryEngine`
//  (see Support/Stubs/StubRosaryEngine.swift) with your real rules.
//

import Foundation

protocol RosaryEngine {
    /// Builds the full, ordered sequence of prayer steps for a Rosary session from a config.
    func buildSteps(for config: RosaryConfig) -> [RosaryStep]
}

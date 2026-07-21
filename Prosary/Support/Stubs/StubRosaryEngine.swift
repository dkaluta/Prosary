//
//  StubRosaryEngine.swift
//  Prosary
//
//  Skeleton for the real RosaryEngine implementation — fill in `buildSteps(for:)` with your
//  actual prayer-flow rules (mirroring whatever order/config toggles your RosaryConfig defines).
//  Not wired into the app by default; see MockRosaryEngine for the fully-working version used
//  to drive Previews and interactive testing today.
//

import Foundation

struct StubRosaryEngine: RosaryEngine {
    func buildSteps(for config: RosaryConfig) -> [RosaryStep] {
        fatalError("StubRosaryEngine.buildSteps(for:) not implemented")
    }
}

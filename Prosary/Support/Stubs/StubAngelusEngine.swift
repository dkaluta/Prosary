//
//  StubAngelusEngine.swift
//  Prosary
//
//  Skeleton for the real AngelusEngine implementation — fill in `buildSteps(languageCode:)` with
//  your actual prayer-flow rules. Not wired into the app by default; see MockAngelusEngine for the
//  fully-working version used to drive Previews and interactive testing today.
//

import Foundation

struct StubAngelusEngine: AngelusEngine {
    func buildSteps(languageCode: String?) -> [RosaryStep] {
        fatalError("StubAngelusEngine.buildSteps(languageCode:) not implemented")
    }
}

//
//  AngelusEngine.swift
//  Prosary
//
//  What the UI needs from the backend to build the Angelus. Unlike the Rosary, the Angelus isn't
//  user-configurable — there's no config to pass, just a language — so this is the prayer-flow
//  business logic boundary for a fixed devotion. Implement `StubAngelusEngine` (see
//  Support/Stubs/StubAngelusEngine.swift) with your real rules.
//

import Foundation

protocol AngelusEngine {
    /// Builds the full, ordered sequence of prayer steps for an Angelus session in the given
    /// language — the standard three-versicle form, or the Regina Caeli substitute during
    /// Eastertide.
    func buildSteps(languageCode: String?) -> [RosaryStep]
}

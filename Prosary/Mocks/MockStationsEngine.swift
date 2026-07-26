//
//  MockStationsEngine.swift
//  Prosary
//
//  Thin wrapper over StubStationsEngine for Previews and unit tests.
//

import Foundation

struct MockStationsEngine: StationsEngine {
  private let inner = StubStationsEngine()

  func buildSteps(languageCode: String?) -> [RosaryStep] {
    inner.buildSteps(languageCode: languageCode)
  }
}

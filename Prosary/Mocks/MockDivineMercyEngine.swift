//
//  MockDivineMercyEngine.swift
//  Prosary
//
//  Thin wrapper over StubDivineMercyEngine for Previews and unit tests.
//

import Foundation

struct MockDivineMercyEngine: DivineMercyEngine {
  private let inner = StubDivineMercyEngine()

  func buildSteps(languageCode: String?) -> [RosaryStep] {
    inner.buildSteps(languageCode: languageCode)
  }
}

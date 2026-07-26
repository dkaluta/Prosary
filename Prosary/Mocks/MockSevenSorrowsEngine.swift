//
//  MockSevenSorrowsEngine.swift
//  Prosary
//
//  Thin wrapper over StubSevenSorrowsEngine for Previews and unit tests.
//

import Foundation

struct MockSevenSorrowsEngine: SevenSorrowsEngine {
  private let inner = StubSevenSorrowsEngine()

  func buildSteps(languageCode: String?) -> [RosaryStep] {
    inner.buildSteps(languageCode: languageCode)
  }
}

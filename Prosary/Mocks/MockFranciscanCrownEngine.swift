//
//  MockFranciscanCrownEngine.swift
//  Prosary
//
//  Thin wrapper over StubFranciscanCrownEngine for Previews and unit tests.
//

import Foundation

struct MockFranciscanCrownEngine: FranciscanCrownEngine {
  private let inner: StubFranciscanCrownEngine

  init(calendar: LiturgicalCalendarProviding = MockLiturgicalCalendar()) {
    inner = StubFranciscanCrownEngine(calendar: calendar)
  }

  func buildSteps(languageCode: String?) -> [RosaryStep] {
    inner.buildSteps(languageCode: languageCode)
  }
}

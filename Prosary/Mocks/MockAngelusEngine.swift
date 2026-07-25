
//
//  MockAngelusEngine.swift
//  Prosary
//
//  Thin wrapper over StubAngelusEngine for Previews and unit tests.
//

import Foundation

struct MockAngelusEngine: AngelusEngine {
  private let inner: StubAngelusEngine

  init(calendar: LiturgicalCalendarProviding = MockLiturgicalCalendar()) {
    inner = StubAngelusEngine(calendar: calendar)
  }

  func buildSteps(languageCode: String?) -> [RosaryStep] {
    inner.buildSteps(languageCode: languageCode)
  }
}

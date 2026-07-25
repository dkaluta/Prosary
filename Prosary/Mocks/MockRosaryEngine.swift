
//
//  MockRosaryEngine.swift
//  Prosary
//
//  Thin wrapper over StubRosaryEngine for Previews and unit tests. Accepts an optional
//  calendar override so tests can inject a fixed liturgical state.
//

import Foundation

struct MockRosaryEngine: RosaryEngine {
  private let inner: StubRosaryEngine

  init(calendar: LiturgicalCalendarProviding = MockLiturgicalCalendar()) {
    inner = StubRosaryEngine(calendar: calendar)
  }

  func buildSteps(for prayer: Prayer) -> [RosaryStep] {
    inner.buildSteps(for: prayer)
  }

  func resolveMysteryGroups(for prayer: Prayer) -> [MysteryGroup] {
    inner.resolveMysteryGroups(for: prayer)
  }
}

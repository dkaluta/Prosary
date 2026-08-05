
//
//  MockLiturgicalCalendar.swift
//  Prosary
//
//  Thin wrapper over StubLiturgicalCalendar for Previews and unit tests. Exposes the same
//  interface so call sites that hold a `MockLiturgicalCalendar` work unchanged.
//

import SwiftUI

struct MockLiturgicalCalendar: LiturgicalCalendarProviding {
  private let inner = StubLiturgicalCalendar()

  func mysteryGroup(for date: Date) -> MysteryGroup        { inner.mysteryGroup(for: date) }
  func seasonColor(for date: Date) -> Color                { inner.seasonColor(for: date) }
  func seasonalMarianAntiphon(for date: Date) -> MarianAntiphonOption { inner.seasonalMarianAntiphon(for: date) }
  func isEasterSeason(for date: Date) -> Bool              { inner.isEasterSeason(for: date) }
  func isLent(for date: Date) -> Bool                      { inner.isLent(for: date) }
}

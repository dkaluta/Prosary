
//
//  PrayerReminderTests.swift
//  ProsaryTests
//

import XCTest
@testable import Prosary

final class PrayerReminderTests: XCTestCase {

  // MARK: - Basic properties

  func testDefaultMinuteIsZero() {
    let r = PrayerReminder(hour: 9)
    XCTAssertEqual(r.hour, 9)
    XCTAssertEqual(r.minute, 0)
    XCTAssertTrue(r.isEnabled)
  }

  func testAsDateReflectsHourAndMinute() {
    let r = PrayerReminder(hour: 14, minute: 30)
    let comps = Calendar.current.dateComponents([.hour, .minute], from: r.asDate)
    XCTAssertEqual(comps.hour, 14)
    XCTAssertEqual(comps.minute, 30)
  }

  func testDisplayTimeIsNonEmpty() {
    let r = PrayerReminder(hour: 6, minute: 0)
    XCTAssertFalse(r.displayTime.isEmpty)
  }

  // MARK: - Codable round-trip

  func testCodableRoundTrip() throws {
    let original = PrayerReminder(hour: 18, minute: 45, isEnabled: false)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(PrayerReminder.self, from: data)

    XCTAssertEqual(decoded.id, original.id)
    XCTAssertEqual(decoded.hour, 18)
    XCTAssertEqual(decoded.minute, 45)
    XCTAssertFalse(decoded.isEnabled)
  }

  func testCodableRoundTripForArray() throws {
    let reminders = [
      PrayerReminder(hour: 6),
      PrayerReminder(hour: 12),
      PrayerReminder(hour: 18),
    ]
    let data = try JSONEncoder().encode(reminders)
    let decoded = try JSONDecoder().decode([PrayerReminder].self, from: data)
    XCTAssertEqual(decoded.map(\.hour), [6, 12, 18])
  }

  // MARK: - Prayer.reminders integration

  func testPrayerRemindersDefaultEmpty() {
    let prayer = Prayer(kind: .rosary)
    XCTAssertTrue(prayer.reminders.isEmpty)
  }

  func testPrayerCanHoldReminders() {
    var prayer = Prayer(kind: .custom, customDevotionId: "angelus")
    prayer.reminders = [PrayerReminder(hour: 6), PrayerReminder(hour: 12), PrayerReminder(hour: 18)]
    XCTAssertEqual(prayer.reminders.count, 3)
    XCTAssertEqual(prayer.reminders.map(\.hour), [6, 12, 18])
  }

  func testPrayerReminderCodableRoundTrip() throws {
    var original = Prayer(name: "Morning Angelus", kind: .custom, customDevotionId: "angelus")
    original.reminders = [PrayerReminder(hour: 6), PrayerReminder(hour: 12)]

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Prayer.self, from: data)

    XCTAssertEqual(decoded.reminders.count, 2)
    XCTAssertEqual(decoded.reminders[0].hour, 6)
    XCTAssertEqual(decoded.reminders[1].hour, 12)
  }
}

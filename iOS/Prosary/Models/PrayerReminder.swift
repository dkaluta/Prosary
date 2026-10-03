
//
//  PrayerReminder.swift
//  Prosary
//

import Foundation

struct PrayerReminder: Hashable, Codable, Identifiable {
  var id = UUID()
  var hour: Int     // 0–23
  var minute: Int   // 0–59
  var isEnabled: Bool = true

  init(hour: Int, minute: Int = 0, isEnabled: Bool = true) {
    self.hour = hour
    self.minute = minute
    self.isEnabled = isEnabled
  }

  var displayTime: String {
    let comps = DateComponents(hour: hour, minute: minute)
    guard let date = Calendar.current.date(from: comps) else {
      return String(format: "%02d:%02d", hour, minute)
    }
    return date.formatted(date: .omitted, time: .shortened)
  }

  /// A `Date` whose time component matches this reminder, for use with `DatePicker`.
  var asDate: Date {
    Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
  }
}

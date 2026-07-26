
//
//  ReminderScheduler.swift
//  Prosary
//
//  Thin wrapper around UNUserNotificationCenter that schedules/removes daily repeating
//  local notifications for a Prayer's saved reminders.
//

import UserNotifications
import Foundation

struct ReminderScheduler {

  /// Requests notification permission if not yet determined. Returns true when the app
  /// is authorized (already was or just granted).
  @discardableResult
  static func requestPermission() async -> Bool {
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    switch settings.authorizationStatus {
    case .authorized, .provisional, .ephemeral:
      return true
    case .notDetermined:
      return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    default:
      return false
    }
  }

  /// Replaces all pending notifications for `prayer` with its current enabled reminders.
  static func schedule(for prayer: Prayer) {
    let center = UNUserNotificationCenter.current()
    let prefix = notificationPrefix(for: prayer)

    center.getPendingNotificationRequests { existing in
      // Remove everything that was previously scheduled for this prayer.
      let stale = existing.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
      center.removePendingNotificationRequests(withIdentifiers: stale)

      for reminder in prayer.reminders where reminder.isEnabled {
        let content = UNMutableNotificationContent()
        content.title = prayer.name
        content.body = notificationBody(for: prayer)
        content.sound = .default
        content.userInfo = ["prayerId": prayer.id.uuidString]

        var comps = DateComponents()
        comps.hour = reminder.hour
        comps.minute = reminder.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(
          identifier: "\(prefix)\(reminder.id)",
          content: content,
          trigger: trigger
        )
        center.add(request)
      }
    }
  }

  /// Removes all pending notifications for `prayer`.
  static func removeAll(for prayer: Prayer) {
    let center = UNUserNotificationCenter.current()
    let prefix = notificationPrefix(for: prayer)
    center.getPendingNotificationRequests { existing in
      let ids = existing.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
      center.removePendingNotificationRequests(withIdentifiers: ids)
    }
  }

  private static func notificationPrefix(for prayer: Prayer) -> String {
    "prosary-\(prayer.id)-"
  }

  private static func notificationBody(for prayer: Prayer) -> String {
    switch prayer.kind {
    case .rosary:             return "Time to pray the Rosary."
    case .angelus:            return "The Angelus bell is ringing."
    case .jesusPrayer:        return "Time for the Jesus Prayer."
    case .stationsOfTheCross: return "Time to pray the Stations of the Cross."
    case .franciscanCrown:    return "Time to pray the Franciscan Crown."
    case .sevenSorrows:       return "Time to pray the Seven Sorrows."
    case .divineMercyChaplet: return "Time to pray the Divine Mercy Chaplet."
    }
  }
}

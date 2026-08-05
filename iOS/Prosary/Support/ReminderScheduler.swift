
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

  // MARK: - Multi-day series

  /// A series in progress earns one notification per remaining day — the spec's "a notification
  /// per day prompting you to continue" — rather than a daily repeat that would keep nagging
  /// after the last day. Rewritten from scratch on every call, so recording a day, starting
  /// over, or finishing the run all leave exactly the right ones pending.
  static func refreshSeries(devotionId: String) {
    let center = UNUserNotificationCenter.current()
    let prefix = seriesPrefix(devotionId)

    center.getPendingNotificationRequests { existing in
      let stale = existing.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
      center.removePendingNotificationRequests(withIdentifiers: stale)
    }

    Task { @MainActor in
      guard let definition = PrayerPackStore.definition(for: devotionId),
            let days = definition.days, days.count > 1,
            (definition.dayProgression ?? .series) == .series,
            let run = MultiDayRuns.run(for: devotionId),
            !run.isComplete(dayCount: days.count) else { return }

      let time = reminderTime(definition.suggestedReminderTime)
      let name = PrayerPackStore.info(for: devotionId)?.localizedDisplayName ?? devotionId
      let pending = Self.pendingSeriesDays(run: run, dayCount: days.count, time: time)
      guard !pending.isEmpty, await requestPermission() else { return }

      for (day, date) in pending {
        let content = UNMutableNotificationContent()
        content.title = name
        content.body = String(
          localized: "multiDay.reminderBody",
          defaultValue: "Day \(day + 1) of \(days.count) awaits.")
        content.sound = .default
        content.userInfo = ["devotionId": devotionId, "dayIndex": day]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let request = UNNotificationRequest(
          identifier: "\(prefix)\(day)",
          content: content,
          trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        try? await center.add(request)
      }
    }
  }

  static func removeSeries(devotionId: String) {
    let center = UNUserNotificationCenter.current()
    let prefix = seriesPrefix(devotionId)
    center.getPendingNotificationRequests { existing in
      let ids = existing.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
      center.removePendingNotificationRequests(withIdentifiers: ids)
    }
  }

  /// Which days still deserve a notification and when: each unprayed day on the calendar date
  /// the run puts it on, skipping anything already past. Pure, so the dates are testable
  /// without a notification centre.
  static func pendingSeriesDays(
    run: MultiDayRun,
    dayCount: Int,
    time: (hour: Int, minute: Int),
    now: Date = Date()
  ) -> [(day: Int, date: Date)] {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: run.startedOn)
    return (0..<dayCount).compactMap { day in
      guard !run.prayedDays.contains(day),
            let midnight = calendar.date(byAdding: .day, value: day, to: start),
            let fire = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: midnight),
            fire > now else { return nil }
      return (day, fire)
    }
  }

  /// The bundle's suggested "HH:mm", or early evening — when the day's prayer is traditionally
  /// said and, failing that, when someone is most likely free to say it.
  static func reminderTime(_ suggested: String?) -> (hour: Int, minute: Int) {
    let parts = suggested?.split(separator: ":").compactMap { Int($0) } ?? []
    guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else {
      return (hour: 18, minute: 0)
    }
    return (hour: parts[0], minute: parts[1])
  }

  private static func seriesPrefix(_ devotionId: String) -> String {
    "prosary-series-\(devotionId)-"
  }

  private static func notificationPrefix(for prayer: Prayer) -> String {
    "prosary-\(prayer.id)-"
  }

  private static func notificationBody(for prayer: Prayer) -> String {
    switch prayer.kind {
    case .rosary:      return "Time to pray the Rosary."
    case .jesusPrayer: return "Time for the Jesus Prayer."
    case .custom:
      // Each bundle devotion ships its own notification body in its manifest (e.g. the
      // Angelus's "The Angelus bell is ringing.").
      guard let devotionId = prayer.customDevotionId,
            let body = PrayerPackStore.info(for: devotionId)?.localizedReminderBody else {
        return "Time to pray."
      }
      return body
    }
  }
}

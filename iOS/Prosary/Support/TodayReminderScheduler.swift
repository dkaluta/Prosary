import Foundation
import Combine
import SwiftUI
import UserNotifications

/// Date-specific content needs one notification per civil day. Refresh the two-week window
/// on launch, foreground, settings edits and time-zone changes; prayer times remain recurring.
enum TodayReminderScheduler {
  static let readingsEnabledKey = "readingsReminderEnabled"
  static let readingsTimeKey = "readingsReminderMinutes"
  static let saintsEnabledKey = "saintReminderEnabled"
  static let saintsTimeKey = "saintReminderMinutes"
  private static let prefix = "prosary-today-"
  @MainActor private static var generation = 0

  @MainActor
  static func refresh(now: Date = Date()) async {
    guard !ProsaryRuntimeEnvironment.isTesting else { return }
    generation += 1
    let currentGeneration = generation
    let center = UNUserNotificationCenter.current()
    let pending = await center.pendingNotificationRequests()
    guard currentGeneration == generation else { return }
    center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier))
    let defaults = UserDefaults.standard
    let readings = defaults.bool(forKey: readingsEnabledKey)
    let saints = defaults.bool(forKey: saintsEnabledKey)
    guard readings || saints else { return }
    let settings = await center.notificationSettings()
    guard currentGeneration == generation else { return }
    var allowedStatuses: [UNAuthorizationStatus] = [.authorized, .provisional]
    #if !os(macOS)
    allowedStatuses.append(.ephemeral)
    #endif
    guard allowedStatuses.contains(settings.authorizationStatus) else { return }
    let calendar = Calendar.autoupdatingCurrent
    let language = UILanguage.current
    var remaining = max(0, 64 - pending.filter { !$0.identifier.hasPrefix(prefix) }.count)
    for offset in 0..<14 {
      guard currentGeneration == generation, remaining > 0 else { return }
      guard let date = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
      if readings {
        let citations = TodayInfoStore.readings(on: date)
        if !citations.isEmpty {
          if await add(kind: "readings", title: String(localized: "home.today.readings", defaultValue: "Today's readings", bundle: UILanguage.bundle, locale: UILanguage.locale),
                    body: citations.map { $0.localizedFull(language) }.joined(separator: "; "),
                    date: date, minutes: minutes(for: readingsTimeKey), now: now, url: "prosary://readings") { remaining -= 1 }
        }
      }
      if saints, remaining > 0, let feast = TodayInfoStore.feast(on: date) {
        if await add(kind: "saints", title: feast.localizedTitle(language),
                  body: saintBody(feast: feast, calendarID: TodayInfoStore.selectedCalendarId, language: language),
                  date: date, minutes: minutes(for: saintsTimeKey), now: now, url: "prosary://today") { remaining -= 1 }
      }
    }
  }

  static func minutes(for key: String) -> Int {
    let defaults = UserDefaults.standard
    return min(1439, max(0, defaults.object(forKey: key) as? Int ?? 9 * 60))
  }

  static func saintBody(feast: FeastDay, calendarID: String, language: String) -> String {
    let descriptions = feast.saintDescriptions(calendarID: calendarID, language: language)
    guard !descriptions.isEmpty else {
      return "\(feast.localizedTitle(language)) · \(feast.localizedRank(language))"
    }
    return descriptions.map { description in
      [description.title, description.text, description.credit].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
    }.joined(separator: "\n\n")
  }

  static func deliveryDate(on date: Date, minutes: Int, after now: Date, calendar: Calendar = .autoupdatingCurrent) -> Date? {
    guard let fire = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: date), fire > now else { return nil }
    return fire
  }

  private static func add(kind: String, title: String, body: String, date: Date, minutes: Int, now: Date, url: String) async -> Bool {
    let calendar = Calendar.autoupdatingCurrent
    guard let fire = deliveryDate(on: date, minutes: minutes, after: now, calendar: calendar) else { return false }
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.userInfo = ["url": url]
    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
    let identifier = "\(prefix)\(kind)-\(components.year!)-\(components.month!)-\(components.day!)"
    do {
      try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content,
        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
      return true
    } catch { return false }
  }
}

struct ReminderLifecycle: ViewModifier {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.appServices) private var services
  @State private var preferencesSignature: [String] = []

  func body(content: Content) -> some View {
    content.task { await refresh() }
      .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await refresh() } } }
      .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in Task { await refresh() } }
      .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in Task { await refresh() } }
      .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).receive(on: RunLoop.main)) { _ in
        let defaults = UserDefaults.standard
        let signature = [TodayInfoStore.selectedCalendarId, defaults.string(forKey: TodayInfoStore.paschaStyleDefaultsKey) ?? "julian", UILanguage.current,
          String(defaults.bool(forKey: TodayReminderScheduler.readingsEnabledKey)), String(TodayReminderScheduler.minutes(for: TodayReminderScheduler.readingsTimeKey)),
          String(defaults.bool(forKey: TodayReminderScheduler.saintsEnabledKey)), String(TodayReminderScheduler.minutes(for: TodayReminderScheduler.saintsTimeKey))]
        if signature != preferencesSignature {
          preferencesSignature = signature
          Task { await TodayReminderScheduler.refresh() }
        }
      }
  }

  @MainActor private func refresh() async {
    guard !ProsaryRuntimeEnvironment.isTesting else { return }
    if let prayers = try? await services.presetStore.all() {
      for prayer in prayers { ReminderScheduler.schedule(for: prayer) }
    }
    await TodayReminderScheduler.refresh()
  }
}

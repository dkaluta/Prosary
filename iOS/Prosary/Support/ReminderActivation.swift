import Foundation
import Observation
import UserNotifications

/// Notification taps use the same strict, read-only destinations as widgets and Shortcuts.
@MainActor
@Observable
final class ReminderActivation: NSObject, UNUserNotificationCenterDelegate {
  static let shared = ReminderActivation()
  var pendingURL: URL?

  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse) async {
    guard let raw = response.notification.request.content.userInfo["url"] as? String,
          let url = URL(string: raw) else { return }
    await MainActor.run {
      guard ProsaryWidgetLink(url: url) != nil else { return }
      self.pendingURL = url
    }
  }

  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }
}

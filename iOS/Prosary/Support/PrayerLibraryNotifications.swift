import Foundation

extension Notification.Name {
  static let prayerConfigurationDidChange = Notification.Name("Prosary.prayerConfigurationDidChange")
  static let prayerConfigurationDidDelete = Notification.Name("Prosary.prayerConfigurationDidDelete")
  /// Presets and installed devotions are shared; navigation and prayer positions are not.
  static let prayerLibraryDidChange = Notification.Name("Prosary.prayerLibraryDidChange")
}

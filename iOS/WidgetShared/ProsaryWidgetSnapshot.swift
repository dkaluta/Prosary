import Foundation

/// Versioned, intentionally small handoff; widgets never open the app's SwiftData store.
nonisolated struct ProsaryWidgetSnapshot: Codable, Equatable, Sendable {
  static let appGroupIdentifier = "group.com.dkaluta.prosary"
  static let storageKey = "prosaryWidgetSnapshot.v1"
  static let todayKind = "ProsaryTodayWidget"
  static let prayerKind = "ProsarySavedPrayerWidget"

  var today: WidgetTodaySettings = .init()
  var prayers: [WidgetSavedPrayer] = []
  var updatedAt: Date = Date()

  static func load(defaults: UserDefaults? = UserDefaults(suiteName: appGroupIdentifier)) -> Self {
    guard let data = defaults?.data(forKey: storageKey),
          let snapshot = try? JSONDecoder().decode(Self.self, from: data) else { return .init() }
    return snapshot
  }

  @discardableResult
  func save(to defaults: UserDefaults? = UserDefaults(suiteName: Self.appGroupIdentifier)) -> Bool {
    guard let defaults, let data = try? JSONEncoder().encode(self) else { return false }
    defaults.set(data, forKey: Self.storageKey)
    return true
  }

  static func localDateKey(_ date: Date, timeZone: TimeZone = .current) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
}

nonisolated struct WidgetTodaySettings: Codable, Equatable, Sendable {
  var calendarID = "lpj"
  var easternPaschaStyle = "julian"
  var languageCode = Locale.preferredLanguages.first ?? "en"
  var showFeast = true
  var showIntention = true
  var showTorah = false

  var normalizedLanguageCode: String {
    let base = languageCode.lowercased().replacingOccurrences(of: "_", with: "-").split(separator: "-").first.map(String.init) ?? "en"
    let code = base == "fil" ? "tl" : base == "iw" ? "he" : base
    return ["en", "he", "ar", "ru", "tl", "fr", "it", "uk"].contains(code) ? code : "en"
  }

  var isRightToLeft: Bool { ["he", "ar"].contains(normalizedLanguageCode) }
}

nonisolated struct WidgetSavedPrayer: Codable, Equatable, Identifiable, Sendable {
  var id: UUID
  var name: String
  var kind: String
  /// Zero-based current step or current repetition for the Jesus Prayer.
  var stepIndex: Int? = nil
  var stepCount: Int? = nil
  /// Rosary bookmarks retain their original civil-day key, including across time-zone changes.
  var progressLocalDate: String? = nil
  var progressExpiresAtMidnight = false

  var url: URL { URL(string: "prosary://prayer/\(id.uuidString)")! }

  func hasProgress(on date: Date) -> Bool {
    guard let stepIndex, stepIndex > 0 else { return false }
    if let stepCount, stepCount <= 0 || stepIndex >= stepCount { return false }
    if progressExpiresAtMidnight || kind.lowercased() == "rosary" {
      return progressLocalDate == ProsaryWidgetSnapshot.localDateKey(date)
    }
    return true
  }

  func fractionCompleted(on date: Date) -> Double? {
    guard hasProgress(on: date), let stepIndex, let stepCount, stepCount > 0 else { return nil }
    return min(1, max(0, Double(stepIndex + 1) / Double(stepCount)))
  }
}

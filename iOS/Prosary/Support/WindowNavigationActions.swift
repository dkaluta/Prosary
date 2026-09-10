import SwiftUI

enum AppSection: String, CaseIterable, Hashable {
  case pray, browse, readings, search

  var title: String {
    switch self {
    case .pray: String(localized: "tabs.pray", defaultValue: "Pray")
    case .browse: String(localized: "tabs.browse", defaultValue: "Browse")
    case .readings: String(localized: "tabs.readings", defaultValue: "Readings")
    case .search: String(localized: "tabs.search", defaultValue: "Search")
    }
  }

  var systemImage: String {
    switch self {
    case .pray: "hands.and.sparkles"
    case .browse: "globe"
    case .readings: "book"
    case .search: "magnifyingglass"
    }
  }
}

/// Menus follow the focused scene; in-view handoffs use the same window's environment.
struct WindowNavigationActions {
  let selectedSection: AppSection
  let canGoBack: Bool
  let currentRoute: AppRoute?
  let selectSection: (AppSection) -> Void
  let goBack: () -> Void
  let openRoute: (AppRoute) -> Void
  let importBundle: () -> Void
}

private struct WindowNavigationFocusKey: FocusedValueKey {
  typealias Value = WindowNavigationActions
}

extension FocusedValues {
  var windowNavigation: WindowNavigationActions? {
    get { self[WindowNavigationFocusKey.self] }
    set { self[WindowNavigationFocusKey.self] = newValue }
  }
}

private struct WindowNavigationEnvironmentKey: EnvironmentKey {
  static let defaultValue: WindowNavigationActions? = nil
}

extension EnvironmentValues {
  var prayerWindowIsModal: Bool {
    get { self[PrayerWindowIsModalKey.self] }
    set { self[PrayerWindowIsModalKey.self] = newValue }
  }
  /// Dedicated prayer windows close on completion; navigation-based sessions keep their
  /// platform's usual dismissal behavior when no action is supplied.
  var finishPrayerSession: (() -> Void)? {
    get { self[FinishPrayerSessionKey.self] }
    set { self[FinishPrayerSessionKey.self] = newValue }
  }

  var prayerWindowTitle: String? {
    get { self[PrayerWindowTitleKey.self] }
    set { self[PrayerWindowTitleKey.self] = newValue }
  }

  /// A saved Mac prayer copy provides its own pace; other sessions use the app setting.
  var prayerAutoAdvanceSeconds: Binding<Int>? {
    get { self[PrayerAutoAdvanceSecondsKey.self] }
    set { self[PrayerAutoAdvanceSecondsKey.self] = newValue }
  }

  var prayerProgressNamespace: String? {
    get { self[PrayerProgressNamespaceKey.self] }
    set { self[PrayerProgressNamespaceKey.self] = newValue }
  }

  var windowNavigation: WindowNavigationActions? {
    get { self[WindowNavigationEnvironmentKey.self] }
    set { self[WindowNavigationEnvironmentKey.self] = newValue }
  }
}

private struct PrayerWindowIsModalKey: EnvironmentKey {
  static let defaultValue = false
}

private struct PrayerProgressNamespaceKey: EnvironmentKey {
  static let defaultValue: String? = nil
}

private struct FinishPrayerSessionKey: EnvironmentKey {
  static let defaultValue: (() -> Void)? = nil
}

private struct PrayerWindowTitleKey: EnvironmentKey {
  static let defaultValue: String? = nil
}

private struct PrayerAutoAdvanceSecondsKey: EnvironmentKey {
  static let defaultValue: Binding<Int>? = nil
}

/// A Mac library copy owns its progress even when its bundle and settings match another
/// copy. The unscoped identity remains available for mobile and unsaved sessions.
enum PrayerCopyProgressIdentity {
  static func devotionID(_ devotionID: String, prayerID: UUID?) -> String {
    guard let prayerID else { return devotionID }
    return "mac:\(prayerID.uuidString):\(devotionID)"
  }

  /// The saved copy's settings are authoritative after an editor save. The old sequence
  /// signature remains intact so a language-owned variant still invalidates its bookmark.
  static func continuation(_ progress: PrayerRunProgress?, savedLanguageCode: String?) -> PrayerRunProgress? {
    guard let progress, let savedLanguageCode else { return progress }
    return PrayerRunProgress(
      configurationSignature: progress.configurationSignature,
      stepIndex: progress.stepIndex,
      languageCode: savedLanguageCode,
      savedLocalDate: progress.savedLocalDate)
  }
}

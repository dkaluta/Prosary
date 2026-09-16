import Combine
import Foundation
import Observation
import SwiftUI

/// The interface also supplies automatic Bible editions and prayer language when no prayer
/// override is selected. Content choices never become interface-language preferences.
enum UILanguage {
  nonisolated static let defaultsKey = "interfaceLanguageCode"
  nonisolated private static let supportedCodes: Set<String> = ["en", "he", "ar", "ru", "tl", "fr", "it", "uk"]
  static let all: [LanguageOption] = [
    LanguageOption(code: "en", nativeName: "English", isRightToLeft: false),
    LanguageOption(code: "he", nativeName: "עברית", isRightToLeft: true),
    LanguageOption(code: "ar", nativeName: "العربية", isRightToLeft: true),
    LanguageOption(code: "ru", nativeName: "Русский", isRightToLeft: false),
    LanguageOption(code: "tl", nativeName: "Tagalog", isRightToLeft: false),
    LanguageOption(code: "fr", nativeName: "Français", isRightToLeft: false),
    LanguageOption(code: "it", nativeName: "Italiano", isRightToLeft: false),
    LanguageOption(code: "uk", nativeName: "Українська", isRightToLeft: false),
  ]

  nonisolated static func normalized(_ identifier: String) -> String {
    let base = identifier.lowercased().replacingOccurrences(of: "_", with: "-")
      .split(separator: "-").first.map(String.init) ?? ""
    switch base {
    case "iw": return "he"
    case "fil": return "tl"
    default: return base
    }
  }

  nonisolated static func resolve(_ identifier: String) -> String {
    let code = normalized(identifier)
    return supportedCodes.contains(code) ? code : "en"
  }

  static var current: String {
    InterfaceLanguageStore.shared.code
  }

  nonisolated static var systemLanguage: String { resolve(Bundle.main.preferredLocalizations.first ?? "en") }
  static var locale: Locale { Locale(identifier: resourceLanguage(current)) }
  static var bundle: Bundle { resourceBundle(for: current) }

  nonisolated static func selection(_ identifier: String) -> String {
    let code = normalized(identifier)
    return supportedCodes.contains(code) ? code : ""
  }

  nonisolated static func resourceBundle(for language: String) -> Bundle {
    let code = resourceLanguage(language)
    if let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) {
      return bundle
    }
    return Bundle.main
  }

  /// LocalizedError can be read from any executor. Read Foundation's thread-safe preferences
  /// there, without synchronously entering the observable main-actor UI state.
  nonisolated static var persistedCode: String {
    let selected = selection(UserDefaults.standard.string(forKey: defaultsKey) ?? "")
    return selected.isEmpty ? systemLanguage : selected
  }
  nonisolated static var persistedBundle: Bundle { resourceBundle(for: persistedCode) }
  nonisolated static var persistedLocale: Locale { Locale(identifier: resourceLanguage(persistedCode)) }

  nonisolated static func isRightToLeft(_ identifier: String) -> Bool {
    ["ar", "he"].contains(normalized(identifier))
  }

  /// Use the selected resource bundle explicitly: Today can use a different language from
  /// the surrounding interface, including its captions, formatted numbers and accessibility.
  static func text(_ key: String, language: String, fallback: String) -> String {
    let code = resourceLanguage(language)
    guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
          let bundle = Bundle(path: path) else { return fallback }
    return bundle.localizedString(forKey: key, value: fallback, table: nil)
  }

  /// Xcode canonicalizes Tagalog catalog entries to `fil.lproj` when compiling resources.
  /// Shared data and preferences continue to use the stable cross-platform `tl` identifier.
  nonisolated static func resourceLanguage(_ identifier: String) -> String {
    let code = resolve(identifier)
    return code == "tl" ? "fil" : code
  }

  /// Tags remain stable identifiers for grouping and filtering; their displayed labels follow
  /// the interface. Unknown community tags retain the author's spelling.
  static func tag(_ identifier: String, language: String? = nil) -> String {
    text("category.\(identifier)", language: language ?? current, fallback: identifier.capitalized)
  }
}

extension Notification.Name {
  static let interfaceLanguageDidChange = Notification.Name("Prosary.interfaceLanguageDidChange")
}

/// Observation makes eager Foundation/AppKit strings update along with SwiftUI's localized
/// Text values. Preserve scene identity so a language change cannot discard an editor or run.
@MainActor @Observable
final class InterfaceLanguageStore {
  static let shared = InterfaceLanguageStore(defaults: .standard)

  private(set) var code: String
  private var storedSelection: String
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let systemLanguage: () -> String
  @ObservationIgnored private let notificationCenter: NotificationCenter
  @ObservationIgnored private var notifications: AnyCancellable?

  var selection: String {
    get { storedSelection }
    set {
      let selected = UILanguage.selection(newValue)
      defaults.set(selected, forKey: UILanguage.defaultsKey)
      apply(selected)
    }
  }

  init(defaults: UserDefaults, notificationCenter: NotificationCenter = .default,
       systemLanguage: @escaping () -> String = { UILanguage.systemLanguage }) {
    self.defaults = defaults
    self.systemLanguage = systemLanguage
    self.notificationCenter = notificationCenter
    let selected = UILanguage.selection(defaults.string(forKey: UILanguage.defaultsKey) ?? "")
    storedSelection = selected
    code = selected.isEmpty ? UILanguage.resolve(systemLanguage()) : selected
    notifications = Publishers.Merge(
      notificationCenter.publisher(for: UserDefaults.didChangeNotification),
      notificationCenter.publisher(for: NSLocale.currentLocaleDidChangeNotification))
      // Native Mac menus run a tracking loop. Apply external changes after that menu closes.
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in self?.refresh() }
  }

  func refresh() {
    apply(UILanguage.selection(defaults.string(forKey: UILanguage.defaultsKey) ?? ""))
  }

  private func apply(_ selected: String) {
    let nextCode = selected.isEmpty ? UILanguage.resolve(systemLanguage()) : selected
    guard storedSelection != selected || code != nextCode else { return }
    storedSelection = selected
    code = nextCode
    notificationCenter.post(name: .interfaceLanguageDidChange, object: self)
  }
}

extension Scene {
  func appInterfaceLanguage() -> some Scene {
    environment(\.locale, UILanguage.locale)
      .environment(\.layoutDirection, UILanguage.isRightToLeft(UILanguage.current) ? .rightToLeft : .leftToRight)
  }
}

/// Existing windows need a view-level observation boundary: scene environment values can
/// retain their launch value even after eager strings inside a presented sheet have updated.
private struct AppInterfaceLanguageModifier: ViewModifier {
  @State private var language = InterfaceLanguageStore.shared

  func body(content: Content) -> some View {
    let code = language.code
    content
      .environment(\.locale, Locale(identifier: UILanguage.resourceLanguage(code)))
      .environment(\.layoutDirection, UILanguage.isRightToLeft(code) ? .rightToLeft : .leftToRight)
  }
}

extension View {
  func appInterfaceLanguage() -> some View { modifier(AppInterfaceLanguageModifier()) }
}

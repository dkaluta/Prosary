import Foundation

/// Interface and Today languages are independent of the language chosen for prayer texts.
enum UILanguage {
  static let all: [LanguageOption] = [
    LanguageOption(code: "en", nativeName: "English", isRightToLeft: false),
    LanguageOption(code: "he", nativeName: "עברית", isRightToLeft: true),
    LanguageOption(code: "ar", nativeName: "العربية", isRightToLeft: true),
    LanguageOption(code: "ru", nativeName: "Русский", isRightToLeft: false),
    LanguageOption(code: "tl", nativeName: "Tagalog", isRightToLeft: false),
    LanguageOption(code: "fr", nativeName: "Français", isRightToLeft: false),
    LanguageOption(code: "it", nativeName: "Italiano", isRightToLeft: false),
  ]

  static func normalized(_ identifier: String) -> String {
    let base = identifier.lowercased().replacingOccurrences(of: "_", with: "-")
      .split(separator: "-").first.map(String.init) ?? ""
    switch base {
    case "iw": return "he"
    case "fil": return "tl"
    default: return base
    }
  }

  static func resolve(_ identifier: String) -> String {
    let code = normalized(identifier)
    return all.contains { $0.code == code } ? code : "en"
  }

  static var current: String {
    resolve(Bundle.main.preferredLocalizations.first ?? "en")
  }

  static func isRightToLeft(_ identifier: String) -> Bool {
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
  static func resourceLanguage(_ identifier: String) -> String {
    let code = resolve(identifier)
    return code == "tl" ? "fil" : code
  }

  /// Tags remain stable identifiers for grouping and filtering; their displayed labels follow
  /// the interface. Unknown community tags retain the author's spelling.
  static func tag(_ identifier: String, language: String = current) -> String {
    text("category.\(identifier)", language: language, fallback: identifier.capitalized)
  }
}

enum TodayTranslationLanguage {
  static let defaultsKey = "todayLanguageCode"
  /// The empty preference follows the app UI, never the independent prayer preference.
  static func resolve(_ stored: String, appLanguage: String = UILanguage.current) -> String {
    stored.isEmpty ? UILanguage.resolve(appLanguage) : UILanguage.resolve(stored)
  }
}

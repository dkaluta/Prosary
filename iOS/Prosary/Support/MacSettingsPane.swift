#if os(macOS)
import SwiftUI

enum MacSettingsPane: String {
  static let defaultsKey = "macSettingsPane"
  case language, praying, typography, today, downloads

  var title: String {
    switch self {
    case .language: String(localized: "settings.prayerLanguageHeader", defaultValue: "Language", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .praying: String(localized: "settings.prayingHeader", defaultValue: "Praying", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .typography: String(localized: "settings.appearanceHeader", defaultValue: "Appearance", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .today: String(localized: "settings.todayHeader", defaultValue: "Today", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .downloads: String(localized: "settings.downloadsHeader", defaultValue: "Downloads", bundle: UILanguage.bundle, locale: UILanguage.locale)
    }
  }
}
#endif

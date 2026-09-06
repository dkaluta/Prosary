import SwiftUI

/// The stored code still selects an exact sourced text. These controls present its language
/// and Hebrew prayer tradition separately without rewriting existing presets or bookmarks.
struct PrayerLanguagePicker: View {
  let label: String
  @Binding var code: String
  var defaultLabel: String? = nil

  private var language: Binding<String> {
    Binding(get: { LanguageCatalog.pickerLanguageCode(code) },
            set: { code = LanguageCatalog.selectingLanguage($0, current: code) })
  }

  var body: some View {
    Picker(label, selection: language) {
      if let defaultLabel { Text(defaultLabel).tag(LanguageCatalog.defaultSentinel) }
      ForEach(LanguageCatalog.languages) { option in
        Text(option.nativeName).tag(option.code)
      }
    }
    .accessibilityIdentifier("prayerLanguagePicker")
    if LanguageCatalog.pickerLanguageCode(code) == "he" {
      Picker(String(localized: "prayerLanguage.tradition", defaultValue: "Prayer tradition"), selection: $code) {
        Text(LanguageCatalog.traditionName("he")).tag("he")
        Text(LanguageCatalog.traditionName("he-x-gamliel")).tag("he-x-gamliel")
      }
      .accessibilityIdentifier("prayerTraditionPicker")
    }
  }
}

struct PrayerLanguageMenuContent: View {
  @ObservedObject private var prayerLanguage = PrayerLanguageMonitor.shared
  let code: String
  var options = LanguageCatalog.languages
  var identifierPrefix = "prayerLanguage"
  let onSelect: (String) -> Void

  var body: some View {
    let _ = prayerLanguage.code
    option(code: LanguageCatalog.defaultSentinel,
           name: String(localized: "prayerFlow.language.appDefault", defaultValue: "App setting"))
    Divider()
    ForEach(options) { language in
      option(code: language.code, name: language.nativeName)
    }
    if LanguageCatalog.pickerLanguageCode(LanguageCatalog.resolve(code).code) == "he" {
      Divider()
      Menu(String(localized: "prayerLanguage.tradition", defaultValue: "Prayer tradition")) {
        ForEach(["he", "he-x-gamliel"], id: \.self) { tradition in
          Button { onSelect(tradition) } label: {
            if LanguageCatalog.resolve(code).code == tradition {
              Label(LanguageCatalog.traditionName(tradition), systemImage: "checkmark")
            } else {
              Text(LanguageCatalog.traditionName(tradition))
            }
          }
          .accessibilityIdentifier("prayerTradition-\(tradition)")
        }
      }
      .accessibilityIdentifier("prayerTraditionMenu")
    }
  }

  private func option(code selected: String, name: String) -> some View {
    Button { onSelect(LanguageCatalog.selectingLanguage(selected, current: code)) } label: {
      if LanguageCatalog.pickerLanguageCode(code) == selected {
        Label(name, systemImage: "checkmark")
      } else {
        Text(name)
      }
    }
    .accessibilityIdentifier("\(identifierPrefix)-\(selected.isEmpty ? "default" : selected)")
  }
}

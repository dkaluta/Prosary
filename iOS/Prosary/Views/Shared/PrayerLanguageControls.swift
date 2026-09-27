import SwiftUI

/// The stored code still selects an exact sourced text. These controls present its language
/// and Hebrew prayer tradition separately without rewriting existing presets or bookmarks.
struct PrayerLanguagePicker: View {
  let label: String
  @Binding var code: String
  var defaultLabel: String? = nil
  var hebrewTraditions = ["he", "he-x-gamliel"]

  private var language: Binding<String> {
    Binding(get: { LanguageCatalog.pickerLanguageCode(code) },
            set: {
              let chosen = LanguageCatalog.selectingLanguage($0, current: code)
              code = LanguageCatalog.pickerLanguageCode(chosen) == "he" && hebrewTraditions.count == 1
                ? hebrewTraditions[0] : chosen
            })
  }

  var body: some View {
    Picker(label, selection: language) {
      if let defaultLabel { Text(defaultLabel).tag(LanguageCatalog.defaultSentinel) }
      ForEach(LanguageCatalog.languages) { option in
        Text(option.nativeName).tag(option.code)
      }
    }
    .accessibilityIdentifier("prayerLanguagePicker")
    if LanguageCatalog.pickerLanguageCode(code) == "he", hebrewTraditions.count > 1 {
      Picker(String(localized: "prayerLanguage.tradition", defaultValue: "Prayer Tradition", bundle: UILanguage.bundle, locale: UILanguage.locale), selection: $code) {
        ForEach(hebrewTraditions, id: \.self) { tradition in
          Text(LanguageCatalog.traditionName(tradition)).tag(tradition)
        }
      }
      .accessibilityIdentifier("prayerTraditionPicker")
    }
  }
}

struct PrayerLanguageMenuContent: View {
  @ObservedObject private var prayerLanguage = PrayerLanguageMonitor.shared
  let code: String
  var resolvedCode: String? = nil
  var options = LanguageCatalog.languages
  var identifierPrefix = "prayerLanguage"
  var hebrewTraditions = ["he", "he-x-gamliel"]
  let onSelect: (String) -> Void

  var body: some View {
    let _ = prayerLanguage.code
    let effectiveCode = resolvedCode ?? LanguageCatalog.resolve(code).code
    let inheritedName = LanguageCatalog.resolve(effectiveCode).nativeName
    option(code: LanguageCatalog.defaultSentinel,
           name: code.isEmpty && resolvedCode != nil
             ? String(localized: "prayer.language.default", defaultValue: "Default (\(inheritedName))", bundle: UILanguage.bundle, locale: UILanguage.locale)
             : String(localized: "prayerFlow.language.appDefault", defaultValue: "App Setting", bundle: UILanguage.bundle, locale: UILanguage.locale))
    Divider()
    ForEach(options) { language in
      option(code: language.code, name: language.nativeName)
    }
    if LanguageCatalog.pickerLanguageCode(effectiveCode) == "he", hebrewTraditions.count > 1 {
      Divider()
      Menu(String(localized: "prayerLanguage.tradition", defaultValue: "Prayer Tradition", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
        ForEach(hebrewTraditions, id: \.self) { tradition in
          Button { onSelect(tradition) } label: {
            if effectiveCode == tradition {
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
    Button {
      let chosen = LanguageCatalog.selectingLanguage(selected, current: code)
      onSelect(LanguageCatalog.pickerLanguageCode(chosen) == "he" && hebrewTraditions.count == 1
        ? hebrewTraditions[0] : chosen)
    } label: {
      if LanguageCatalog.pickerLanguageCode(code) == selected {
        Label(name, systemImage: "checkmark")
      } else {
        Text(name)
      }
    }
    .accessibilityIdentifier("\(identifierPrefix)-\(selected.isEmpty ? "default" : selected)")
  }
}

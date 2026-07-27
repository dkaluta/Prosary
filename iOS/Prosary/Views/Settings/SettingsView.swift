//
//  SettingsView.swift
//  Prosary
//
//  Shown on macOS via the Settings scene (Cmd+,). On iOS the equivalent lives in the
//  system Settings app — see Settings.bundle/Root.plist.
//

import SwiftUI

struct SettingsView: View {
  @AppStorage("defaultLanguageCode") private var languageCode = LanguageCatalog.defaultCode

  var body: some View {
    Form {
      Section("settings.prayerLanguageHeader") {
        Picker("settings.defaultLanguage", selection: $languageCode) {
          ForEach(LanguageCatalog.all) { lang in
            Text(lang.nativeName).tag(lang.code)
          }
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 420)
  }
}

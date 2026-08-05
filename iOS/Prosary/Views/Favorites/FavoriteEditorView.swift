
//
//  FavoriteEditorView.swift
//  Prosary
//
//  Editor for any kind of saved prayer favorite. Replaces PresetEditorView.
//  Kind-specific options appear conditionally based on prayer.kind.
//

import SwiftUI

struct FavoriteEditorView: View {
  @State var prayer: Prayer
  let isNew: Bool

  @Environment(\.appServices) private var services
  @Environment(\.dismiss) private var dismiss
  @AppStorage("defaultLanguageCode") private var appDefaultCode = LanguageCatalog.defaultCode

  /// The picker rows edit one stored code between them: the language row binds to its base,
  /// the rite row to the full code ("he-x-gamliel").
  private var languageBinding: Binding<String> {
    Binding(
      get: {
        let code = prayer.languageCode
        return code == LanguageCatalog.defaultSentinel ? code : (LanguageCatalog.baseLanguage(of: code) ?? code)
      },
      set: { newBase in
        prayer.languageCode = newBase == LanguageCatalog.defaultSentinel
          ? newBase
          : (LanguageCatalog.rites(of: newBase).first?.code ?? newBase)
      })
  }

  var body: some View {
    Form {
      // MARK: Common fields
      Section {
        TextField("favoriteEditor.name", text: $prayer.name, prompt: Text("favoriteEditor.namePlaceholder"))
        Toggle(String(localized: "favoriteEditor.setAsDefault", defaultValue: "Set as default for \(prayer.kind.displayName)"), isOn: $prayer.isDefault)
      }

      Section {
        Picker("favoriteEditor.language", selection: languageBinding) {
          let defaultName = LanguageCatalog.resolve(appDefaultCode).nativeName
          Text(String(localized: "favoriteEditor.defaultLanguageOption", defaultValue: "Default — \(defaultName)")).tag(LanguageCatalog.defaultSentinel)
          ForEach(LanguageCatalog.all) { language in
            Text(language.nativeName).tag(language.code)
          }
        }

        // Only for a language prayed in more than one use; a rite that lacks a prayer reads it
        // in the language's own wording, so this is a preference, never a restriction.
        let rites = LanguageCatalog.rites(of: prayer.languageCode)
        if rites.count > 1 {
          Picker(String(localized: "settings.rite", defaultValue: "Rite"), selection: $prayer.languageCode) {
            ForEach(rites) { rite in
              Text(rite.nativeName).tag(rite.code)
            }
          }
        }
      } header: {
        Text("favoriteEditor.prayerLanguageHeader")
      } footer: {
        #if os(iOS)
        Text("favoriteEditor.languageFooter")
        #endif
      }

      // MARK: Rosary options
      if prayer.kind == .rosary {
        Section {
          NavigationLink {
            RosaryOptionsEditorView(rosary: $prayer.rosary)
          } label: {
            LabeledContent("favoriteEditor.rosaryOptions", value: prayer.rosary.mysterySelectionSummary)
          }
        }
      }

      // MARK: Jesus Prayer options
      if prayer.kind == .jesusPrayer {
        Section("favoriteEditor.target") {
          Picker("favoriteEditor.repetitions", selection: $prayer.jesusPrayer.target) {
            Text("jesusPrayerTarget.33").tag(JesusPrayerTarget.count(33))
            Text("jesusPrayerTarget.66").tag(JesusPrayerTarget.count(66))
            Text("jesusPrayerTarget.99").tag(JesusPrayerTarget.count(99))
            Text("jesusPrayerOptions.unbounded").tag(JesusPrayerTarget.unbounded)
          }
          .pickerStyle(.segmented)
        }
      }

      // MARK: Reminders
      RemindersSection(reminders: $prayer.reminders)
    }
    .formStyle(.grouped)
    .navigationTitle(isNew ? "favoriteEditor.newFavoriteTitle" : "favoriteEditor.editFavoriteTitle")
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("favoriteEditor.cancel") { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("favoriteEditor.save") { save() }
      }
    }
  }

  // MARK: - Save

  private func save() {
    var toSave = prayer
    if toSave.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      toSave.name = toSave.kind.defaultName
    }
    Task {
      if !toSave.reminders.filter(\.isEnabled).isEmpty {
        await ReminderScheduler.requestPermission()
      }
      try? await services.presetStore.save(toSave)
      ReminderScheduler.schedule(for: toSave)
      dismiss()
    }
  }
}

#Preview("New Rosary") {
  NavigationStack {
    FavoriteEditorView(prayer: Prayer(kind: .rosary), isNew: true)
  }
}

#Preview("New Jesus Prayer") {
  NavigationStack {
    FavoriteEditorView(
      prayer: Prayer(
        name: "Jesus Prayer",
        kind: .jesusPrayer,
        reminders: [PrayerReminder(hour: 6), PrayerReminder(hour: 12), PrayerReminder(hour: 18)]
      ),
      isNew: true
    )
  }
}

#Preview("Edit Rosary") {
  NavigationStack {
    FavoriteEditorView(
      prayer: Prayer(
        name: "Evening Rosary for the Departed",
        kind: .rosary,
        languageCode: "en",
        rosary: RosaryOptions(
          mysterySelectionMode: .specific,
          specificMysteryGroup: .sorrowful,
          includeOpeningPrayers: false,
          eternalRestForDeceased: .afterEachDecade,
          includeStMichaelPrayer: true
        ),
        reminders: [PrayerReminder(hour: 21, minute: 0)]
      ),
      isNew: false)
  }
}

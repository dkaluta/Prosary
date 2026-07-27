
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

  var body: some View {
    Form {
      // MARK: Common fields
      Section {
        TextField("favoriteEditor.name", text: $prayer.name, prompt: Text("favoriteEditor.namePlaceholder"))
        Toggle(String(localized: "favoriteEditor.setAsDefault", defaultValue: "Set as default for \(prayer.kind.displayName)"), isOn: $prayer.isDefault)
      }

      Section {
        Picker("favoriteEditor.language", selection: $prayer.languageCode) {
          let defaultName = LanguageCatalog.resolve(appDefaultCode).nativeName
          Text(String(localized: "favoriteEditor.defaultLanguageOption", defaultValue: "Default — \(defaultName)")).tag(LanguageCatalog.defaultSentinel)
          ForEach(LanguageCatalog.all) { language in
            Text(language.nativeName).tag(language.code)
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
        Section("favoriteEditor.whichMysteries") {
          Picker("favoriteEditor.mysteriesPicker", selection: $prayer.rosary.mysterySelectionMode) {
            ForEach(MysterySelectionMode.allCases) { mode in
              Text(mode.displayName).tag(mode)
            }
          }
          if prayer.rosary.mysterySelectionMode == .specific || prayer.rosary.mysterySelectionMode == .singleMystery {
            Picker("favoriteEditor.specificSet", selection: $prayer.rosary.specificMysteryGroup) {
              ForEach(MysteryGroup.allCases) { group in
                Text(group.displayName).tag(group)
              }
            }
          }
          if prayer.rosary.mysterySelectionMode == .singleMystery {
            Picker("favoriteEditor.specificMystery", selection: $prayer.rosary.specificMysteryOrder) {
              ForEach(MysteryCatalog.forGroup(prayer.rosary.specificMysteryGroup)) { mystery in
                Text(MysteryTranslations.get(languageCode: "en", imageKey: mystery.imageKey).title).tag(mystery.order)
              }
            }
          }
        }

        Section("favoriteEditor.openingDecadePrayers") {
          Toggle("favoriteEditor.apostlesCreed", isOn: $prayer.rosary.includeApostlesCreed)
          Toggle("favoriteEditor.openingPrayers", isOn: $prayer.rosary.includeOpeningPrayers)
          Toggle("favoriteEditor.fatimaPrayer", isOn: $prayer.rosary.includeFatimaPrayer)
          Picker("favoriteEditor.eternalRest", selection: $prayer.rosary.eternalRestForDeceased) {
            ForEach(EternalRestPlacement.allCases) { option in
              Text(option.displayName).tag(option)
            }
          }
        }

        Section {
          Toggle("favoriteEditor.presenterMode", isOn: $prayer.rosary.presenterMode)
        } header: {
          Text("favoriteEditor.presenterModeHeader")
        } footer: {
          Text("favoriteEditor.presenterModeFooter")
        }

        Section("favoriteEditor.closingPrayers") {
          Picker("favoriteEditor.marianAntiphon", selection: $prayer.rosary.marianAntiphon) {
            ForEach(MarianAntiphonOption.allCases) { option in
              Text(option.displayName).tag(option)
            }
          }
          Toggle("favoriteEditor.stMichaelPrayer", isOn: $prayer.rosary.includeStMichaelPrayer)
          Toggle("favoriteEditor.finalSignOfCross", isOn: $prayer.rosary.includeFinalSignOfCross)
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
      RemindersSection(reminders: $prayer.reminders, kind: prayer.kind)
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

#Preview("New Angelus") {
  NavigationStack {
    FavoriteEditorView(
      prayer: Prayer(
        name: "Angelus",
        kind: .angelus,
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

//
//  PresetEditorView.swift
//  Prosary
//

import SwiftUI

struct PresetEditorView: View {
    @State var config: RosaryConfig
    let isNew: Bool

    @Environment(\.appServices) private var services
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $config.name, prompt: Text("e.g. Morning Rosary"))
                Toggle("Use as my default preset", isOn: $config.isDefault)
            }

            Section("Prayer Language") {
                Picker("Language", selection: $config.languageCode) {
                    ForEach(LanguageCatalog.all) { language in
                        Text(language.nativeName).tag(language.code)
                    }
                }
            }

            Section("Which mysteries?") {
                Picker("Mysteries", selection: $config.mysterySelectionMode) {
                    ForEach(MysterySelectionMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                if config.mysterySelectionMode == .specific {
                    Picker("Specific set", selection: $config.specificMysteryGroup) {
                        ForEach(MysteryGroup.allCases) { group in
                            Text(group.displayName).tag(group)
                        }
                    }
                }
            }

            Section("Opening & Decade Prayers") {
                Toggle("Apostles' Creed", isOn: $config.includeApostlesCreed)
                Toggle("Opening Our Father & 3 Hail Marys", isOn: $config.includeOpeningPrayers)
                Toggle("Fatima Prayer after each decade", isOn: $config.includeFatimaPrayer)
                Picker("For the faithful departed", selection: $config.eternalRestForDeceased) {
                    ForEach(EternalRestPlacement.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
            }

            Section("Closing Prayers") {
                Picker("Marian antiphon", selection: $config.marianAntiphon) {
                    ForEach(MarianAntiphonOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                Toggle("St. Michael Prayer", isOn: $config.includeStMichaelPrayer)
                Toggle("Final Sign of the Cross", isOn: $config.includeFinalSignOfCross)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(isNew ? "New Preset" : "Edit Preset")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
    }

    private func save() {
        var toSave = config
        if toSave.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            toSave.name = "My Rosary"
        }
        Task {
            try? await services.presetStore.save(toSave)
            dismiss()
        }
    }
}

#Preview("New") {
    NavigationStack {
        PresetEditorView(config: RosaryConfig(), isNew: true)
    }
}

#Preview("Edit") {
    NavigationStack {
        PresetEditorView(
            config: RosaryConfig(
                name: "Evening Rosary for the Departed", mysterySelectionMode: .specific,
                specificMysteryGroup: .sorrowful, includeOpeningPrayers: false,
                eternalRestForDeceased: .afterEachDecade, includeStMichaelPrayer: true, languageCode: "en"),
            isNew: false)
    }
}

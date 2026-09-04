//
//  RosaryQuickSetupView.swift
//  Prosary
//
//  Extracted from RosaryPresetPickerView when the Pray tab became the favorites list: choosing
//  which saved Rosary to pray is what that list does now, but praying an unsaved one still
//  needs its own setup sheet. Reached from Pray's + menu.
//

import SwiftUI

/// The "Pray any Rosary" quick setup: the full Rosary options editor over a scratch Prayer —
/// pray it without saving anything, or keep it as a new preset (never stealing the default
/// slot unless it's the first preset).
struct RosaryQuickSetupView: View {
  let seed: RosaryOptions
  let hasPresets: Bool
  let onPray: (Prayer) -> Void
  let onSaved: () -> Void

  @Environment(\.appServices) private var services
  @Environment(\.dismiss) private var dismiss

  @State private var options = RosaryOptions()
  @State private var showsSaveNamePrompt = false
  @State private var presetName = ""
  @State private var didSeed = false
  /// Both events from a Mac double-click must describe the same transient prayer so the
  /// navigation path can recognize the second event as a duplicate.
  @State private var scratchPrayerID = UUID()

  var body: some View {
    NavigationStack {
      Form {
        RosaryOptionsSections(rosary: $options)

        Section {
          Button {
            showsSaveNamePrompt = true
          } label: {
            Label("rosaryPicker.saveAsPreset", systemImage: "bookmark")
          }
        }
      }
      .formStyle(.grouped)
      .navigationTitle("rosaryPicker.anyRosary")
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("favoriteEditor.cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("favorites.pray") {
            onPray(Prayer(id: scratchPrayerID, name: "", kind: .rosary, rosary: options))
          }
        }
      }
      .alert("rosaryPicker.saveAsPreset", isPresented: $showsSaveNamePrompt) {
        TextField(
          String(localized: "rosaryPicker.presetNamePlaceholder", defaultValue: "Preset name"),
          text: $presetName)
        Button("favoriteEditor.save") { save() }
        Button("favoriteEditor.cancel", role: .cancel) {}
      }
      .onAppear {
        guard !didSeed else { return }
        didSeed = true
        options = seed
      }
    }
  }

  private func save() {
    let name = presetName.trimmingCharacters(in: .whitespaces)
    let preset = Prayer(
      name: name.isEmpty ? PrayerKind.rosary.defaultName : name,
      kind: .rosary,
      isDefault: !hasPresets,
      rosary: options)
    Task {
      try? await services.presetStore.save(preset)
      onSaved()
      dismiss()
    }
  }
}

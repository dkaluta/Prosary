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
  @State private var isSaving = false
  @State private var saveError: String?

  var body: some View {
    NavigationStack {
      setupLayout
      .navigationTitle("rosaryPicker.anyRosary")
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      #if !os(macOS)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("favoriteEditor.cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("favorites.pray") { pray() }
        }
      }
      #endif
      .interactiveDismissDisabled(isSaving)
      .alert("rosaryPicker.saveAsPreset", isPresented: $showsSaveNamePrompt) {
        TextField(
          String(localized: "rosaryPicker.presetNamePlaceholder", defaultValue: "Preset name"),
          text: $presetName)
        Button("favoriteEditor.save") { save() }
          .keyboardShortcut(.defaultAction)
        Button("favoriteEditor.cancel", role: .cancel) {}
      }
      .alert(
        String(localized: "favoriteEditor.saveFailed", defaultValue: "Could Not Save Favorite"),
        isPresented: .init(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
      ) {
        Button("common.ok") { saveError = nil }
          .keyboardShortcut(.defaultAction)
      } message: {
        Text(saveError ?? "")
      }
      .onAppear {
        guard !didSeed else { return }
        didSeed = true
        options = seed
      }
    }
  }

  @ViewBuilder private var setupLayout: some View {
    #if os(macOS)
    MacPrayerEditorSheet(preferredSize: CGSize(width: 600, height: 600)) {
      setupSections
    } actions: {
      Button("favoriteEditor.cancel") { dismiss() }
        .keyboardShortcut(.cancelAction)
      Button("favorites.pray") { pray() }
        .keyboardShortcut(.defaultAction)
    }
    .disabled(isSaving)
    #else
    Form { setupSections }
      .formStyle(.grouped)
      .disabled(isSaving)
    #endif
  }

  @ViewBuilder private var setupSections: some View {
    RosaryOptionsSections(rosary: $options)

    Section {
      Button {
        showsSaveNamePrompt = true
      } label: {
        Label("rosaryPicker.saveAsPresetAction", systemImage: "bookmark")
      }
    }
  }

  private func pray() {
    onPray(Prayer(id: scratchPrayerID, name: "", kind: .rosary, rosary: options))
  }

  private func save() {
    guard !isSaving else { return }
    isSaving = true
    let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
    let preset = Prayer(
      name: name.isEmpty ? PrayerKind.rosary.defaultName : name,
      kind: .rosary,
      isDefault: !hasPresets,
      rosary: options)
    Task {
      defer { isSaving = false }
      do {
        try await services.presetStore.save(preset)
        onSaved()
        dismiss()
      } catch {
        saveError = error.localizedDescription
      }
    }
  }
}

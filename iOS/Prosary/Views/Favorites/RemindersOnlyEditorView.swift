//
//  RemindersOnlyEditorView.swift
//  Prosary
//
//  The compact editor for an existing Prayer row. Generic bundle rows expose their schema-driven
//  `options.json` choices plus reminders; Rosary/Jesus rows use it for reminder-only actions.
//  This view never creates a row. Bundle display names and traditional reminder presets come
//  from the manifest.
//

import SwiftUI

struct RemindersOnlyEditorView: View {
  @State var prayer: Prayer

  @Environment(\.appServices) private var services
  @Environment(\.dismiss) private var dismiss

  /// `prayer.kind.displayName` is only a generic fallback (a single `PrayerKind` case can't
  /// carry per-bundle text) — read the real name from the bundle's own manifest.
  private var info: CustomDevotionInfo? {
    prayer.customDevotionId.flatMap { PrayerPackStore.info(for: $0) }
  }

  private var options: [CustomDevotionOption] {
    prayer.customDevotionId.map { PrayerPackStore.options(for: $0) } ?? []
  }

  var body: some View {
    Form {
      if !options.isEmpty {
        Section("favoriteEditor.options") {
          ForEach(options, id: \.key) { option in
            switch option.kind {
            case .toggle:
              Toggle(option.localizedName, isOn: toggleBinding(for: option))
            case .choice:
              Picker(option.localizedName, selection: choiceBinding(for: option)) {
                ForEach(option.cases ?? [], id: \.id) { optionCase in
                  Text(optionCase.localizedName).tag(optionCase.id)
                }
              }
            }
          }
        }
      }
      RemindersSection(
        reminders: $prayer.reminders,
        presetHours: info?.reminderPresetHours ?? [],
        presetFooter: info?.localizedReminderPresetFooter)
    }
    .formStyle(.grouped)
    .navigationTitle(info?.localizedDisplayName ?? prayer.kind.displayName)
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

  // Bindings read through to the option's declared default so the rows show the effective
  // value even before the user has ever touched them; writes store an explicit override.
  private func toggleBinding(for option: CustomDevotionOption) -> Binding<Bool> {
    Binding(
      get: { (prayer.customOptions[option.key] ?? option.defaultValue) == "true" },
      set: { prayer.customOptions[option.key] = $0 ? "true" : "false" })
  }

  private func choiceBinding(for option: CustomDevotionOption) -> Binding<String> {
    Binding(
      get: { prayer.customOptions[option.key] ?? option.defaultValue },
      set: { prayer.customOptions[option.key] = $0 })
  }

  private func save() {
    let toSave = prayer
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

#Preview("Angelus") {
  NavigationStack {
    RemindersOnlyEditorView(prayer: Prayer(
      name: "Angelus",
      kind: .custom,
      isDefault: true,
      customDevotionId: "angelus",
      reminders: [PrayerReminder(hour: 6), PrayerReminder(hour: 18)]
    ))
  }
}

#Preview("Stations — no reminders yet") {
  NavigationStack {
    RemindersOnlyEditorView(prayer: Prayer(
      name: "Stations of the Cross",
      kind: .custom,
      isDefault: true,
      customDevotionId: "stationsOfTheCross"
    ))
  }
}

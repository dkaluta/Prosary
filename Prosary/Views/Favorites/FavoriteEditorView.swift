
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

  /// Hours that have dedicated Angelus toggle rows (traditional bell times).
  private let angelusPresetHours: Set<Int> = [6, 12, 18]

  var body: some View {
    Form {
      // MARK: Common fields
      Section {
        TextField("Name", text: $prayer.name, prompt: Text("e.g. Morning Rosary"))
        Toggle("Set as default for \(prayer.kind.displayName)", isOn: $prayer.isDefault)
      }

      Section {
        Picker("Language", selection: $prayer.languageCode) {
          let defaultName = LanguageCatalog.resolve(appDefaultCode).nativeName
          Text("Default — \(defaultName)").tag(LanguageCatalog.defaultSentinel)
          ForEach(LanguageCatalog.all) { language in
            Text(language.nativeName).tag(language.code)
          }
        }
      } header: {
        Text("Prayer Language")
      } footer: {
        #if os(iOS)
        Text("The default language is set in [Settings → Prosary](app-settings:).")
        #endif
      }

      // MARK: Rosary options
      if prayer.kind == .rosary {
        Section("Which mysteries?") {
          Picker("Mysteries", selection: $prayer.rosary.mysterySelectionMode) {
            ForEach(MysterySelectionMode.allCases) { mode in
              Text(mode.displayName).tag(mode)
            }
          }
          if prayer.rosary.mysterySelectionMode == .specific {
            Picker("Specific set", selection: $prayer.rosary.specificMysteryGroup) {
              ForEach(MysteryGroup.allCases) { group in
                Text(group.displayName).tag(group)
              }
            }
          }
        }

        Section("Opening & Decade Prayers") {
          Toggle("Apostles' Creed", isOn: $prayer.rosary.includeApostlesCreed)
          Toggle("Opening Our Father & 3 Hail Marys", isOn: $prayer.rosary.includeOpeningPrayers)
          Toggle("Fatima Prayer after each decade", isOn: $prayer.rosary.includeFatimaPrayer)
          Picker("For the faithful departed", selection: $prayer.rosary.eternalRestForDeceased) {
            ForEach(EternalRestPlacement.allCases) { option in
              Text(option.displayName).tag(option)
            }
          }
        }

        Section("Closing Prayers") {
          Picker("Marian antiphon", selection: $prayer.rosary.marianAntiphon) {
            ForEach(MarianAntiphonOption.allCases) { option in
              Text(option.displayName).tag(option)
            }
          }
          Toggle("St. Michael Prayer", isOn: $prayer.rosary.includeStMichaelPrayer)
          Toggle("Final Sign of the Cross", isOn: $prayer.rosary.includeFinalSignOfCross)
        }
      }

      // MARK: Jesus Prayer options
      if prayer.kind == .jesusPrayer {
        Section("Target") {
          Picker("Repetitions", selection: $prayer.jesusPrayer.target) {
            Text("33").tag(JesusPrayerTarget.count(33))
            Text("66").tag(JesusPrayerTarget.count(66))
            Text("99").tag(JesusPrayerTarget.count(99))
            Text("Unbounded").tag(JesusPrayerTarget.unbounded)
          }
          .pickerStyle(.segmented)
        }
      }

      // MARK: Reminders
      Section {
        if prayer.kind == .angelus {
          // Traditional Angelus bell times — quick toggles for 6am, noon, 6pm.
          Toggle("6:00 AM", isOn: angelusTimeBinding(hour: 6))
          Toggle("12:00 PM", isOn: angelusTimeBinding(hour: 12))
          Toggle("6:00 PM", isOn: angelusTimeBinding(hour: 18))

          ForEach(customReminders) { reminder in
            reminderRow(for: reminder.id)
          }
        } else {
          ForEach(prayer.reminders) { reminder in
            reminderRow(for: reminder.id)
          }
        }

        Button {
          prayer.reminders.append(PrayerReminder(hour: 9, minute: 0))
        } label: {
          Label("Add Reminder", systemImage: "plus")
        }
      } header: {
        Text("Reminders")
      } footer: {
        if prayer.kind == .angelus, !prayer.reminders.isEmpty {
          Text("Traditional times correspond to the Angelus bell. All reminders repeat daily.")
        } else if !prayer.reminders.isEmpty {
          Text("Reminders repeat daily.")
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle(isNew ? "New Favorite" : "Edit Favorite")
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

  // MARK: - Reminder helpers

  /// Toggles presence of a `PrayerReminder` at exactly `hour:00` for the Angelus presets.
  private func angelusTimeBinding(hour: Int) -> Binding<Bool> {
    Binding(
      get: {
        prayer.reminders.contains { $0.hour == hour && $0.minute == 0 && $0.isEnabled }
      },
      set: { isOn in
        if isOn {
          if !prayer.reminders.contains(where: { $0.hour == hour && $0.minute == 0 }) {
            prayer.reminders.append(PrayerReminder(hour: hour, minute: 0))
          } else if let i = prayer.reminders.firstIndex(where: { $0.hour == hour && $0.minute == 0 }) {
            prayer.reminders[i].isEnabled = true
          }
        } else {
          prayer.reminders.removeAll { $0.hour == hour && $0.minute == 0 }
        }
      }
    )
  }

  /// Reminders that don't map to one of the three traditional Angelus preset times.
  private var customReminders: [PrayerReminder] {
    prayer.reminders.filter { r in
      !(angelusPresetHours.contains(r.hour) && r.minute == 0)
    }
  }

  /// A DatePicker + delete row bound to an existing reminder by ID.
  @ViewBuilder
  private func reminderRow(for reminderId: UUID) -> some View {
    HStack {
      DatePicker("", selection: dateBinding(for: reminderId), displayedComponents: .hourAndMinute)
        .labelsHidden()
      Spacer()
      Button(role: .destructive) {
        prayer.reminders.removeAll { $0.id == reminderId }
      } label: {
        Image(systemName: "minus.circle.fill")
          .foregroundStyle(.red)
      }
      .buttonStyle(.borderless)
    }
  }

  private func dateBinding(for reminderId: UUID) -> Binding<Date> {
    Binding(
      get: {
        prayer.reminders.first(where: { $0.id == reminderId })?.asDate ?? Date()
      },
      set: { date in
        guard let i = prayer.reminders.firstIndex(where: { $0.id == reminderId }) else { return }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        prayer.reminders[i].hour = comps.hour ?? 0
        prayer.reminders[i].minute = comps.minute ?? 0
      }
    )
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

//
//  RemindersOnlyEditorView.swift
//  Prosary
//
//  Lightweight reminders editor for the generic (bundle-driven) devotions — these have no name,
//  language, or per-favorite options to edit (see FavoritesListView), just reminders. Reachable
//  from the star row's bell button, and only once the devotion is favorited (a Prayer row must
//  already exist to attach reminders to — this view never creates one). The devotion's display
//  name and any traditional preset reminder times come from its bundle manifest.
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

  var body: some View {
    Form {
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

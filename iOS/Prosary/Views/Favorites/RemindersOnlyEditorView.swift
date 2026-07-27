//
//  RemindersOnlyEditorView.swift
//  Prosary
//
//  Lightweight reminders editor for the 5 non-configurable devotion kinds (Angelus, Stations of
//  the Cross, Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet) — these have no name,
//  language, or per-favorite options to edit (see FavoritesListView), just reminders. Reachable
//  from the star row's bell button, and only once the kind is favorited (a Prayer row must
//  already exist to attach reminders to — this view never creates one).
//

import SwiftUI

struct RemindersOnlyEditorView: View {
  @State var prayer: Prayer

  @Environment(\.appServices) private var services
  @Environment(\.dismiss) private var dismiss

  /// For `.custom`, `prayer.kind.displayName` is only a generic fallback (a single `PrayerKind`
  /// case can't carry per-bundle text) — read the real name from the bundle's own manifest.
  private var navigationTitleText: String {
    guard prayer.kind == .custom, let devotionId = prayer.customDevotionId else {
      return prayer.kind.displayName
    }
    return PrayerPackStore.info(for: devotionId)?.localizedDisplayName ?? prayer.kind.displayName
  }

  var body: some View {
    Form {
      RemindersSection(reminders: $prayer.reminders, kind: prayer.kind)
    }
    .formStyle(.grouped)
    .navigationTitle(navigationTitleText)
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
      name: PrayerKind.angelus.defaultName,
      kind: .angelus,
      isDefault: true,
      reminders: [PrayerReminder(hour: 6), PrayerReminder(hour: 18)]
    ))
  }
}

#Preview("Stations — no reminders yet") {
  NavigationStack {
    RemindersOnlyEditorView(prayer: Prayer(
      name: PrayerKind.stationsOfTheCross.defaultName,
      kind: .stationsOfTheCross,
      isDefault: true
    ))
  }
}

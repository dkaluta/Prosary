//
//  RemindersSection.swift
//  Prosary
//
//  The reminders Form section, shared by FavoriteEditorView (Rosary/Jesus Prayer's full editor)
//  and RemindersOnlyEditorView (the lightweight sheet for Angelus/Stations/Franciscan
//  Crown/Seven Sorrows/Divine Mercy Chaplet). Extracted so both editors manage reminders
//  identically instead of drifting.
//

import SwiftUI

struct RemindersSection: View {
  @Binding var reminders: [PrayerReminder]
  let kind: PrayerKind

  /// Hours that have dedicated Angelus toggle rows (traditional bell times).
  private let angelusPresetHours: Set<Int> = [6, 12, 18]

  var body: some View {
    Section {
      if kind == .angelus {
        // Traditional Angelus bell times — quick toggles for 6am, noon, 6pm.
        Toggle("favoriteEditor.angelusTime6Am", isOn: angelusTimeBinding(hour: 6))
        Toggle("favoriteEditor.angelusTimeNoon", isOn: angelusTimeBinding(hour: 12))
        Toggle("favoriteEditor.angelusTime6Pm", isOn: angelusTimeBinding(hour: 18))

        ForEach(customReminders) { reminder in
          reminderRow(for: reminder.id)
        }
      } else {
        ForEach(reminders) { reminder in
          reminderRow(for: reminder.id)
        }
      }

      Button {
        reminders.append(PrayerReminder(hour: 9, minute: 0))
      } label: {
        Label("favoriteEditor.addReminder", systemImage: "plus")
      }
    } header: {
      Text("favoriteEditor.remindersHeader")
    } footer: {
      if kind == .angelus, !reminders.isEmpty {
        Text("favoriteEditor.angelusRemindersFooter")
      } else if !reminders.isEmpty {
        Text("favoriteEditor.remindersFooter")
      }
    }
  }

  /// Toggles presence of a `PrayerReminder` at exactly `hour:00` for the Angelus presets.
  private func angelusTimeBinding(hour: Int) -> Binding<Bool> {
    Binding(
      get: {
        reminders.contains { $0.hour == hour && $0.minute == 0 && $0.isEnabled }
      },
      set: { isOn in
        if isOn {
          if !reminders.contains(where: { $0.hour == hour && $0.minute == 0 }) {
            reminders.append(PrayerReminder(hour: hour, minute: 0))
          } else if let i = reminders.firstIndex(where: { $0.hour == hour && $0.minute == 0 }) {
            reminders[i].isEnabled = true
          }
        } else {
          reminders.removeAll { $0.hour == hour && $0.minute == 0 }
        }
      }
    )
  }

  /// Reminders that don't map to one of the three traditional Angelus preset times.
  private var customReminders: [PrayerReminder] {
    reminders.filter { r in
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
        reminders.removeAll { $0.id == reminderId }
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
        reminders.first(where: { $0.id == reminderId })?.asDate ?? Date()
      },
      set: { date in
        guard let i = reminders.firstIndex(where: { $0.id == reminderId }) else { return }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        reminders[i].hour = comps.hour ?? 0
        reminders[i].minute = comps.minute ?? 0
      }
    )
  }
}

#Preview("Angelus") {
  @Previewable @State var reminders = [PrayerReminder(hour: 6), PrayerReminder(hour: 12)]
  Form {
    RemindersSection(reminders: $reminders, kind: .angelus)
  }
  .formStyle(.grouped)
}

#Preview("Stations") {
  @Previewable @State var reminders = [PrayerReminder(hour: 15, minute: 0)]
  Form {
    RemindersSection(reminders: $reminders, kind: .stationsOfTheCross)
  }
  .formStyle(.grouped)
}

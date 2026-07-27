//
//  RemindersSection.swift
//  Prosary
//
//  The reminders Form section, shared by FavoriteEditorView (Rosary/Jesus Prayer's full editor)
//  and RemindersOnlyEditorView (the lightweight sheet for the generic bundle devotions).
//  Extracted so both editors manage reminders identically instead of drifting.
//
//  A devotion with traditional fixed prayer times ships them in its bundle manifest
//  (`reminderPresetHours` — the Angelus's 6am/noon/6pm bells) and gets one quick toggle per
//  preset hour plus an explanatory footer, instead of any kind-specific special case here.
//

import SwiftUI

struct RemindersSection: View {
  @Binding var reminders: [PrayerReminder]
  /// Whole hours that get dedicated quick-toggle rows (from the devotion's manifest); empty for
  /// devotions without traditional fixed times.
  var presetHours: [Int] = []
  /// Footer shown (instead of the generic one) while any reminder exists, explaining the presets.
  var presetFooter: String? = nil

  var body: some View {
    Section {
      if !presetHours.isEmpty {
        ForEach(presetHours, id: \.self) { hour in
          Toggle(presetLabel(hour: hour), isOn: presetTimeBinding(hour: hour))
        }

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
      if let presetFooter, !reminders.isEmpty {
        Text(presetFooter)
      } else if !reminders.isEmpty {
        Text("favoriteEditor.remindersFooter")
      }
    }
  }

  /// "6:00 AM" / "12:00 PM"-style label for a preset hour, in the user's locale.
  private func presetLabel(hour: Int) -> String {
    let components = DateComponents(hour: hour, minute: 0)
    guard let date = Calendar.current.date(from: components) else { return "\(hour):00" }
    return date.formatted(date: .omitted, time: .shortened)
  }

  /// Toggles presence of a `PrayerReminder` at exactly `hour:00` for the preset rows.
  private func presetTimeBinding(hour: Int) -> Binding<Bool> {
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

  /// Reminders that don't map to one of the preset times.
  private var customReminders: [PrayerReminder] {
    reminders.filter { r in
      !(presetHours.contains(r.hour) && r.minute == 0)
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

#Preview("With preset hours (Angelus-style)") {
  @Previewable @State var reminders = [PrayerReminder(hour: 6), PrayerReminder(hour: 12)]
  Form {
    RemindersSection(
      reminders: $reminders, presetHours: [6, 12, 18],
      presetFooter: "Traditional times correspond to the Angelus bell. All reminders repeat daily.")
  }
  .formStyle(.grouped)
}

#Preview("Plain") {
  @Previewable @State var reminders = [PrayerReminder(hour: 15, minute: 0)]
  Form {
    RemindersSection(reminders: $reminders)
  }
  .formStyle(.grouped)
}

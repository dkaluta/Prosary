import SwiftUI

struct TodayReminderSettings: View {
  var body: some View {
    Section {
      DateSpecificReminderControls(label: "settings.reminders.readings",
        enabledKey: TodayReminderScheduler.readingsEnabledKey, timeKey: TodayReminderScheduler.readingsTimeKey,
        identifier: "readingsReminderEnabled")
      DateSpecificReminderControls(label: "settings.reminders.saints",
        enabledKey: TodayReminderScheduler.saintsEnabledKey, timeKey: TodayReminderScheduler.saintsTimeKey,
        identifier: "saintReminderEnabled")
    } header: { Text("settings.reminders.header") }
    footer: { ReminderSettingsFooter() }
  }
}

/// The Readings surface edits the same preference and scheduled reminder as global Settings.
struct ReadingsReminderSettings: View {
  var body: some View {
    Section {
      DateSpecificReminderControls(label: "settings.reminders.readings",
        enabledKey: TodayReminderScheduler.readingsEnabledKey, timeKey: TodayReminderScheduler.readingsTimeKey,
        identifier: "readingsReminderEnabled")
    } header: { Text("settings.reminders.header") }
    footer: {
      Text("settings.readingsReminderFooter")
      Text("settings.reminders.window")
    }
  }
}

private struct ReminderSettingsFooter: View {
  var body: some View {
    Text("settings.reminders.footer")
    Text("settings.reminders.window")
  }
}

private struct DateSpecificReminderControls: View {
  let label: LocalizedStringKey
  let identifier: String
  @AppStorage private var isEnabled: Bool
  @AppStorage private var minutes: Int
  @State private var showsPermissionHelp = false

  init(label: LocalizedStringKey, enabledKey: String, timeKey: String, identifier: String) {
    self.label = label
    self.identifier = identifier
    _isEnabled = AppStorage(wrappedValue: false, enabledKey)
    _minutes = AppStorage(wrappedValue: 540, timeKey)
  }

  var body: some View {
    Group {
      Toggle(label, isOn: enabledBinding)
        .accessibilityIdentifier(identifier)
      if isEnabled {
        DatePicker("settings.reminders.time", selection: timeBinding, displayedComponents: .hourAndMinute)
          .environment(\.locale, .autoupdatingCurrent)
      }
    }
    .onChange(of: minutes) { _, _ in Task { await TodayReminderScheduler.refresh() } }
    .alert("settings.reminders.permissionTitle", isPresented: $showsPermissionHelp) {
      Button("common.ok", role: .cancel) { }
    } message: { Text("settings.reminders.permissionBody") }
  }

  private var enabledBinding: Binding<Bool> {
    Binding(get: { isEnabled }, set: { enabled in
      if enabled {
        Task {
          if await ReminderScheduler.requestPermission() { isEnabled = true }
          else { showsPermissionHelp = true }
          await TodayReminderScheduler.refresh()
        }
      } else {
        isEnabled = false
        Task { await TodayReminderScheduler.refresh() }
      }
    })
  }

  private var timeBinding: Binding<Date> {
    Binding(get: {
      Calendar.autoupdatingCurrent.date(bySettingHour: minutes / 60,
        minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }, set: { date in
      let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
      minutes = (components.hour ?? 9) * 60 + (components.minute ?? 0)
    })
  }
}

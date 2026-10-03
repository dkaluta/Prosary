import SwiftUI

struct TodayReminderSettings: View {
  @AppStorage(TodayReminderScheduler.readingsEnabledKey) private var readingsEnabled = false
  @AppStorage(TodayReminderScheduler.readingsTimeKey) private var readingsMinutes = 540
  @AppStorage(TodayReminderScheduler.saintsEnabledKey) private var saintsEnabled = false
  @AppStorage(TodayReminderScheduler.saintsTimeKey) private var saintsMinutes = 540
  @State private var showsPermissionHelp = false

  var body: some View {
    Section {
      Toggle("settings.reminders.readings", isOn: enabledBinding($readingsEnabled))
        .accessibilityIdentifier("readingsReminderEnabled")
      if readingsEnabled {
        DatePicker("settings.reminders.time", selection: timeBinding($readingsMinutes), displayedComponents: .hourAndMinute)
          .environment(\.locale, .autoupdatingCurrent)
      }
      Toggle("settings.reminders.saints", isOn: enabledBinding($saintsEnabled))
        .accessibilityIdentifier("saintReminderEnabled")
      if saintsEnabled {
        DatePicker("settings.reminders.time", selection: timeBinding($saintsMinutes), displayedComponents: .hourAndMinute)
          .environment(\.locale, .autoupdatingCurrent)
      }
    } header: { Text("settings.reminders.header") }
    footer: {
      Text("settings.reminders.footer")
      Text("settings.reminders.window")
    }
    .onChange(of: readingsMinutes) { _, _ in Task { await TodayReminderScheduler.refresh() } }
    .onChange(of: saintsMinutes) { _, _ in Task { await TodayReminderScheduler.refresh() } }
    .alert("settings.reminders.permissionTitle", isPresented: $showsPermissionHelp) {
      Button("common.ok", role: .cancel) { }
    } message: { Text("settings.reminders.permissionBody") }
  }

  private func enabledBinding(_ stored: Binding<Bool>) -> Binding<Bool> {
    Binding(get: { stored.wrappedValue }, set: { enabled in
      if enabled {
        Task {
          if await ReminderScheduler.requestPermission() { stored.wrappedValue = true }
          else { showsPermissionHelp = true }
          await TodayReminderScheduler.refresh()
        }
      } else {
        stored.wrappedValue = false
        Task { await TodayReminderScheduler.refresh() }
      }
    })
  }

  private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
    Binding(get: {
      Calendar.autoupdatingCurrent.date(bySettingHour: minutes.wrappedValue / 60,
        minute: minutes.wrappedValue % 60, second: 0, of: Date()) ?? Date()
    }, set: { date in
      let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
      minutes.wrappedValue = (components.hour ?? 9) * 60 + (components.minute ?? 0)
    })
  }
}

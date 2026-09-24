#if os(macOS)
import AppKit
import Combine
import SwiftUI

/// A reference desk inside the Mac library. Browsing dates never changes a prayer session.
struct MacTodayView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openWindow) private var openWindow
  @AppStorage(TodayInfoStore.calendarDefaultsKey) private var feastCalendarId = ""
  @AppStorage(TodayInfoStore.paschaStyleDefaultsKey) private var easternPaschaStyle = "julian"
  @AppStorage("showTodayFeast") private var showsFeast = true
  @AppStorage("showTodayIntention") private var showsIntention = true
  @AppStorage("showTodayTorahPortion") private var showsTorah = false

  @State private var dateSelection = MacTodayDateSelection()
  @State private var showsDatePicker = false
  @State private var showsOptions = false
  @State private var feast: FeastDay?
  @State private var intention: PopeIntention?
  @State private var dayInfo: LiturgicalDayInfo?
  @State private var readings: [ReadingCitation] = []
  @State private var torah: TorahPortion?

  private var language: String { UILanguage.current }
  private var selectedDate: Date { dateSelection.localDate() }
  private var passageContext: String { "\(dateSelection.day)|\(feastCalendarId)|\(easternPaschaStyle)" }
  private var isToday: Bool { dateSelection.isToday() }
  private var selectedCalendarName: String {
    TodayInfoStore.calendars.first { $0.id == TodayInfoStore.selectedCalendarId }?.displayName ?? ""
  }
  private var readingsTitle: String {
    isToday ? label("home.today.readings", "Today’s readings")
      : label("home.today.selectedReadings", "Readings")
  }
  private var dateLabel: String {
    formattedDate(template: "yMMMMdEEEE")
  }
  private var toolbarDateLabel: String {
    formattedDate(template: "yMMMd")
  }
  private func formattedDate(template: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: language)
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.setLocalizedDateFormatFromTemplate(template)
    return formatter.string(from: selectedDate)
  }

  var body: some View {
    readingContent
    // The window toolbar owns navigation and its material; readings remain ordinary content.
    .background(Color(nsColor: .textBackgroundColor))
    .accessibilityIdentifier("macToday.content")
    .toolbar { dateToolbar }
    .environment(\.layoutDirection, UILanguage.isRightToLeft(language) ? .rightToLeft : .leftToRight)
    .environment(\.locale, Locale(identifier: language == "tl" ? "fil" : language))
    .accessibilityIdentifier("macToday")
    .onAppear { refreshCurrentDay() }
    .onChange(of: dateSelection.day) { _, _ in load() }
    .onChange(of: feastCalendarId) { _, _ in load() }
    .onChange(of: easternPaschaStyle) { _, _ in load() }
    .onChange(of: showsFeast) { _, _ in load() }
    .onChange(of: showsIntention) { _, _ in load() }
    .onChange(of: showsTorah) { _, _ in load() }
    .onChange(of: scenePhase) { _, phase in if phase == .active { refreshCurrentDay() } }
    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshCurrentDay() }
    .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in refreshCurrentDay() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refreshCurrentDay() }
    .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
      .receive(on: RunLoop.main)) { _ in load() }
  }

  private var readingContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text(selectedCalendarName)
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("macToday.calendarName")
        if let dayInfo {
          Text(HebrewDisplayText.unpointed(dayInfo.localized(language)))
            .font(.subheadline).foregroundStyle(.secondary)
            .accessibilityIdentifier("macToday.dayHeading")
        }
        if let feast {
          VStack(alignment: .leading, spacing: 6) {
            Text(feast.localizedTitle(language))
              .font(.title2.weight(["Solemnity", "1st Class", "Great Feast"].contains(feast.rank) ? .bold : .semibold))
              .accessibilityAddTraits(.isHeader)
            Text(feast.localizedRank(language)).foregroundStyle(.secondary)
          }
          .accessibilityIdentifier("macToday.feast")
        }
        if let intention {
          VStack(alignment: .leading, spacing: 8) {
            Text(String(format: label("home.today.popesIntention", "The Pope’s intention: %@"),
                        locale: Locale(identifier: language), intention.localizedTitle(language)))
              .font(.headline).accessibilityAddTraits(.isHeader)
            Text(intention.localizedText(language)).lineSpacing(3)
          }
          .accessibilityIdentifier("macToday.intention")
        }
        if !readings.isEmpty || torah != nil { ReadingEditionPicker() }
        if !readings.isEmpty { readingsSection }
        if let torah { torahSection(torah) }
        Button(label("about.section.calendar", "Calendar Data")) {
          openWindow(id: "about")
        }
        .buttonStyle(.link)
        .accessibilityIdentifier("macToday.calendarData")
      }
      .textSelection(.enabled)
      .frame(maxWidth: 720, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(24)
    }
  }

  @ToolbarContentBuilder
  private var dateToolbar: some ToolbarContent {
    ToolbarItem(id: "today.previousDay", placement: .navigation) {
      Button { dateSelection.move(by: -1) } label: {
        Label(label("home.today.previousDay", "Previous Day"), systemImage: "chevron.backward")
      }
      .labelStyle(.iconOnly)
      .buttonBorderShape(.circle)
      .disabled(!dateSelection.canMoveBackward)
      .help(label("home.today.previousDay", "Previous Day"))
      .accessibilityIdentifier("macToday.previousDay")
    }
    if #available(macOS 26.0, *) {
      ToolbarSpacer(.fixed, placement: .navigation)
    }
    ToolbarItem(id: "today.chooseDate", placement: .navigation) {
      Button { showsDatePicker = true } label: {
        Text(toolbarDateLabel).lineLimit(1)
      }
      .buttonBorderShape(.capsule)
      .help(dateLabel)
      .accessibilityLabel(dateLabel)
      .accessibilityHint(label("home.today.chooseDate", "Choose a date"))
      .accessibilityIdentifier("macToday.chooseDate")
      .popover(isPresented: $showsDatePicker) { datePopover }
    }
    if #available(macOS 26.0, *) {
      ToolbarSpacer(.fixed, placement: .navigation)
    }
    ToolbarItem(id: "today.nextDay", placement: .navigation) {
      Button { dateSelection.move(by: 1) } label: {
        Label(label("home.today.nextDay", "Next Day"), systemImage: "chevron.forward")
      }
      .labelStyle(.iconOnly)
      .buttonBorderShape(.circle)
      .disabled(!dateSelection.canMoveForward)
      .help(label("home.today.nextDay", "Next Day"))
      .accessibilityIdentifier("macToday.nextDay")
    }
    ToolbarItem(id: "today.reset", placement: .primaryAction) {
      Button { chooseDate(Date()) } label: {
        Label(label("home.today.today", "Today"), systemImage: "calendar.badge.clock")
      }
      .labelStyle(.iconOnly)
      .buttonBorderShape(.circle)
      .disabled(isToday)
      .help(label("home.today.today", "Today"))
      .accessibilityIdentifier("macToday.reset")
    }
    if #available(macOS 26.0, *) {
      ToolbarSpacer(.fixed, placement: .primaryAction)
    }
    ToolbarItem(id: "today.options", placement: .primaryAction) {
      Button { showsOptions = true } label: {
        Label(label("settings.title", "Settings"), systemImage: "slider.horizontal.3")
      }
      .labelStyle(.iconOnly)
      .buttonBorderShape(.circle)
      .help(label("settings.todayHeader", "Today"))
      .accessibilityIdentifier("macToday.options")
      .popover(isPresented: $showsOptions) { optionsPopover }
    }
  }

  private var datePopover: some View {
    ReadingDatePickerPopover(selection: Binding(get: { selectedDate }, set: chooseDate),
                             range: MacTodayDateSelection.pickerRange(),
                             pickerIdentifier: "macToday.datePicker",
                             todayIdentifier: "macToday.dateReset",
                             doneIdentifier: "macToday.dateDone") {
      showsDatePicker = false
    }
  }

  private var optionsPopover: some View {
    MacPrayerEditorForm {
      Section {
        Picker(label("settings.feastCalendar", "Liturgical calendar"),
               selection: Binding(get: { TodayInfoStore.selectedCalendarId }, set: { feastCalendarId = $0 })) {
          ForEach(TodayInfoStore.calendars) { calendar in
            Text(calendar.displayName).tag(calendar.id)
          }
        }
        .accessibilityIdentifier("macToday.calendarPicker")
        if TodayInfoStore.selectedCalendarId == "ugcc" {
          Picker(label("settings.easternPaschaStyle", "Byzantine Easter date"),
                 selection: Binding(get: { TodayInfoStore.selectedPaschaStyle }, set: { easternPaschaStyle = $0 })) {
            Text(label("settings.easternPaschaStyle.julian", "Julian Easter")).tag("julian")
            Text(label("settings.easternPaschaStyle.gregorian", "Gregorian Easter")).tag("gregorian")
          }
          .accessibilityIdentifier("macToday.paschaPicker")
        }
      }
      Section {
        Toggle(label("settings.showTodayFeast", "Show the day's feast"), isOn: $showsFeast)
          .accessibilityIdentifier("macToday.showFeast")
        Toggle(label("settings.showTodayIntention", "Show the Pope's intention"), isOn: $showsIntention)
          .accessibilityIdentifier("macToday.showIntention")
        Toggle(label("settings.showTodayTorahPortion", "Show the weekly Torah portion"), isOn: $showsTorah)
          .accessibilityIdentifier("macToday.showTorah")
        if showsTorah {
          Text(label("settings.torahPortionFooter", "The upcoming Sabbath’s Torah reading, following the Eretz Israel schedule."))
            .font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .frame(width: 400, height: 340)
  }

  private var readingsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(readingsTitle).font(.headline).accessibilityAddTraits(.isHeader)
      ForEach(Array(readings.enumerated()), id: \.offset) { _, reading in
        ScripturePassageView(reading: reading, interfaceLanguage: language)
          .id(passageContext)
      }
    }
    .accessibilityIdentifier("macToday.readings")
  }

  private func torahSection(_ portion: TorahPortion) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(portion.isHoliday ? label("home.today.festivalTorahReading", "Festival Torah reading")
        : label("home.today.torahPortion", "Weekly Torah portion"))
        .font(.headline).accessibilityAddTraits(.isHeader)
      Text(portion.localizedTitle(language))
      ForEach(Array(portion.readings.enumerated()), id: \.offset) { _, reading in
        ScripturePassageView(reading: reading, isTorah: true, interfaceLanguage: language)
          .id(passageContext)
      }
    }
    .accessibilityIdentifier("macToday.torah")
  }

  private func chooseDate(_ date: Date) {
    dateSelection.select(date)
    showsDatePicker = false
  }

  private func refreshCurrentDay() {
    dateSelection.refresh()
    load()
  }

  private func load() {
    // Disabled rows do not load. The selected calendar supplies its own feast and readings.
    feast = showsFeast ? TodayInfoStore.feast(on: selectedDate) : nil
    intention = showsIntention ? TodayInfoStore.intention(for: selectedDate) : nil
    dayInfo = TodayInfoStore.displayDayInfo(on: selectedDate)
    readings = TodayInfoStore.readings(on: selectedDate)
    torah = showsTorah ? TodayInfoStore.torahPortion(on: selectedDate) : nil
  }

  private func label(_ key: String, _ fallback: String) -> String {
    UILanguage.text(key, language: language, fallback: fallback)
  }
}
#endif

#if os(macOS)
import AppKit
import Combine
import SwiftUI

/// A reference desk inside the Mac library. Browsing dates never changes a prayer session.
struct MacTodayView: View {
  var opensCalendar = false
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openWindow) private var openWindow
  @AppStorage(TodayInfoStore.calendarDefaultsKey) private var feastCalendarId = ""
  @AppStorage(TodayInfoStore.paschaStyleDefaultsKey) private var easternPaschaStyle = "julian"
  @AppStorage("showTodayFeast") private var showsFeast = true
  @AppStorage("showTodayIntention") private var showsIntention = true
  @AppStorage("showTodayTorahPortion") private var showsTorah = false
  @AppStorage(ReadingDisplayOrder.defaultsKey) private var reverseReadingsOrder = false
  @AppStorage(TodayCardColor.defaultsKey) private var todayCardColor = TodayCardColor.default.rawValue

  @State private var dateSelection = MacTodayDateSelection()
  @State private var showsDatePicker = false
  @State private var showsCalendar = false
  @State private var showsFeasts = false
  @State private var feast: FeastDay?
  @State private var intention: PopeIntention?
  @State private var dayInfo: LiturgicalDayInfo?
  @State private var readings: [ReadingCitation] = []
  @State private var torah: TorahPortion?

  private var language: String { UILanguage.current }
  private var displayedReadings: [ReadingDisplayOrder.Row<ReadingCitation>] { ReadingDisplayOrder.indexed(readings, reverse: reverseReadingsOrder) }
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
    .toolbar {
      ToolbarItem {
        Button { showsFeasts = true } label: {
          Label(label("calendar.feastsAndSolemnities", "Feasts and Solemnities"), systemImage: "calendar")
        }
      }
    }
    .sheet(isPresented: $showsCalendar) {
      VStack(spacing: 0) {
        LiturgicalCalendarView(dateSelection: $dateSelection, onSelectDate: { showsCalendar = false })
        HStack {
          Spacer()
          Button(label("common.done", "Done")) { showsCalendar = false }.keyboardShortcut(.defaultAction)
        }.padding()
      }.frame(minWidth: 480, minHeight: 520)
    }
    .sheet(isPresented: $showsFeasts) {
      VStack(spacing: 0) {
        Text(label("calendar.feastsAndSolemnities", "Feasts and Solemnities"))
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
        FeastsAndSolemnitiesView(dateSelection: $dateSelection, onSelectDate: { showsFeasts = false })
        Divider()
        HStack {
          Spacer()
          Button(label("common.done", "Done")) { showsFeasts = false }.keyboardShortcut(.defaultAction)
        }.padding()
      }
      .frame(minWidth: 480, minHeight: 520)
    }
    .onAppear { if opensCalendar { showsCalendar = true } }
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
      VStack(alignment: .leading, spacing: 18) {
        daySummary
        if !readings.isEmpty || torah != nil {
          Divider()
          readingHeading
          if !readings.isEmpty { readingsSection }
          if let torah { torahSection(torah) }
        }
        if let intention {
          Divider()
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
              Text(label("homeWidgets.popeIntention", "Pope’s Intention"))
                .font(.headline).accessibilityAddTraits(.isHeader)
              PapalKeysSymbol(size: 18).foregroundStyle(Color.appAccent)
            }
            Text(verbatim: intention.localizedTitle(language)).font(.subheadline.weight(.medium))
            Text(verbatim: intention.localizedText(language)).lineSpacing(3)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier("macToday.intention")
        }
        Divider()
        Button(label("about.section.calendar", "Calendar Data")) {
          openWindow(id: "about")
        }
        .buttonStyle(.link)
        .font(.caption)
        .accessibilityIdentifier("macToday.calendarData")
      }
      .textSelection(.enabled)
      .frame(maxWidth: 600, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(24)
    }
  }

  private var daySummary: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(selectedCalendarName)
          .font(.caption).foregroundStyle(.secondary)
          .accessibilityIdentifier("macToday.calendarName")
        if let dayInfo {
          Text(HebrewDisplayText.unpointed(dayInfo.localized(language)))
            .font(.subheadline).foregroundStyle(.secondary)
            .padding(.vertical, 3)
            .background((TodayCardColor(rawValue: todayCardColor) ?? .default).tint,
                        in: RoundedRectangle(cornerRadius: 4))
            .accessibilityIdentifier("macToday.dayHeading")
        }
      }
      if let feast {
        VStack(alignment: .leading, spacing: 6) {
          Text(verbatim: feast.localizedTitle(language))
            .font(.title.weight(["Solemnity", "1st Class", "Great Feast"].contains(feast.rank) ? .bold : .semibold))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
          Text(verbatim: feast.localizedRank(language))
            .font(.subheadline).foregroundStyle(.secondary)
          SaintDescriptionsView(feast: feast, calendarID: TodayInfoStore.selectedCalendarId, language: language)
            .padding(.top, 4)
            .id("\(passageContext)|\(language)")
        }
        .accessibilityIdentifier("macToday.feast")
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var readingHeading: some View {
    VStack(alignment: .leading, spacing: 8) {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: 16) {
          Text(readingsTitle).font(.headline).accessibilityAddTraits(.isHeader)
            .fixedSize(horizontal: true, vertical: false)
          Spacer(minLength: 12)
          ReadingEditionPicker(compact: true, showsNotice: false).frame(width: 280)
        }
        VStack(alignment: .leading, spacing: 8) {
          Text(readingsTitle).font(.headline).accessibilityAddTraits(.isHeader)
          ReadingEditionPicker(compact: true, showsNotice: false)
            .frame(maxWidth: 300, alignment: .leading)
        }
      }
      Text(label("readings.bibleNote", "Bible passages; wording may differ from the liturgical reading."))
        .font(.caption).foregroundStyle(.secondary)
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

  private var readingsSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      ForEach(Array(displayedReadings.enumerated()), id: \.element.id) { index, row in
        let reading = row.value
        if let group = reading.sourceGroup, !group.isEmpty,
           index == 0 || displayedReadings[index - 1].value.sourceGroup != group {
          Text(group).font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
        }
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

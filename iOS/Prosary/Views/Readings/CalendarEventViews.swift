import SwiftUI

struct CalendarMonthGrid: View {
  @Binding var dateSelection: MacTodayDateSelection
  var showsToday = true
  @AppStorage(TodayInfoStore.calendarDefaultsKey) private var calendarID = ""
  @AppStorage(TodayInfoStore.paschaStyleDefaultsKey) private var paschaStyle = "julian"
  @Environment(\.colorScheme) private var colorScheme
  private var calendar: Calendar { Calendar(identifier: .gregorian) }
  private var date: Date { dateSelection.localDate() }
  private var cells: [Date?] { CalendarEventPresentation.monthCells(for: date) }
  private var formatter: DateFormatter {
    let value = DateFormatter(); value.locale = UILanguage.locale; value.calendar = calendar
    return value
  }

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Button { moveMonth(-1) } label: { Image(systemName: "chevron.backward") }
          .accessibilityLabel(calendarLabel("previousMonth", "Previous Month"))
          .disabled(dateSelection.day.year == MacTodayDateSelection.minimumDay.year && dateSelection.day.month == MacTodayDateSelection.minimumDay.month)
        Spacer()
        Text(monthTitle).font(.headline)
        Spacer()
        Button { moveMonth(1) } label: { Image(systemName: "chevron.forward") }
          .accessibilityLabel(calendarLabel("nextMonth", "Next Month"))
          .disabled(dateSelection.day.year == MacTodayDateSelection.maximumDay.year && dateSelection.day.month == MacTodayDateSelection.maximumDay.month)
      }.buttonStyle(.borderless).frame(minHeight: 44)
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
        ForEach(0..<7, id: \.self) { index in
          Text(formatter.veryShortStandaloneWeekdaySymbols[(index + 1) % 7]).font(.caption).foregroundStyle(.secondary)
            .accessibilityLabel(formatter.standaloneWeekdaySymbols[(index + 1) % 7])
        }
        ForEach(cells.indices, id: \.self) { index in
          if let day = cells[index] { dayCell(day) }
          else { Color.clear.frame(minHeight: 48).accessibilityHidden(true) }
        }
      }
      if showsToday {
        Button(UILanguage.text("home.today.today", language: UILanguage.current, fallback: "Today")) { dateSelection.select(Date()) }.buttonStyle(.bordered)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("calendar.monthPicker")
  }

  private var monthTitle: String {
    let value = formatter; value.setLocalizedDateFormatFromTemplate("yMMMM"); return value.string(from: date)
  }

  private func dayCell(_ day: Date) -> some View {
    let _ = calendarID; let _ = paschaStyle
    let events = CalendarEventPresentation.events(on: day, feast: TodayInfoStore.feast(on: day))
    let selected = calendar.isDate(day, inSameDayAs: date)
    let selectedForeground: Color = colorScheme == .dark ? .black : .white
    let fullDate = formatter; fullDate.dateStyle = .full
    let eventCount = String.localizedStringWithFormat(calendarLabel("events", "%lld events"), events.count)
    return Button { dateSelection.select(day) } label: {
      VStack(spacing: 3) {
        Text(calendar.component(.day, from: day), format: .number.locale(UILanguage.locale)).font(.body)
          .foregroundStyle(selected ? selectedForeground : Color.primary)
        HStack(spacing: 3) {
          ForEach(0..<min(events.count, 3), id: \.self) { _ in Circle().fill(selected ? selectedForeground : Color.appAccent).frame(width: 4, height: 4) }
        }.frame(height: 5)
      }
      .frame(maxWidth: .infinity, minHeight: 48)
      .background(selected ? Color.appAccent : Color.clear, in: RoundedRectangle(cornerRadius: 9))
      .overlay { if calendar.isDateInToday(day) && !selected { RoundedRectangle(cornerRadius: 9).stroke(Color.appAccent, lineWidth: 1) } }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(fullDate.string(from: day)), \(eventCount)")
    .accessibilityAddTraits(selected ? .isSelected : [])
    .accessibilityIdentifier("calendar.day.\(PrayerRunProgress.localDateString(for: day, calendar: calendar))")
  }

  private func moveMonth(_ offset: Int) {
    guard let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
          let next = calendar.date(byAdding: .month, value: offset, to: first) else { return }
    dateSelection.select(next)
  }
}

struct CalendarDayEvents: View {
  let date: Date
  var openReadings: () -> Void = {}
  @State private var selectedEvent: CalendarEvent?
  @AppStorage(TodayInfoStore.calendarDefaultsKey) private var calendarID = ""
  @AppStorage(TodayInfoStore.paschaStyleDefaultsKey) private var paschaStyle = "julian"
  private var events: [CalendarEvent] {
    let _ = calendarID; let _ = paschaStyle
    return CalendarEventPresentation.events(on: date, feast: TodayInfoStore.feast(on: date))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if events.isEmpty { Text(calendarLabel("noEventsOnDate", "No published events are available for this date.")).foregroundStyle(.secondary) }
      ForEach(events) { event in
        Button { selectedEvent = event } label: { CalendarEventRow(event: event) }.buttonStyle(.plain)
          .accessibilityIdentifier("calendar.event.\(event.index)")
      }
    }
    .sheet(item: $selectedEvent) { event in
      CalendarEventDetail(event: event) { selectedEvent = nil; openReadings() }
    }
    .onChange(of: calendarID) { _, _ in selectedEvent = nil }
    .onChange(of: date) { _, _ in selectedEvent = nil }
  }
}

struct CalendarEventRow: View {
  let event: CalendarEvent
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(event.title(UILanguage.current)).foregroundStyle(.primary).font(.subheadline.weight(.semibold))
        Text(event.feast.localizedRank(UILanguage.current)).font(.caption).foregroundStyle(.secondary)
        if let description = event.description(UILanguage.current) {
          Text(verbatim: description.text).font(.caption).foregroundStyle(.secondary).lineLimit(3)
        }
      }
      Spacer(minLength: 0)
      Image(systemName: "chevron.forward").font(.caption).foregroundStyle(.tertiary).accessibilityHidden(true)
    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
  }
}

struct CalendarEventDetail: View {
  let event: CalendarEvent
  var openReadings: () -> Void
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text(event.title(UILanguage.current)).font(.title2.weight(.semibold))
          Text(CalendarEventPresentation.dateLabel(event.date)).font(.subheadline).foregroundStyle(.secondary)
          Text(event.feast.localizedRank(UILanguage.current)).font(.caption).foregroundStyle(.secondary)
          if let description = event.description(UILanguage.current) {
            Text(verbatim: description.text).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            if let credit = description.credit { Text(verbatim: credit).font(.caption).foregroundStyle(.secondary) }
            if let source = description.sourceURL {
              Link(UILanguage.text("readings.source", language: UILanguage.current, fallback: "Text source"), destination: source).font(.caption)
            }
          } else { Text(calendarLabel("noEventDescription", "No description is available for this event.")).foregroundStyle(.secondary) }
          Button(calendarLabel("readings", "Readings")) { openReadings() }.buttonStyle(.bordered)
        }.frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity).padding(20)
      }
      .navigationTitle(calendarLabel("eventDetails", "Event Details"))
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button(UILanguage.text("common.done", language: UILanguage.current, fallback: "Done")) { dismiss() } } }
    }
    .environment(\.layoutDirection, UILanguage.isRightToLeft(UILanguage.current) ? .rightToLeft : .leftToRight)
    #if os(macOS)
    .frame(minWidth: 460, minHeight: 420)
    #endif
  }
}

private func calendarLabel(_ key: String, _ fallback: String) -> String {
  UILanguage.text("calendar." + key, language: UILanguage.current, fallback: fallback)
}

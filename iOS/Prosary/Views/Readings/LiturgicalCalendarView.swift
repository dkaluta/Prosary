import SwiftUI

/// Every sourced date and observance remains available, regardless of its liturgical rank.
struct FeastsAndSolemnitiesView: View {
  @Binding var dateSelection: MacTodayDateSelection
  var onSelectDate: () -> Void = {}
  @AppStorage(TodayInfoStore.calendarDefaultsKey) private var calendarID = ""
  @AppStorage(TodayInfoStore.paschaStyleDefaultsKey) private var paschaStyle = "julian"
  @AppStorage("calendarViewMode") private var viewMode = "list"
  @State private var selectedEvent: CalendarEvent?
  @State private var pendingReadingsDate: Date?

  private var rows: [(date: Date, feast: FeastDay)] {
    let _ = calendarID; let _ = paschaStyle
    return TodayInfoStore.publishedCalendarDays()
  }

  var body: some View {
    VStack(spacing: 0) {
      Picker(label("view", "Calendar View"), selection: $viewMode) {
        Text(label("listView", "List")).tag("list")
        Text(label("monthView", "Month")).tag("month")
      }.pickerStyle(.segmented).padding().accessibilityIdentifier("calendar.viewMode")
      if viewMode == "month" { LiturgicalCalendarView(dateSelection: $dateSelection, onSelectDate: onSelectDate) }
      else { eventList }
    }
    .navigationTitle(label("eventCalendar", "Event Calendar"))
    .environment(\.layoutDirection, UILanguage.isRightToLeft(UILanguage.current) ? .rightToLeft : .leftToRight)
    .accessibilityIdentifier("feastsAndSolemnities.screen")
    .sheet(item: $selectedEvent, onDismiss: {
      guard let date = pendingReadingsDate else { return }
      pendingReadingsDate = nil
      dateSelection.select(date)
      onSelectDate()
    }) { event in
      CalendarEventDetail(event: event) { pendingReadingsDate = event.date; selectedEvent = nil }
    }
  }

  private var eventList: some View {
    ScrollViewReader { proxy in
      List {
        Section {
          Text(TodayInfoStore.calendars.first { $0.id == TodayInfoStore.selectedCalendarId }?.displayName ?? "")
            .font(.caption).foregroundStyle(.secondary)
          if rows.isEmpty { Text(label("noFeasts", "No published feasts or solemnities are available in this calendar.")).foregroundStyle(.secondary) }
        }
        ForEach(rows, id: \.date) { row in
          Section {
            ForEach(CalendarEventPresentation.events(on: row.date, feast: row.feast)) { event in
              Button { selectedEvent = event } label: { CalendarEventRow(event: event) }.buttonStyle(.plain)
                .accessibilityIdentifier("calendar.listEvent.\(event.id)")
            }
          } header: {
            Text(CalendarEventPresentation.dateLabel(row.date, template: "yMMMMdEEEE"))
          }.id(row.date)
        }
      }
      .onAppear {
        if let row = rows.first(where: { $0.date >= dateSelection.localDate() }) ?? rows.last { proxy.scrollTo(row.date, anchor: .top) }
      }
    }
  }
  private func label(_ key: String, _ fallback: String) -> String { UILanguage.text("calendar." + key, language: UILanguage.current, fallback: fallback) }
}

/// Home and the Readings/desktop reference surfaces share the same marked civil-date grid.
struct LiturgicalCalendarView: View {
  @Binding var dateSelection: MacTodayDateSelection
  var onSelectDate: () -> Void = {}
  @AppStorage(TodayInfoStore.calendarDefaultsKey) private var calendarID = ""
  @AppStorage(TodayInfoStore.paschaStyleDefaultsKey) private var paschaStyle = "julian"

  var body: some View {
    List {
      Section {
        Text(TodayInfoStore.calendars.first { $0.id == TodayInfoStore.selectedCalendarId }?.displayName ?? "")
          .font(.caption).foregroundStyle(.secondary)
        CalendarMonthGrid(dateSelection: $dateSelection)
      }
      Section {
        CalendarDayEvents(date: dateSelection.localDate(), openReadings: onSelectDate)
      } header: {
        Text(CalendarEventPresentation.dateLabel(dateSelection.localDate()))
      }
    }
    .navigationTitle(UILanguage.text("calendar.title", language: UILanguage.current, fallback: "Liturgical Calendar"))
    .environment(\.layoutDirection, UILanguage.isRightToLeft(UILanguage.current) ? .rightToLeft : .leftToRight)
    .accessibilityIdentifier("liturgicalCalendar.screen")
  }
}

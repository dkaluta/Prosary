import SwiftUI

/// A month of this calendar's published observances. A date tap opens its readings.
struct LiturgicalCalendarView: View {
  @Binding var dateSelection: MacTodayDateSelection
  var onSelectDate: () -> Void = {}
  @AppStorage(TodayInfoStore.calendarDefaultsKey) private var calendarID = ""
  @AppStorage(TodayInfoStore.paschaStyleDefaultsKey) private var paschaStyle = "julian"

  private var calendar: Calendar { Calendar(identifier: .gregorian) }
  private var date: Date { dateSelection.localDate() }
  private var monthStart: Date {
    calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
  }
  private var days: [Date] {
    guard let range = calendar.range(of: .day, in: .month, for: date) else { return [] }
    return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: monthStart) }
  }
  private var rows: [(Date, FeastDay)] {
    // Reading the AppStorage values makes a Settings calendar change invalidate this view.
    _ = calendarID; _ = paschaStyle
    return days.compactMap { day in TodayInfoStore.feast(on: day).map { (day, $0) } }
  }
  private func formatted(_ date: Date, template: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = UILanguage.locale
    formatter.calendar = calendar
    formatter.setLocalizedDateFormatFromTemplate(template)
    return formatter.string(from: date)
  }

  var body: some View {
    List {
      Section {
        HStack {
          Button { moveMonth(-1) } label: {
            Image(systemName: "chevron.backward")
          }.accessibilityLabel(label("calendar.previousMonth", "Previous Month"))
            .disabled(dateSelection.day.year == MacTodayDateSelection.minimumDay.year
                      && dateSelection.day.month == MacTodayDateSelection.minimumDay.month)
          Spacer()
          Text(formatted(date, template: "yMMMM")).font(.headline)
          Spacer()
          Button { moveMonth(1) } label: {
            Image(systemName: "chevron.forward")
          }.accessibilityLabel(label("calendar.nextMonth", "Next Month"))
            .disabled(dateSelection.day.year == MacTodayDateSelection.maximumDay.year
                      && dateSelection.day.month == MacTodayDateSelection.maximumDay.month)
        }
        .buttonStyle(.borderless)
        Button(label("home.today.today", "Today")) { dateSelection = MacTodayDateSelection() }
        Text(TodayInfoStore.calendars.first { $0.id == TodayInfoStore.selectedCalendarId }?.displayName ?? "")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section {
        if rows.isEmpty {
          Text(label("calendar.noObservances", "No published observances are available for this month."))
            .foregroundStyle(.secondary)
        }
        ForEach(rows, id: \.0) { day, feast in
          Button {
            dateSelection.select(day)
            onSelectDate()
          } label: {
            HStack(alignment: .top, spacing: 16) {
              Text(formatted(day, template: "EEEd"))
                .font(.subheadline).foregroundStyle(.secondary).frame(minWidth: 70, alignment: .leading)
              VStack(alignment: .leading, spacing: 4) {
                Text(feast.localizedTitle(UILanguage.current)).foregroundStyle(.primary)
                Text(feast.localizedRank(UILanguage.current)).font(.caption).foregroundStyle(.secondary)
              }
              Spacer(minLength: 0)
              Image(systemName: "chevron.forward").font(.caption).foregroundStyle(.tertiary)
            }
          }.buttonStyle(.plain)
        }
      }
    }
    .navigationTitle(label("calendar.title", "Liturgical Calendar"))
    .environment(\.layoutDirection, UILanguage.isRightToLeft(UILanguage.current) ? .rightToLeft : .leftToRight)
    .accessibilityIdentifier("liturgicalCalendar.screen")
  }

  private func moveMonth(_ offset: Int) {
    if let target = calendar.date(byAdding: .month, value: offset, to: monthStart) {
      dateSelection.select(target)
    }
  }
  private func label(_ key: StaticString, _ fallback: String.LocalizationValue) -> String {
    String(localized: key, defaultValue: fallback,
           bundle: UILanguage.bundle, locale: UILanguage.locale)
  }
}

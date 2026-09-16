#if !os(macOS)
import SwiftUI

/// Browsing civil dates leaves prayer mysteries and continuation unchanged.
struct ReadingsView: View {
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage(TodayInfoStore.calendarDefaultsKey) private var calendarID = ""
  @AppStorage(TodayInfoStore.paschaStyleDefaultsKey) private var paschaStyle = "julian"
  @AppStorage("showTodayFeast") private var showsFeast = true
  @AppStorage("showTodayTorahPortion") private var showsTorah = false
  @State private var dateSelection = MacTodayDateSelection()
  @State private var showsDatePicker = false
  @State private var showsOptions = false
  @State private var readings: [ReadingCitation] = []
  @State private var feast: FeastDay?
  @State private var torah: TorahPortion?

  private var language: String { UILanguage.current }
  private var selectedDate: Date { dateSelection.localDate() }
  private var passageContext: String { "\(dateSelection.day)|\(calendarID)|\(paschaStyle)" }
  private var calendarName: String {
    TodayInfoStore.calendars.first { $0.id == TodayInfoStore.selectedCalendarId }?.displayName ?? ""
  }
  private var dateLabel: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: language == "tl" ? "fil" : language)
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.setLocalizedDateFormatFromTemplate("yMMMd")
    return formatter.string(from: selectedDate)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        if let feast {
          Text(feast.localizedTitle(language))
            .font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
        }
        ReadingEditionPicker()
        VStack(alignment: .leading, spacing: 14) {
          Text(String(localized: "home.today.selectedReadings", defaultValue: "Readings", bundle: UILanguage.bundle, locale: UILanguage.locale))
            .font(.headline).accessibilityAddTraits(.isHeader)
          if readings.isEmpty {
            Text(String(localized: "readings.noReadings", defaultValue: "No readings are available for this date in the selected calendar.", bundle: UILanguage.bundle, locale: UILanguage.locale))
              .foregroundStyle(.secondary)
              .accessibilityIdentifier("readings.empty")
          }
          ForEach(Array(readings.enumerated()), id: \.offset) { _, reading in
            ScripturePassageView(reading: reading, interfaceLanguage: language)
              .id(passageContext)
          }
        }
        if let torah {
          VStack(alignment: .leading, spacing: 14) {
            Text(torah.isHoliday
                 ? String(localized: "home.today.festivalTorahReading", defaultValue: "Festival Torah reading", bundle: UILanguage.bundle, locale: UILanguage.locale)
                 : String(localized: "home.today.torahPortion", defaultValue: "Weekly Torah portion", bundle: UILanguage.bundle, locale: UILanguage.locale))
              .font(.headline).accessibilityAddTraits(.isHeader)
            Text(torah.localizedTitle(language))
            ForEach(Array(torah.readings.enumerated()), id: \.offset) { _, reading in
              ScripturePassageView(reading: reading, isTorah: true, interfaceLanguage: language)
                .id(passageContext)
            }
          }
          .accessibilityIdentifier("readings.torah")
        }
      }
      .frame(maxWidth: 720, alignment: .leading)
      .frame(maxWidth: .infinity)
      .padding(20)
    }
    .prosaryNavigationBar(edge: .top) { dateNavigation }
    .navigationTitle(String(localized: "tabs.readings", defaultValue: "Readings", bundle: UILanguage.bundle, locale: UILanguage.locale))
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button { showsOptions = true } label: {
          Label(String(localized: "settings.title", defaultValue: "Settings", bundle: UILanguage.bundle, locale: UILanguage.locale), systemImage: "slider.horizontal.3")
        }
        .accessibilityIdentifier("readings.options")
      }
    }
    .sheet(isPresented: $showsOptions) { options }
    .environment(\.layoutDirection, UILanguage.isRightToLeft(language) ? .rightToLeft : .leftToRight)
    .environment(\.locale, Locale(identifier: language == "tl" ? "fil" : language))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("readings.screen")
    .onAppear { refresh() }
    .onChange(of: dateSelection.day) { _, _ in load() }
    .onChange(of: calendarID) { _, _ in load() }
    .onChange(of: paschaStyle) { _, _ in load() }
    .onChange(of: showsFeast) { _, _ in load() }
    .onChange(of: showsTorah) { _, _ in load() }
    .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refresh() }
    .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in refresh() }
  }

  private var dateNavigation: some View {
    VStack(spacing: 8) {
      ProsaryGlassControlGroup(spacing: 12) { dateControls }
      Text(calendarName)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private var dateControls: some View {
    HStack(spacing: 12) {
      Button { dateSelection.move(by: -1) } label: {
        Label(String(localized: "home.today.previousDay", defaultValue: "Previous Day", bundle: UILanguage.bundle, locale: UILanguage.locale), systemImage: "chevron.backward")
          .prosaryDateControlLabel()
      }
      .labelStyle(.iconOnly).disabled(!dateSelection.canMoveBackward)
      .accessibilityIdentifier("readings.previousDay")
      Button { showsDatePicker = true } label: {
        Text(dateLabel)
          .font(.subheadline.weight(.semibold))
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .prosaryDateControlLabel()
      }
      .accessibilityHint(String(localized: "home.today.chooseDate", defaultValue: "Choose a date", bundle: UILanguage.bundle, locale: UILanguage.locale))
      .accessibilityIdentifier("readings.chooseDate")
      .popover(isPresented: $showsDatePicker) { datePopover }
      Button { dateSelection.move(by: 1) } label: {
        Label(String(localized: "home.today.nextDay", defaultValue: "Next Day", bundle: UILanguage.bundle, locale: UILanguage.locale), systemImage: "chevron.forward")
          .prosaryDateControlLabel()
      }
      .labelStyle(.iconOnly).disabled(!dateSelection.canMoveForward)
      .accessibilityIdentifier("readings.nextDay")
    }
    .prosaryNavigationButtonStyle()
    #if os(visionOS)
    .controlSize(.extraLarge)
    #else
    .controlSize(.large)
    #endif
    .fixedSize(horizontal: false, vertical: true)
  }

  private var datePopover: some View {
    ReadingDatePickerPopover(selection: Binding(get: { selectedDate }, set: chooseDate),
                             range: MacTodayDateSelection.pickerRange(),
                             pickerIdentifier: "readings.datePicker",
                             todayIdentifier: "readings.reset",
                             doneIdentifier: "readings.dateDone") {
      showsDatePicker = false
    }
    .presentationCompactAdaptation(.popover)
  }

  private var options: some View {
    NavigationStack {
      Form {
        Picker(String(localized: "settings.feastCalendar", defaultValue: "Liturgical calendar", bundle: UILanguage.bundle, locale: UILanguage.locale),
               selection: Binding(get: { TodayInfoStore.selectedCalendarId }, set: { calendarID = $0 })) {
          ForEach(TodayInfoStore.calendars) { calendar in Text(calendar.displayName).tag(calendar.id) }
        }
        if TodayInfoStore.selectedCalendarId == "ugcc" {
          Picker(String(localized: "settings.easternPaschaStyle", defaultValue: "Byzantine Easter date", bundle: UILanguage.bundle, locale: UILanguage.locale), selection: $paschaStyle) {
            Text(String(localized: "settings.easternPaschaStyle.julian", defaultValue: "Julian Easter", bundle: UILanguage.bundle, locale: UILanguage.locale)).tag("julian")
            Text(String(localized: "settings.easternPaschaStyle.gregorian", defaultValue: "Gregorian Easter", bundle: UILanguage.bundle, locale: UILanguage.locale)).tag("gregorian")
          }
        }
        Toggle(String(localized: "settings.showTodayTorahPortion", defaultValue: "Show the weekly Torah portion", bundle: UILanguage.bundle, locale: UILanguage.locale), isOn: $showsTorah)
      }
      .navigationTitle(String(localized: "tabs.readings", defaultValue: "Readings", bundle: UILanguage.bundle, locale: UILanguage.locale))
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "common.done", defaultValue: "Done", bundle: UILanguage.bundle, locale: UILanguage.locale)) { showsOptions = false }
        }
      }
    }
  }

  private func chooseDate(_ date: Date) {
    dateSelection.select(date)
    showsDatePicker = false
  }
  private func refresh() { dateSelection.refresh(); load() }
  private func load() {
    feast = showsFeast ? TodayInfoStore.feast(on: selectedDate) : nil
    readings = TodayInfoStore.readings(on: selectedDate)
    torah = showsTorah ? TodayInfoStore.torahPortion(on: selectedDate) : nil
  }
}
#endif

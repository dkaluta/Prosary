import SwiftUI

/// Give the native calendar room for all seven columns and its larger spatial day targets.
struct ReadingDatePickerPopover: View {
  @Binding var selection: Date
  var range: ClosedRange<Date> = Date.distantPast...Date.distantFuture
  var pickerIdentifier: String
  var todayIdentifier: String
  var doneIdentifier: String
  var dismiss: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      #if os(iOS)
      // iPad window height can change without a compact vertical size class.
      // Only the calendar scrolls; Today and Done remain outside its clipped viewport.
      ScrollView { calendar }
        .scrollBounceBehavior(.basedOnSize)
        .frame(idealHeight: 420)
      #else
      calendar
      #endif
      HStack {
        Button(String(localized: "home.today.today", defaultValue: "Today", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
          selection = Date()
        }
        .disabled(Calendar(identifier: .gregorian).isDateInToday(selection))
        .accessibilityIdentifier(todayIdentifier)
        Spacer()
        Button(String(localized: "common.done", defaultValue: "Done", bundle: UILanguage.bundle, locale: UILanguage.locale), action: dismiss)
          .accessibilityIdentifier(doneIdentifier)
          .keyboardShortcut(.defaultAction)
      }
    }
    .buttonStyle(.bordered)
    #if os(macOS)
    .controlSize(.regular)
    #else
    .controlSize(.large)
    #endif
    .padding(padding)
    #if os(iOS)
    .frame(idealWidth: calendarWidth + 2 * padding)
    #else
    .fixedSize(horizontal: true, vertical: true)
    #endif
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(pickerIdentifier + ".popover")
  }

  private var calendar: some View {
    CalendarMonthGrid(dateSelection: Binding(get: { MacTodayDateSelection(now: selection) },
      set: { selection = min(max($0.localDate(), range.lowerBound), range.upperBound) }), showsToday: false)
      #if os(iOS)
      .frame(maxWidth: calendarWidth)
      #else
      .frame(width: calendarWidth)
      #endif
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityIdentifier(pickerIdentifier)
  }

  private var padding: CGFloat {
    #if os(visionOS)
    24
    #else
    16
    #endif
  }

  private var calendarWidth: CGFloat {
    #if os(visionOS)
    500
    #elseif os(macOS)
    288
    #else
    320
    #endif
  }
}

extension View {
  /// All labels in a date row share a height, including the icon-only day controls.
  func prosaryDateControlLabel() -> some View {
    self.frame(minWidth: dateControlMinimumLabelHeight,
               minHeight: dateControlMinimumLabelHeight, maxHeight: .infinity)
  }

  private var dateControlMinimumLabelHeight: CGFloat {
    #if os(visionOS)
    40
    #elseif os(macOS)
    18
    #else
    24
    #endif
  }
}

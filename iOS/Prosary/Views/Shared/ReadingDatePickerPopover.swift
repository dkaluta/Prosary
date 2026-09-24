import SwiftUI

/// Give the native calendar room for all seven columns and its larger spatial day targets.
struct ReadingDatePickerPopover: View {
  #if os(iOS)
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  #endif
  @Binding var selection: Date
  var range: ClosedRange<Date> = Date.distantPast...Date.distantFuture
  var pickerIdentifier: String
  var todayIdentifier: String
  var doneIdentifier: String
  var dismiss: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      #if os(iOS)
      if verticalSizeClass == .compact {
        ScrollView { calendar }
          .scrollBounceBehavior(.basedOnSize)
      } else {
        calendar
      }
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
    .fixedSize(horizontal: true, vertical: verticalSizeClass != .compact)
    #else
    .fixedSize(horizontal: true, vertical: true)
    #endif
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(pickerIdentifier + ".popover")
  }

  private var calendar: some View {
    DatePicker(String(localized: "home.today.chooseDate", defaultValue: "Choose a date", bundle: UILanguage.bundle, locale: UILanguage.locale),
               selection: $selection, in: range, displayedComponents: .date)
      .datePickerStyle(.graphical)
      .labelsHidden()
      .environment(\.calendar, Calendar(identifier: .gregorian))
      // The UIKit-backed graphical picker underreports its ideal width in a popover.
      .frame(width: calendarWidth)
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

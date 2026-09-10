//
//  JesusPrayerSetupView.swift
//  Prosary
//
//  Picks how many times to pray the Jesus Prayer before starting a session. "Custom" is purely a
//  UI affordance for entering a number here — by the time Begin is tapped it's already resolved
//  into a plain JesusPrayerTarget.count(_:), so nothing downstream ever sees "custom" as a case.
//

import SwiftUI

struct JesusPrayerSetupView: View {
  @Binding var path: [AppRoute]

  /// Laid out two to a row — the counts across the top, the two open-ended choices below —
  /// rather than one five-segment control, where "Unbounded" never fit on a phone.
  private enum SetupOption: String, CaseIterable, Identifiable {
    case thirtyThree, sixtySix, ninetyNine, custom, unbounded

    static let countRow: [SetupOption] = [.thirtyThree, .sixtySix, .ninetyNine]
    static let openRow: [SetupOption] = [.unbounded, .custom]

    var id: String { rawValue }

    var displayName: String {
      switch self {
      case .thirtyThree: return String(localized: "jesusPrayerTarget.33", defaultValue: "33")
      case .sixtySix: return String(localized: "jesusPrayerTarget.66", defaultValue: "66")
      case .ninetyNine: return String(localized: "jesusPrayerTarget.99", defaultValue: "99")
      case .custom: return String(localized: "jesusPrayerSetup.custom", defaultValue: "Custom")
      case .unbounded: return String(localized: "jesusPrayerOptions.unbounded", defaultValue: "Unbounded")
      }
    }

    var fixedCount: Int? {
      switch self {
      case .thirtyThree: return 33
      case .sixtySix: return 66
      case .ninetyNine: return 99
      case .custom, .unbounded: return nil
      }
    }
  }

  // This quick setup starts a temporary session; saved configurations live in favorites.
  @State private var selection: SetupOption = .thirtyThree
  @State private var customCountText = ""
  @FocusState private var isCustomCountFocused: Bool

  private var customCount: Int? {
    guard let value = Int(customCountText), value > 0 else { return nil }
    return value
  }

  private var canBegin: Bool {
    selection != .custom || customCount != nil
  }

  private var resolvedTarget: JesusPrayerTarget {
    switch selection {
    case .unbounded: return .unbounded
    case .custom: return .count(customCount ?? 1)
    case .thirtyThree, .sixtySix, .ninetyNine: return .count(selection.fixedCount ?? 1)
    }
  }

  /// One row of the target chooser. Each segment fills its share of the row so the two rows
  /// line up, and carries the `.isSelected` trait so VoiceOver and the tests can read the
  /// choice the way a segmented control would report it.
  @ViewBuilder
  private func targetRow(_ options: [SetupOption]) -> some View {
    HStack(spacing: 8) {
      ForEach(options) { option in
        let isSelected = selection == option
        Button {
          selection = option
        } label: {
          Text(option.displayName)
            .font(.callout)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            // Without this only the glyphs are hit-testable, so every tap on the pill's
            // padding — most of it — falls through and the row feels dead.
            .contentShape(Rectangle())
        }
        // .plain in a Form row lets the row swallow the tap; .borderless keeps each
        // segment individually clickable.
        .buttonStyle(.borderless)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.brandPrimary.opacity(0.18) : Color.secondary.opacity(0.12))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .strokeBorder(isSelected ? Color.brandPrimary : .clear, lineWidth: 1.5)
        )
        .foregroundStyle(isSelected ? Color.brandPrimary : .primary)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
      }
    }
  }

  var body: some View {
    setupLayout
    #if os(macOS)
    .frame(maxWidth: 640)
    .frame(maxWidth: .infinity)
    .onChange(of: selection) { _, newSelection in
      isCustomCountFocused = newSelection == .custom
    }
    #endif
    .navigationTitle("jesusPrayerFlow.title")
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      #if os(macOS)
      ToolbarItem(placement: .primaryAction) {
        Button("jesusPrayerSetup.begin") { begin() }
          .keyboardShortcut(.defaultAction)
          .disabled(!canBegin)
          .accessibilityIdentifier("jesusPrayerBeginButton")
      }
      #else
      ToolbarItem(placement: .confirmationAction) {
        Button("jesusPrayerSetup.begin") { begin() }
        .disabled(!canBegin)
      }
      #endif
    }
  }

  @ViewBuilder private var setupLayout: some View {
    #if os(macOS)
    MacPrayerEditorForm { setupSections }
    #else
    Form { setupSections }.formStyle(.grouped)
    #endif
  }

  @ViewBuilder private var setupSections: some View {
    Section("jesusPrayerSetup.howManyTimes") {
      #if os(macOS)
      Picker("jesusPrayerSetup.target", selection: $selection) {
        ForEach(SetupOption.allCases) { option in
          Text(option.displayName).tag(option)
        }
      }
      .pickerStyle(.radioGroup)
      .accessibilityIdentifier("jesusPrayerTargetPicker")
      #else
      VStack(spacing: 8) {
        targetRow(SetupOption.countRow)
        targetRow(SetupOption.openRow)
      }
      .accessibilityElement(children: .contain)
      .accessibilityLabel(Text("jesusPrayerSetup.target"))
      .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
      #endif

      if selection == .custom {
        TextField("jesusPrayerSetup.numberOfRepetitions", text: $customCountText)
          .accessibilityIdentifier("jesusPrayerCustomCount")
          #if os(macOS)
          .focused($isCustomCountFocused)
          .onSubmit { begin() }
          #endif
          #if os(iOS)
          .keyboardType(.numberPad)
          #endif
      }
    }
  }

  private func begin() {
    guard canBegin else { return }
    path.push(AppRoute.jesusPrayer(target: resolvedTarget))
  }
}

#Preview {
  NavigationStack {
    JesusPrayerSetupView(path: .constant([]))
  }
}

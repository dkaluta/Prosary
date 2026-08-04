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
  @Binding var path: NavigationPath

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

  // No persistence here (the whole app has none yet — see PresetStore's in-memory-only
  // implementation), so this always starts back at the same default rather than remembering
  // the last session's choice.
  @State private var selection: SetupOption = .thirtyThree
  @State private var customCountText = ""

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
        }
        .buttonStyle(.plain)
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
    Form {
      Section("jesusPrayerSetup.howManyTimes") {
        VStack(spacing: 8) {
          targetRow(SetupOption.countRow)
          targetRow(SetupOption.openRow)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("jesusPrayerSetup.target"))
        .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))

        if selection == .custom {
          TextField("jesusPrayerSetup.numberOfRepetitions", text: $customCountText)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("jesusPrayerFlow.title")
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("jesusPrayerSetup.begin") {
          path.append(AppRoute.jesusPrayer(target: resolvedTarget))
        }
        .disabled(!canBegin)
      }
    }
  }
}

#Preview {
  NavigationStack {
    JesusPrayerSetupView(path: .constant(NavigationPath()))
  }
}

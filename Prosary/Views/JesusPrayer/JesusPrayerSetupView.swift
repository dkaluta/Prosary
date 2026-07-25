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

  private enum SetupOption: String, CaseIterable, Identifiable {
    case thirtyThree, sixtySix, ninetyNine, custom, unbounded

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

  var body: some View {
    Form {
      Section("jesusPrayerSetup.howManyTimes") {
        Picker("jesusPrayerSetup.target", selection: $selection) {
          ForEach(SetupOption.allCases) { option in
            Text(option.displayName).tag(option)
          }
        }
        .pickerStyle(.segmented)

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

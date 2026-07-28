//
//  ContentView.swift
//  Prosary
//

import SwiftUI

struct ContentView: View {
  @State private var path = NavigationPath()
  private var coordinator = NavigationCoordinator.shared

  var body: some View {
    NavigationStack(path: $path) {
      HomeView(path: $path)
        .navigationDestination(for: AppRoute.self) { route in
          switch route {
          case .prayer(let id):
            PrayerDispatchView(prayerId: id, path: $path)
          case .favorites:
            FavoritesListView(path: $path)
          case .about:
            AboutView()
          case .jesusPrayerSetup:
            JesusPrayerSetupView(path: $path)
          case .jesusPrayer(let target):
            JesusPrayerFlowView(path: $path, target: target)
          case .custom(let devotionId):
            CustomDevotionFlowView(devotionId: devotionId)
          case .rosaryPicker:
            RosaryPresetPickerView(path: $path)
          case .rosaryQuickPray(let prayer):
            RosaryFlowView(prayer: prayer)
          }
        }
    }
    .onChange(of: coordinator.pendingRoute) { _, newValue in
      guard let newValue else { return }
      path.append(newValue)
      coordinator.pendingRoute = nil
    }
    .task {
      if let pending = coordinator.pendingRoute {
        path.append(pending)
        coordinator.pendingRoute = nil
      }
    }
  }
}

#Preview {
  ContentView()
}

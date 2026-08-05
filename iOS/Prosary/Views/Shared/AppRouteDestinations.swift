//
//  AppRouteDestinations.swift
//  Prosary
//
//  The one AppRoute -> View switch, shared by every tab's NavigationStack — extracted from
//  ContentView when the app grew tabs so four stacks don't carry four copies.
//

import SwiftUI

private struct AppRouteDestinations: ViewModifier {
  @Binding var path: NavigationPath

  func body(content: Content) -> some View {
    content.navigationDestination(for: AppRoute.self) { route in
      switch route {
      case .prayer(let id):
        PrayerDispatchView(prayerId: id, path: $path)
      case .about:
        AboutView()
      case .rosaryPresets:
        RosaryPresetsView(path: $path)
      case .jesusPrayerSetup:
        JesusPrayerSetupView(path: $path)
      case .jesusPrayer(let target):
        JesusPrayerFlowView(path: $path, target: target)
      case .custom(let devotionId):
        CustomDevotionFlowView(devotionId: devotionId)
      case .rosaryQuickPray(let prayer):
        RosaryFlowView(prayer: prayer)
      }
    }
  }
}

extension View {
  func appRouteDestinations(path: Binding<NavigationPath>) -> some View {
    modifier(AppRouteDestinations(path: path))
  }
}

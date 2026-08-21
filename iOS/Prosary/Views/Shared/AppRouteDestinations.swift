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
          .tabBarHiddenWhilePraying()
      case .about:
        AboutView()
      case .rosaryPresets:
        RosaryPresetsView(path: $path)
      case .jesusPrayerSetup:
        JesusPrayerSetupView(path: $path)
      case .jesusPrayer(let target):
        JesusPrayerFlowView(path: $path, target: target)
          .tabBarHiddenWhilePraying()
      case .custom(let devotionId):
        CustomDevotionFlowView(devotionId: devotionId)
          .tabBarHiddenWhilePraying()
      case .rosaryQuickPray(let prayer):
        RosaryFlowView(prayer: prayer)
          .tabBarHiddenWhilePraying()
      case .basicPrayers:
        BasicPrayersView()
      case .basicPrayer(let id):
        BasicPrayerFlowView(prayerId: id)
          .tabBarHiddenWhilePraying()
      }
    }
  }
}

private extension View {
  /// A prayer in progress owns the whole phone screen: the tab bar leaves so a stray tap
  /// can't wander off mid-Rosary, and its height goes back to the flow. Setup and picker
  /// screens keep it — only the flows themselves are praying. iPad and Mac keep their
  /// sidebar; a large screen never needed the room. (Idiom rather than size class: a
  /// Max-size phone in landscape reports `.regular` and must still hide.)
  @ViewBuilder
  func tabBarHiddenWhilePraying() -> some View {
    #if os(iOS)
    if UIDevice.current.userInterfaceIdiom == .phone {
      self.toolbar(.hidden, for: .tabBar)
    } else {
      self
    }
    #else
    self
    #endif
  }
}

extension View {
  func appRouteDestinations(path: Binding<NavigationPath>) -> some View {
    modifier(AppRouteDestinations(path: path))
  }
}

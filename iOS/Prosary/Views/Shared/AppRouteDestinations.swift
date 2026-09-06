//
//  AppRouteDestinations.swift
//  Prosary
//
//  The one AppRoute -> View switch, shared by every tab's NavigationStack — extracted from
//  ContentView when the app grew tabs so four stacks don't carry four copies.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

private struct AppRouteDestinations: ViewModifier {
  @Binding var path: [AppRoute]

  func body(content: Content) -> some View {
    content.navigationDestination(for: AppRoute.self) { route in
      Group {
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
        case .custom(let devotionId, let languageCode, let variantId):
          CustomDevotionFlowView(devotionId: devotionId, initialLanguageCode: languageCode, initialVariantId: variantId)
            .tabBarHiddenWhilePraying()
        case .rosaryQuickPray(let prayer):
          RosaryFlowView(prayer: prayer) { languageCode in
            path.removeLast()
            RunLoop.main.perform { path.push(.custom(devotionId: "litanyOfLoreto", languageCode: languageCode, variantId: "afterRosary")) }
          }
            .tabBarHiddenWhilePraying()
        case .basicPrayers:
          BasicPrayersView(path: $path)
        case .basicPrayer(let id):
          BasicPrayerFlowView(prayerId: id)
            .tabBarHiddenWhilePraying()
        }
      }
      .guardAgainstMacClickThrough(route: route)
    }
  }
}

#if os(macOS)
/// A double-click belongs to the control that was under the pointer when it began. SwiftUI
/// replaces a NavigationStack destination quickly enough that the second physical click can
/// otherwise activate a completely different control at the same screen coordinate — for
/// example Pray → Rosary presets → the default preset — producing a mysterious extra Back.
///
/// The clear overlay catches only a continuation click (`clickCount > 1`) during the user's
/// system double-click interval. A new single click passes straight through, as do keyboard
/// and assistive-technology actions; the guard itself is absent from the accessibility tree.
private struct MacNavigationClickThroughGuard: NSViewRepresentable {
  let route: AppRoute

  func makeNSView(context: Context) -> MacNavigationClickThroughView {
    let view = MacNavigationClickThroughView()
    view.arm(for: route)
    return view
  }

  func updateNSView(_ view: MacNavigationClickThroughView, context: Context) {
    view.arm(for: route)
  }
}

private final class MacNavigationClickThroughView: NSView {
  private var route: AppRoute?
  private var deadline = 0.0

  func arm(for newRoute: AppRoute) {
    guard route != newRoute else { return }
    route = newRoute
    deadline = ProcessInfo.processInfo.systemUptime + NSEvent.doubleClickInterval
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard ProcessInfo.processInfo.systemUptime <= deadline,
          let event = NSApp.currentEvent,
          event.type == .leftMouseDown,
          event.clickCount > 1 else { return nil }
    return self
  }

  override func mouseDown(with event: NSEvent) {}
}
#endif

private extension View {
  @ViewBuilder
  func guardAgainstMacClickThrough(route: AppRoute) -> some View {
    #if os(macOS)
    overlay {
      MacNavigationClickThroughGuard(route: route)
        .accessibilityHidden(true)
    }
    #else
    self
    #endif
  }

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
  func appRouteDestinations(path: Binding<[AppRoute]>) -> some View {
    modifier(AppRouteDestinations(path: path))
  }
}

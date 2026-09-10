//
//  NavigationCoordinator.swift
//  Prosary
//
//  App Intents (AppIntents/) run outside the view hierarchy and have no NavigationPath to push
//  onto directly. Only the active window may take an intent's pending route. Menus and
//  in-view handoffs use WindowNavigationActions instead of broadcasting through this object.
//

import Observation
import Foundation

@Observable
final class NavigationCoordinator {
  static let shared = NavigationCoordinator()

  var pendingRoute: AppRoute?

  private(set) var activeWindowID: UUID?

  func activateWindow(_ id: UUID) { activeWindowID = id }

  func closeWindow(_ id: UUID) {
    if activeWindowID == id { activeWindowID = nil }
  }

  func takePendingRoute(for windowID: UUID) -> AppRoute? {
    guard activeWindowID == windowID else { return nil }
    defer { pendingRoute = nil }
    return pendingRoute
  }
}

//
//  NavigationCoordinator.swift
//  Prosary
//
//  App Intents (AppIntents/) run outside the view hierarchy and have no NavigationPath to push
//  onto directly. An intent instead sets `pendingRoute`; ContentView observes this shared
//  instance and appends it to its own path, then clears it.
//

import Observation

@Observable
final class NavigationCoordinator {
  static let shared = NavigationCoordinator()

  var pendingRoute: AppRoute?

  /// Set by the menu bar's File → Import Devotion Bundle… (menu commands run outside the view
  /// hierarchy, like intents) — ContentView observes it, presents the file importer, and
  /// clears it.
  var pendingBundleImport = false

  private init() {}
}

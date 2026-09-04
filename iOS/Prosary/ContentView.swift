//
//  ContentView.swift
//  Prosary
//
//  The app's tab shell: Pray (Home), Browse (the prayers.prosary.app catalog), Categories
//  (devotions grouped by manifest tags), and Search (local + community). Bottom tabs on
//  iPhone; on iOS 18/macOS 15 the sidebarAdaptable style turns them into a sidebar on
//  iPad/Mac, matching the "bottom on phone, side on computer" design.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  private enum Tab: Hashable { case pray, browse, categories, search }

  @State private var selectedTab: Tab = .pray
  @State private var prayPath: [AppRoute] = []
  @State private var browsePath: [AppRoute] = []
  @State private var categoriesPath: [AppRoute] = []
  @State private var searchPath: [AppRoute] = []
  @State private var routeLandingGeneration = 0
  @State private var pendingLandingRoute: AppRoute?
  private var coordinator = NavigationCoordinator.shared
  @State private var showsBundleImporter = false
  @State private var importError: String?

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack(path: $prayPath) {
        HomeView(path: $prayPath)
          .appRouteDestinations(path: $prayPath)
      }
      // An external route replaces this stack wholesale. On macOS, resetting and then
      // repopulating one long-lived NavigationStack can leave its native Back control and the
      // bound path disagreeing: Back renders Home while the old route remains hidden in the
      // binding, so the next card is pushed on top of a ghost destination. A new identity makes
      // the replacement atomic — one stack owns exactly one path from its first render.
      .id(routeLandingGeneration)
      .tabItem {
        Label(String(localized: "tabs.pray", defaultValue: "Pray"), systemImage: "hands.and.sparkles")
      }
      .tag(Tab.pray)

      NavigationStack(path: $browsePath) {
        RepositoryBrowserView(presentedAsSheet: false)
          .appRouteDestinations(path: $browsePath)
      }
      .tabItem {
        Label(String(localized: "tabs.browse", defaultValue: "Browse"), systemImage: "globe")
      }
      .tag(Tab.browse)

      NavigationStack(path: $categoriesPath) {
        CategoriesView(path: $categoriesPath)
          .appRouteDestinations(path: $categoriesPath)
      }
      .tabItem {
        Label(String(localized: "tabs.categories", defaultValue: "Categories"), systemImage: "square.grid.2x2")
      }
      .tag(Tab.categories)

      NavigationStack(path: $searchPath) {
        SearchTabView(path: $searchPath)
          .appRouteDestinations(path: $searchPath)
      }
      .tabItem {
        Label(String(localized: "tabs.search", defaultValue: "Search"), systemImage: "magnifyingglass")
      }
      .tag(Tab.search)
    }
    .adaptiveTabViewStyle()
    .onChange(of: coordinator.pendingRoute) { _, newValue in
      guard let newValue else { return }
      land(newValue)
      coordinator.pendingRoute = nil
    }
    // File → Import Devotion Bundle… (menu commands run outside the view hierarchy, so the
    // importer is presented here at the root). Installed devotions are then discoverable in
    // Browse, Categories, and Search and may be pinned to Pray.
    .onChange(of: coordinator.pendingBundleImport) { _, newValue in
      guard newValue else { return }
      coordinator.pendingBundleImport = false
      showsBundleImporter = true
    }
    .fileImporter(
      isPresented: $showsBundleImporter,
      allowedContentTypes: [UTType(filenameExtension: "prosaryprayer") ?? .zip, .zip]
    ) { result in
      guard case .success(let url) = result else { return }
      do {
        // Installed devotions are found through Categories/Search/Browse and become saved
        // sessions only when starred, so there is nowhere to push to — stay put.
        try PrayerPackStore.installPack(fromUserSelected: url)
      } catch {
        importError = error.localizedDescription
      }
    }
    .alert(
      String(localized: "favorites.importFailed", defaultValue: "Could Not Import Devotion"),
      isPresented: .init(get: { importError != nil }, set: { if !$0 { importError = nil } })
    ) {
      Button("favoriteEditor.cancel", role: .cancel) {}
    } message: {
      Text(importError ?? "")
    }
    .task {
      if let pending = coordinator.pendingRoute {
        land(pending)
        coordinator.pendingRoute = nil
      }
    }
    // Menu commands arrive while AppKit is tracking NSMenu rather than during an ordinary
    // SwiftUI event cycle. Keying a view task to the request reliably resumes after the newly
    // identified Pray stack has been installed; a nested RunLoop.perform can be stranded when
    // menu tracking ends.
    .task(id: routeLandingGeneration) {
      await completePendingRouteLanding(generation: routeLandingGeneration)
    }
  }

  /// Lands a route that arrived from outside the view hierarchy — the Mac's Prayers menu, an
  /// App Intent, or a finished devotion's suggestedNext handover. Two rules, both learned from
  /// the Back button dropping people into sessions they never opened (2026-08-08): bring the
  /// Pray tab forward (the route lands on prayPath, so navigating it invisibly under another
  /// tab left ghosts), and replace the stack rather than append — "pray THIS now" must not
  /// stand on whatever leftovers the last session pushed, or Back walks down through them.
  private func land(_ route: AppRoute) {
    routeLandingGeneration += 1
    pendingLandingRoute = route
    selectedTab = .pray
    prayPath = []
  }

  private func completePendingRouteLanding(generation: Int) async {
    guard generation == routeLandingGeneration, let route = pendingLandingRoute else { return }

    // The generation has already given NavigationStack a fresh owner at root. Populate that
    // owner's entire initial route in a later SwiftUI cycle so native Back and this binding
    // begin, and remain, in lockstep.
    await Task.yield()
    guard !Task.isCancelled, generation == routeLandingGeneration,
          pendingLandingRoute == route else { return }

    prayPath = [route]
    pendingLandingRoute = nil
  }
}

private extension View {
  /// Sidebar on iPad/Mac where the OS supports it (iOS 18 / macOS 15); the classic bottom
  /// tab bar / tab control everywhere else — the deployment targets are iOS 17 / macOS 14.
  @ViewBuilder
  func adaptiveTabViewStyle() -> some View {
    if #available(iOS 18.0, macOS 15.0, visionOS 2.0, *) {
      self.tabViewStyle(.sidebarAdaptable)
    } else {
      self
    }
  }
}

#Preview {
  ContentView()
}

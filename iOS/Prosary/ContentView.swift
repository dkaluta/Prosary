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
  @State private var prayPath = NavigationPath()
  @State private var browsePath = NavigationPath()
  @State private var categoriesPath = NavigationPath()
  @State private var searchPath = NavigationPath()
  private var coordinator = NavigationCoordinator.shared
  @State private var showsBundleImporter = false
  @State private var importError: String?

  var body: some View {
    TabView {
      NavigationStack(path: $prayPath) {
        HomeView(path: $prayPath)
          .appRouteDestinations(path: $prayPath)
      }
      .tabItem {
        Label(String(localized: "tabs.pray", defaultValue: "Pray"), systemImage: "hands.and.sparkles")
      }

      NavigationStack(path: $browsePath) {
        RepositoryBrowserView(presentedAsSheet: false)
          .appRouteDestinations(path: $browsePath)
      }
      .tabItem {
        Label(String(localized: "tabs.browse", defaultValue: "Browse"), systemImage: "globe")
      }

      NavigationStack(path: $categoriesPath) {
        CategoriesView(path: $categoriesPath)
          .appRouteDestinations(path: $categoriesPath)
      }
      .tabItem {
        Label(String(localized: "tabs.categories", defaultValue: "Categories"), systemImage: "square.grid.2x2")
      }

      NavigationStack(path: $searchPath) {
        SearchTabView(path: $searchPath)
          .appRouteDestinations(path: $searchPath)
      }
      .tabItem {
        Label(String(localized: "tabs.search", defaultValue: "Search"), systemImage: "magnifyingglass")
      }
    }
    .adaptiveTabViewStyle()
    .onChange(of: coordinator.pendingRoute) { _, newValue in
      guard let newValue else { return }
      prayPath.append(newValue)
      coordinator.pendingRoute = nil
    }
    // File → Import Devotion Bundle… (menu commands run outside the view hierarchy, so the
    // importer is presented here at the root). Success lands on Favorites, where the new
    // devotion's star row is visible.
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
        prayPath.append(pending)
        coordinator.pendingRoute = nil
      }
    }
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

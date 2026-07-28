//
//  ContentView.swift
//  Prosary
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @State private var path = NavigationPath()
  private var coordinator = NavigationCoordinator.shared
  @State private var showsBundleImporter = false
  @State private var importError: String?

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
        try PrayerPackStore.installPack(fromUserSelected: url)
        path.append(AppRoute.favorites)
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
        path.append(pending)
        coordinator.pendingRoute = nil
      }
    }
  }
}

#Preview {
  ContentView()
}

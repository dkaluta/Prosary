//
//  PrayersCommands.swift
//  Prosary
//
//  macOS menu bar — stripped to essentials with a "Prayers" menu.
//  Rosary favorites appear as a submenu; each bundle devotion gets an item (or a favorites
//  submenu once favorited), followed by the Jesus Prayer.
//

#if os(macOS)
import SwiftUI

@Observable
final class PresetsMenuState {
  var prayers: [Prayer] = []

  func reload() async {
    prayers = (try? await AppServices.shared.presetStore.all()) ?? []
  }
}

struct PrayersCommands: Commands {
  @Environment(\.openWindow) private var openWindow
  var presetsState: PresetsMenuState

  var body: some Commands {
    CommandGroup(replacing: .appInfo) {
      Button("about.navigationTitle") { openWindow(id: "about") }
    }

    CommandGroup(replacing: .newItem) {}
    CommandGroup(replacing: .undoRedo) {}
    CommandGroup(replacing: .textEditing) {}
    CommandGroup(replacing: .textFormatting) {}
    CommandGroup(replacing: .toolbar) {}
    CommandGroup(replacing: .sidebar) {}
    CommandGroup(replacing: .help) {}

    CommandMenu("commands.menuTitle") {
      RosarySubmenu(prayers: presetsState.prayers)

      Divider()

      ForEach(PrayerPackStore.customDevotionIds(), id: \.self) { bundleId in
        CustomDevotionSubmenu(bundleId: bundleId, prayers: presetsState.prayers)
      }

      Menu("prayerKind.jesusPrayer") {
        let jpPrayers = presetsState.prayers
          .filter { $0.kind == .jesusPrayer }
          .sorted { $0.isDefault && !$1.isDefault }
        ForEach(jpPrayers) { prayer in
          Button(prayer.isDefault ? "\(prayer.name) ★" : prayer.name) {
            NavigationCoordinator.shared.pendingRoute = .prayer(id: prayer.id)
          }
        }
        if !jpPrayers.isEmpty { Divider() }
        Button("commands.setUpJesusPrayer") {
          NavigationCoordinator.shared.pendingRoute = .jesusPrayerSetup
        }
      }

      Divider()

      Button("commands.editFavorites") {
        NavigationCoordinator.shared.pendingRoute = .favorites
      }
    }
  }
}

private struct RosarySubmenu: View {
  let prayers: [Prayer]

  var body: some View {
    Menu("prayerKind.rosary") {
      let rosary = prayers
        .filter { $0.kind == .rosary }
        .sorted { $0.isDefault && !$1.isDefault }
      ForEach(rosary) { prayer in
        Button(prayer.isDefault ? "\(prayer.name) ★" : prayer.name) {
          NavigationCoordinator.shared.pendingRoute = .prayer(id: prayer.id)
        }
      }
    }
  }
}

/// One menu entry per generic (bundle-driven) devotion — a direct launcher until it has saved
/// favorites, then a submenu of them plus a fresh-session item.
private struct CustomDevotionSubmenu: View {
  let bundleId: String
  let prayers: [Prayer]

  var body: some View {
    let displayName = PrayerPackStore.info(for: bundleId)?.localizedDisplayName ?? bundleId
    let favorites = prayers
      .filter { $0.kind == .custom && $0.customDevotionId == bundleId }
      .sorted { $0.isDefault && !$1.isDefault }

    if favorites.isEmpty {
      Button(displayName) {
        NavigationCoordinator.shared.pendingRoute = .custom(devotionId: bundleId)
      }
    } else {
      Menu(displayName) {
        ForEach(favorites) { prayer in
          Button(prayer.isDefault ? "\(prayer.name) ★" : prayer.name) {
            NavigationCoordinator.shared.pendingRoute = .prayer(id: prayer.id)
          }
        }
        Divider()
        Button(String(localized: "commands.customNew", defaultValue: "New Session")) {
          NavigationCoordinator.shared.pendingRoute = .custom(devotionId: bundleId)
        }
      }
    }
  }
}
#endif

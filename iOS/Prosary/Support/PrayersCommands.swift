//
//  PrayersCommands.swift
//  Prosary
//
//  The menu bar, shared by macOS and iPad (iPadOS surfaces .commands in its menu bar / the
//  hardware-keyboard shortcuts HUD): a real File menu whose one item imports .prosaryprayer
//  bundles, and a "Prayers" menu — Rosary favorites as a submenu, each bundle devotion as an
//  item (or a favorites submenu once favorited), then the Jesus Prayer. The macOS-only strips
//  (About replacement, removing Edit/Format/View noise) stay gated: iPad's menu bar manages
//  its own system menus.
//

import SwiftUI

@Observable
final class PresetsMenuState {
  var prayers: [Prayer] = []

  func reload() async {
    prayers = (try? await AppServices.shared.presetStore.all()) ?? []
  }
}

struct PrayersCommands: Commands {
  #if os(macOS)
  @Environment(\.openWindow) private var openWindow
  #endif
  var presetsState: PresetsMenuState

  var body: some Commands {
    #if os(macOS)
    CommandGroup(replacing: .appInfo) {
      Button("about.navigationTitle") { openWindow(id: "about") }
    }

    CommandGroup(replacing: .undoRedo) {}
    CommandGroup(replacing: .textEditing) {}
    CommandGroup(replacing: .textFormatting) {}
    CommandGroup(replacing: .toolbar) {}
    CommandGroup(replacing: .sidebar) {}
    CommandGroup(replacing: .help) {}
    #endif

    // File — the one document-like thing this app does. Replacing .newItem both drops the
    // default New Window item and brings the File menu back (it had been stripped empty).
    CommandGroup(replacing: .newItem) {
      Button("favorites.importBundle") {
        NavigationCoordinator.shared.pendingBundleImport = true
      }
      .keyboardShortcut("o", modifiers: .command)
    }

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

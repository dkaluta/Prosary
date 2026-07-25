//
//  PrayersCommands.swift
//  Prosary
//
//  macOS menu bar — stripped to essentials with a "Prayers" menu.
//  Rosary favorites appear as a submenu; Angelus and Jesus Prayer are direct items.
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
      Button("About Prosary") { openWindow(id: "about") }
    }

    CommandGroup(replacing: .newItem) {}
    CommandGroup(replacing: .undoRedo) {}
    CommandGroup(replacing: .textEditing) {}
    CommandGroup(replacing: .textFormatting) {}
    CommandGroup(replacing: .toolbar) {}
    CommandGroup(replacing: .sidebar) {}
    CommandGroup(replacing: .help) {}

    CommandMenu("Prayers") {
      RosarySubmenu(prayers: presetsState.prayers)

      Divider()

      AngelusSubmenu(prayers: presetsState.prayers)

      Menu("Jesus Prayer") {
        let jpPrayers = presetsState.prayers
          .filter { $0.kind == .jesusPrayer }
          .sorted { $0.isDefault && !$1.isDefault }
        ForEach(jpPrayers) { prayer in
          Button(prayer.isDefault ? "\(prayer.name) ★" : prayer.name) {
            NavigationCoordinator.shared.pendingRoute = .prayer(id: prayer.id)
          }
        }
        if !jpPrayers.isEmpty { Divider() }
        Button("Set Up Jesus Prayer…") {
          NavigationCoordinator.shared.pendingRoute = .jesusPrayerSetup
        }
      }

      Divider()

      Button("Edit Favorites…") {
        NavigationCoordinator.shared.pendingRoute = .favorites
      }
    }
  }
}

private struct RosarySubmenu: View {
  let prayers: [Prayer]

  var body: some View {
    Menu("Rosary") {
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

private struct AngelusSubmenu: View {
  let prayers: [Prayer]

  var body: some View {
    let angelus = prayers
      .filter { $0.kind == .angelus }
      .sorted { $0.isDefault && !$1.isDefault }

    if angelus.isEmpty {
      Button("The Angelus") {
        NavigationCoordinator.shared.pendingRoute = .angelus
      }
    } else {
      Menu("Angelus") {
        ForEach(angelus) { prayer in
          Button(prayer.isDefault ? "\(prayer.name) ★" : prayer.name) {
            NavigationCoordinator.shared.pendingRoute = .prayer(id: prayer.id)
          }
        }
        Divider()
        Button("The Angelus (New)") {
          NavigationCoordinator.shared.pendingRoute = .angelus
        }
      }
    }
  }
}
#endif

import SwiftUI

@Observable
final class PresetsMenuState {
  var prayers: [Prayer] = []

  func reload() async {
    prayers = (try? await AppServices.shared.presetStore.all()) ?? []
  }
}

struct PrayersCommands: Commands {
  @FocusedValue(\.windowNavigation) private var navigation
  #if os(macOS)
  @Environment(\.openWindow) private var openWindow
  #endif
  var presetsState: PresetsMenuState

  var body: some Commands {
    #if os(macOS)
    CommandGroup(replacing: .appInfo) {
      Button("about.navigationTitle") { openWindow(id: "about") }
    }
    CommandGroup(replacing: .help) {
      Link(String(localized: "commands.help", defaultValue: "Prosary Help"),
           destination: URL(string: "https://prosary.app/")!)
    }
    #endif

    CommandGroup(replacing: .newItem) {
      #if os(macOS)
      Button(String(localized: "commands.newWindow", defaultValue: "New Window")) {
        openWindow(id: "main")
      }
      .keyboardShortcut("n", modifiers: .command)

      Menu(String(localized: "commands.recentlyPrayed", defaultValue: "Recently Prayed")) {
        ForEach(RecentPrayers.shared.entries) { prayer in
          Button(prayer.title) {
            Task {
              if let route = await RecentPrayers.shared.routeForOpening(id: prayer.id) {
                openWindow(id: "prayer", value: PrayerWindowRequest(route: route))
              }
            }
          }
        }
      }
      .disabled(RecentPrayers.shared.entries.isEmpty)
      Divider()
      #endif

      Button("favorites.importBundle") {
        #if os(macOS)
        if let navigation {
          navigation.importBundle()
        } else {
          MacDevotionImporter.open { id in
            openWindow(id: "prayer", value: PrayerWindowRequest(route: .custom(devotionId: id)))
          }
        }
        #else
        navigation?.importBundle()
        #endif
      }
        .keyboardShortcut("o", modifiers: .command)
        #if !os(macOS)
        .disabled(navigation == nil)
        #endif
    }

    #if os(macOS)
    CommandMenu(String(localized: "commands.navigation", defaultValue: "Go")) {
      Button(String(localized: "commands.back", defaultValue: "Back")) { navigation?.goBack() }
        .keyboardShortcut("[", modifiers: .command)
        .disabled(navigation?.canGoBack != true)
      Divider()
      ForEach(Array(AppSection.allCases.enumerated()), id: \.element) { index, section in
        Button(section.title) { navigation?.selectSection(section) }
          .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
          .disabled(navigation == nil)
      }
    }
    #endif

    CommandMenu("commands.menuTitle") {
      Group {
      Button(String(localized: "basicPrayers.title", defaultValue: "Basic Prayers")) {
        navigation?.openRoute(.basicPrayers)
      }
      RosarySubmenu(prayers: presetsState.prayers, openRoute: launch)
      Divider()
      ForEach(PrayerPackStore.customDevotionIds(), id: \.self) { bundleId in
        CustomDevotionSubmenu(bundleId: bundleId, prayers: presetsState.prayers, openRoute: launch)
      }
      Menu("prayerKind.jesusPrayer") {
        let jpPrayers = presetsState.prayers
          .filter { $0.kind == .jesusPrayer }
          .sorted { $0.isDefault && !$1.isDefault }
        ForEach(jpPrayers) { prayer in
          Button(prayer.isDefault ? "\(prayer.name) ★" : prayer.name) {
            launch(.prayer(id: prayer.id))
          }
        }
        if !jpPrayers.isEmpty { Divider() }
        Button("commands.setUpJesusPrayer") { launch(.jesusPrayerSetup) }
      }
      }
      .disabled(navigation == nil)
    }
  }

  private func launch(_ route: AppRoute) { navigation?.openRoute(route) }
}

private struct RosarySubmenu: View {
  let prayers: [Prayer]
  let openRoute: (AppRoute) -> Void

  var body: some View {
    Menu("prayerKind.rosary") {
      let rosary = prayers.filter { $0.kind == .rosary }.sorted { $0.isDefault && !$1.isDefault }
      ForEach(rosary) { prayer in
        Button(prayer.isDefault ? "\(prayer.name) ★" : prayer.name) { openRoute(.prayer(id: prayer.id)) }
      }
    }
  }
}

private struct CustomDevotionSubmenu: View {
  let bundleId: String
  let prayers: [Prayer]
  let openRoute: (AppRoute) -> Void

  var body: some View {
    let displayName = PrayerPackStore.info(for: bundleId)?.localizedDisplayName ?? bundleId
    let favorites = prayers
      .filter { $0.kind == .custom && $0.customDevotionId == bundleId }
      .sorted { $0.isDefault && !$1.isDefault }

    if favorites.isEmpty {
      Button(displayName) { openRoute(.custom(devotionId: bundleId)) }
    } else {
      Menu(displayName) {
        ForEach(favorites) { prayer in
          Button(prayer.isDefault ? "\(prayer.name) ★" : prayer.name) { openRoute(.prayer(id: prayer.id)) }
        }
        Divider()
        Button(String(localized: "commands.customNew", defaultValue: "New Session")) {
          openRoute(.custom(devotionId: bundleId))
        }
      }
    }
  }
}

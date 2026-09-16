#if os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var dockRecentIDs: [String] = []

  func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    guard AppServices.persistenceError == nil else { return nil }
    let entries = RecentPrayers.shared.entries
    Task { await RecentPrayers.shared.refresh() }
    guard !entries.isEmpty else { return nil }

    let menu = NSMenu()
    menu.autoenablesItems = false
    let heading = NSMenuItem(
      title: String(localized: "commands.recentlyPrayed", defaultValue: "Recently Prayed", bundle: UILanguage.bundle, locale: UILanguage.locale),
      action: nil, keyEquivalent: "")
    heading.isEnabled = false
    menu.addItem(heading)
    dockRecentIDs = entries.map(\.id)
    for (index, entry) in entries.enumerated() {
      let item = NSMenuItem(title: entry.title, action: #selector(openRecentPrayer(_:)), keyEquivalent: "")
      item.target = self
      item.tag = index
      menu.addItem(item)
    }
    return menu
  }

  @objc private func openRecentPrayer(_ item: NSMenuItem) {
    guard AppServices.persistenceError == nil else { return }
    guard dockRecentIDs.indices.contains(item.tag) else { return }
    let id = dockRecentIDs[item.tag]
    Task {
      if let route = await RecentPrayers.shared.routeForOpening(id: id) {
        MacPrayerWindowActions.open(route)
      }
    }
  }

  // Closing a prayer window must leave other windows (including minimized ones) alive.
  // Keeping the app running leaves File → New Window available after the last close.
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }
}
#endif

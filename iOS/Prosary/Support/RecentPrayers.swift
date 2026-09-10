import Foundation
import Observation

struct RecentPrayer: Codable, Equatable, Identifiable {
  let id: String
  let route: AppRoute
  var title: String
  let lastPrayedAt: Date
}

/// Small, device-local history. Quick Rosaries deduplicate by configuration, so a fresh
/// temporary Prayer UUID doesn't fill the Dock with repeated copies of the same session.
struct RecentPrayerStore {
  static let defaultsKey = "recentlyPrayed"
  static let maximumCount = 8
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) { self.defaults = defaults }

  var entries: [RecentPrayer] {
    guard let data = defaults.data(forKey: Self.defaultsKey),
          let decoded = try? JSONDecoder().decode([RecentPrayer].self, from: data) else { return [] }
    return Array(decoded.filter { Self.identity(for: $0.route) != nil }.prefix(Self.maximumCount))
  }

  func record(_ route: AppRoute, title: String, at date: Date = Date()) {
    guard let id = Self.identity(for: route), !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    var history = entries.filter { $0.id != id }
    history.append(RecentPrayer(id: id, route: route, title: title, lastPrayedAt: date))
    save(history.sorted { $0.lastPrayedAt > $1.lastPrayedAt })
  }

  func save(_ entries: [RecentPrayer]) {
    guard let data = try? JSONEncoder().encode(Array(entries.prefix(Self.maximumCount))) else { return }
    defaults.set(data, forKey: Self.defaultsKey)
  }

  static func identity(for route: AppRoute) -> String? {
    switch route {
    case .prayer(let id): "favorite:\(id.uuidString)"
    case .custom(let id, _, let variant): "custom:\(id):\(variant ?? "")"
    case .basicPrayer(let id): "basic:\(id)"
    case .jesusPrayer(let target): PrayerRunSignature.jesus(target)
    case .rosaryQuickPray(let prayer): "quick:\(PrayerRunSignature.rosary(prayer.rosary)):\(prayer.languageCode)"
    case .about, .rosaryPresets, .jesusPrayerSetup, .basicPrayers: nil
    }
  }
}

@MainActor
@Observable
final class RecentPrayers {
  static let shared = RecentPrayers()
  private let store: RecentPrayerStore
  private let prayerLookup: (Prayer.ID) async throws -> Prayer?
  private(set) var entries: [RecentPrayer] = []

  init(defaults: UserDefaults = ProsaryRuntimeEnvironment.defaults,
       prayerLookup: @escaping (Prayer.ID) async throws -> Prayer? = {
         try await AppServices.shared.presetStore.get(id: $0)
       }) {
    store = RecentPrayerStore(defaults: defaults)
    self.prayerLookup = prayerLookup
    entries = store.entries
  }

  func record(_ route: AppRoute) async {
    let date = Date()
    guard let title = try? await title(for: route) else { return }
    store.record(route, title: title, at: date)
    entries = store.entries
  }

  /// Refresh names and discard deleted favorites or packs. Keep entries recorded while a
  /// preset lookup was suspended, rather than overwriting them with an earlier snapshot.
  func refresh() async {
    let snapshot = store.entries
    var titles: [String: String] = [:]
    var unavailable: Set<String> = []
    for entry in snapshot {
      do { titles[entry.id] = try await title(for: entry.route) }
      catch { unavailable.insert(entry.id) }
    }
    let refreshed = store.entries.compactMap { entry -> RecentPrayer? in
      guard snapshot.contains(where: { $0.id == entry.id && $0.lastPrayedAt == entry.lastPrayedAt }) else { return entry }
      // A temporarily unavailable library is not evidence that the saved copy was deleted.
      guard !unavailable.contains(entry.id) else { return entry }
      guard let title = titles[entry.id] else { return nil }
      var updated = entry
      updated.title = title
      return updated
    }
    store.save(refreshed)
    entries = refreshed
  }

  func routeForOpening(id: String) async -> AppRoute? {
    guard let entry = entries.first(where: { $0.id == id }) else { return nil }
    do {
      guard try await title(for: entry.route) != nil else {
        await refresh()
        return nil
      }
    } catch {
      return nil
    }
    return entry.route
  }

  private func title(for route: AppRoute) async throws -> String? {
    switch route {
    case .prayer(let id):
      guard let prayer = try await prayerLookup(id) else { return nil }
      if prayer.kind == .custom {
        guard let bundle = prayer.customDevotionId, PrayerPackStore.info(for: bundle) != nil else { return nil }
      }
      return prayer.name.isEmpty ? prayer.kind.displayName : prayer.name
    case .custom(let id, _, _):
      return PrayerPackStore.info(for: id)?.localizedDisplayName
    case .basicPrayer(let id):
      guard let prayer = BasicPrayerCatalog.prayer(id: id) else { return nil }
      let language = UserDefaults.standard.string(forKey: BasicPrayerCatalog.languageDefaultsKey)
      return HebrewDisplayText.unpointed(BasicPrayerCatalog.step(for: prayer, languageCode: language).title)
    case .jesusPrayer(let target):
      if case .count(let count) = target, count <= 0 { return nil }
      return "\(PrayerKind.jesusPrayer.displayName) — \(JesusPrayerOptions(target: target).targetDisplayName)"
    case .rosaryQuickPray(let prayer):
      return "\(PrayerKind.rosary.displayName) — \(prayer.rosary.mysterySelectionSummary)"
    case .about, .rosaryPresets, .jesusPrayerSetup, .basicPrayers:
      return nil
    }
  }
}

#if os(macOS)
import AppKit

/// A SwiftUI scene installs a closure capturing its OpenWindowAction. Keeping the action here
/// lets AppKit open a prayer after every window closes; startup requests wait for installation.
@MainActor
enum MacPrayerWindowActions {
  private static var handler: ((AppRoute) -> Void)?
  private static var pendingRoutes: [AppRoute] = []

  static func install(_ action: @escaping (AppRoute) -> Void) {
    handler = action
    let pending = pendingRoutes
    pendingRoutes = []
    pending.forEach(action)
  }

  static func open(_ route: AppRoute) {
    NSApp.activate(ignoringOtherApps: true)
    if let handler { handler(route) }
    else { pendingRoutes.append(route) }
  }
}
#endif

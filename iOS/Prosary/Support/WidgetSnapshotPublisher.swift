import Combine
import Foundation
import SwiftUI
import WidgetKit

/// Publish a read-only projection. Widget extensions never share a live database context,
/// write bookmarks, or need access to downloaded prayer text and audio.
@MainActor
final class WidgetSnapshotPublisher {
  static let shared = WidgetSnapshotPublisher()
  private var subscriptions: Set<AnyCancellable> = []
  private var pending: Task<Void, Never>?

  func start() {
    guard !ProsaryRuntimeEnvironment.isTesting, subscriptions.isEmpty else { return }
    for name in [UserDefaults.didChangeNotification, .prayerLibraryDidChange,
                 .NSCalendarDayChanged, .NSSystemTimeZoneDidChange,
                 NSLocale.currentLocaleDidChangeNotification] {
      NotificationCenter.default.publisher(for: name)
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
          Task { @MainActor [weak self] in self?.schedule() }
        }
        .store(in: &subscriptions)
    }
    schedule()
  }

  private func schedule() {
    pending?.cancel()
    pending = Task { [weak self] in
      do { try await Task.sleep(for: .milliseconds(700)) }
      catch { return }
      await self?.refresh()
    }
  }

  func refresh() async {
    guard !ProsaryRuntimeEnvironment.isTesting else { return }
    // A transient store error must not replace a usable widget with an empty library.
    guard let prayers = try? await AppServices.shared.presetStore.all(), !Task.isCancelled else { return }
    let snapshot = Self.snapshot(prayers: prayers, defaults: .standard,
                                 engine: AppServices.shared.engine)
    let previous = ProsaryWidgetSnapshot.load()
    guard snapshot.today != previous.today || snapshot.prayers != previous.prayers else { return }
    guard snapshot.save() else { return }
    if snapshot.today != previous.today {
      WidgetCenter.shared.reloadTimelines(ofKind: ProsaryWidgetSnapshot.todayKind)
    }
    if snapshot.prayers != previous.prayers || snapshot.today.languageCode != previous.today.languageCode {
      WidgetCenter.shared.reloadTimelines(ofKind: ProsaryWidgetSnapshot.prayerKind)
    }
  }

  static func snapshot(prayers: [Prayer], defaults: UserDefaults, engine: PrayerEngine,
                       now: Date = Date(), language: String? = nil) -> ProsaryWidgetSnapshot {
    let today = WidgetTodaySettings(
      calendarID: defaults.string(forKey: TodayInfoStore.calendarDefaultsKey) ?? "lpj",
      easternPaschaStyle: defaults.string(forKey: TodayInfoStore.paschaStyleDefaultsKey) ?? "julian",
      languageCode: language ?? UILanguage.current,
      showFeast: defaults.object(forKey: "showTodayFeast") as? Bool ?? true,
      showIntention: defaults.object(forKey: "showTodayIntention") as? Bool ?? true,
      showTorah: defaults.object(forKey: "showTodayTorahPortion") as? Bool ?? false)
    let progressStore = PrayerRunProgressStore(defaults: defaults)
    let rows = prayers.sorted { left, right in
      if left.isDefault != right.isDefault { return left.isDefault }
      let order = left.name.localizedStandardCompare(right.name)
      return order == .orderedSame ? left.id.uuidString < right.id.uuidString : order == .orderedAscending
    }.map { WidgetPrayerProjection.make($0, progressStore: progressStore, engine: engine, now: now) }
    return ProsaryWidgetSnapshot(today: today, prayers: rows, updatedAt: now)
  }
}

/// Match the session's resume validation, including language-owned variants and novena days.
enum WidgetPrayerProjection {
  static func make(_ prayer: Prayer, progressStore: PrayerRunProgressStore,
                   engine: PrayerEngine, now: Date = Date(),
                   seriesRun: ((String) -> MultiDayRun?)? = nil) -> WidgetSavedPrayer {
    var row = WidgetSavedPrayer(id: prayer.id, name: prayer.name, kind: prayer.kind.rawValue)
    var session = prayer
    let runKey: String
    switch prayer.kind {
    case .rosary: runKey = PrayerRunKey.rosary(prayer)
    case .jesusPrayer: runKey = PrayerRunKey.jesus(prayer, target: prayer.jesusPrayer.target)
    case .custom:
      guard let bundleID = prayer.customDevotionId,
            let definition = PrayerPackStore.definition(for: bundleID) else { return row }
      #if os(macOS)
      let seriesID = PrayerCopyProgressIdentity.devotionID(bundleID, prayerID: prayer.id)
      #else
      let seriesID = bundleID
      #endif
      session.variantId = CustomDevotionLaunch.variantId(devotionId: bundleID, incoming: nil, saved: prayer.variantId)
      session.customOptions = RosaryOptions.normalizedCustomOptions(prayer.customOptions, bundleId: bundleID)
      var day = prayer.dayIndex ?? 0
      if let days = definition.days, days.count > 1, (definition.dayProgression ?? .series) == .series {
        row.progressExpiresAtMidnight = true
        let run = (seriesRun ?? MultiDayRuns.run)(seriesID)
        switch run?.resumption(dayCount: days.count, on: now) ?? .start {
        case .start: day = 0
        case .resume(let next): day = next
        case .choose(let missed, _): day = missed
        case .complete: day = days.count - 1
        }
        if let run, run.hasPrayedToday(on: now), let last = run.prayedDays.last { day = last }
      }
      session.dayIndex = day
      runKey = PrayerRunKey.custom(seriesID, variantId: session.variantId, dayIndex: day)
    }
    var continuation = progressStore.progress(for: runKey)
    #if os(macOS)
    continuation = PrayerCopyProgressIdentity.continuation(continuation, savedLanguageCode: prayer.languageCode)
    #endif
    guard let progress = continuation else { return row }
    session.languageCode = progress.languageCode
    let signature: String
    let count: Int
    switch session.kind {
    case .rosary:
      signature = PrayerRunSignature.rosary(session.rosary)
      count = engine.buildSteps(for: session).count
    case .jesusPrayer:
      signature = PrayerRunSignature.jesus(session.jesusPrayer.target)
      switch session.jesusPrayer.target {
      case .count(let target): count = target
      case .unbounded: count = Int.max
      }
    case .custom:
      guard let bundleID = session.customDevotionId else { return row }
      let language = PrayerPackStore.effectiveLanguage(for: bundleID, chosen: session.languageCode)
      let variant = PrayerPackStore.definition(for: bundleID)?.effectiveVariantId(session.variantId, languageCode: language)
      signature = PrayerRunSignature.custom(bundleID, effectiveVariantId: variant,
        dayIndex: session.dayIndex ?? 0, options: session.customOptions)
      count = engine.buildSteps(for: session).count
    }
    guard progress.canResume(stepCount: count, today: now, sameLocalDayOnly: prayer.kind == .rosary,
                             expectedConfigurationSignature: signature) else { return row }
    row.stepIndex = progress.stepIndex
    row.stepCount = count == Int.max ? nil : count
    row.progressLocalDate = row.progressExpiresAtMidnight
      ? ProsaryWidgetSnapshot.localDateKey(now) : progress.savedLocalDate
    return row
  }
}

struct WidgetSnapshotLifecycle: ViewModifier {
  @Environment(\.scenePhase) private var scenePhase

  func body(content: Content) -> some View {
    content
      .task { WidgetSnapshotPublisher.shared.start(); await WidgetSnapshotPublisher.shared.refresh() }
      .onChange(of: scenePhase) { _, _ in
        // Flush the final checkpoint when leaving a prayer, before the app is suspended.
        Task { await WidgetSnapshotPublisher.shared.refresh() }
      }
  }
}

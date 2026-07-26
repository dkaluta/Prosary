//
//  JesusPrayerFlowView.swift
//  Prosary
//
//  Unlike the Rosary/Angelus, there's no engine here building an array of steps — every
//  repetition prays the exact same fixed line, so a single synthesized RosaryStep plus a
//  JesusPrayerProgress counter is the whole model.
//

import SwiftUI

struct JesusPrayerFlowView: View {
  /// Used to pop all the way to Home when the session ends.
  @Binding var path: NavigationPath

  /// When launched from a saved favorite (via PrayerDispatchView). Provides both the
  /// target and the language. Overrides `target` when set.
  var prayer: Prayer? = nil

  /// When launched from JesusPrayerSetupView (no saved favorite). Ignored when `prayer` is set.
  var target: JesusPrayerTarget = .count(33)

  @Environment(\.appServices) private var services

  @State private var progress: JesusPrayerProgress
  @State private var isRightToLeft = false
  @State private var seasonColor = Color.clear
  @State private var languageCode: String?
  @State private var hasLoaded = false
  @State private var matchingFavoriteId: Prayer.ID? = nil

  private var effectiveTarget: JesusPrayerTarget {
    prayer?.jesusPrayer.target ?? target
  }

  init(path: Binding<NavigationPath>, prayer: Prayer? = nil, target: JesusPrayerTarget = .count(33)) {
    _path = path
    self.prayer = prayer
    self.target = target
    _progress = State(initialValue: JesusPrayerProgress(target: prayer?.jesusPrayer.target ?? target))
  }

  private var currentStep: RosaryStep? {
    guard hasLoaded else { return nil }
    return RosaryStep(
      title: PrayerKind.jesusPrayer.displayName, subtitle: nil,
      body: PrayerTranslations.get(languageCode: languageCode, key: .oratioIesu),
      imageOverrideKey: "jesus_portrait")
  }

  var body: some View {
    PrayerStepFlowView(
      navigationTitle: String(localized: "jesusPrayerFlow.title", defaultValue: "The Jesus Prayer"),
      step: currentStep,
      currentIndex: progress.currentIndex,
      totalSteps: progress.targetCount,
      seasonColor: seasonColor,
      isRightToLeft: isRightToLeft,
      languageCode: languageCode,
      canGoBack: progress.canGoBack,
      onBack: { progress.goBack() },
      onNext: next
    )
    .toolbar {
      if case .unbounded = effectiveTarget {
        ToolbarItem(placement: .confirmationAction) {
          Button("prayerFlow.finish") { returnHome() }
        }
      }
      ToolbarItem(placement: .secondaryAction) {
        Button { toggleFavorite() } label: {
          Image(systemName: matchingFavoriteId != nil ? "star.fill" : "star")
        }
        .accessibilityLabel(matchingFavoriteId != nil ? "prayerFlow.removeFromFavorites" : "prayerFlow.addToFavorites")
      }
    }
    .task { await load() }
  }

  private func load() async {
    if let prayer {
      languageCode = prayer.resolvedLanguageCode
    } else {
      let all = (try? await services.presetStore.all()) ?? []
      let defaultJP = all.first { $0.kind == .jesusPrayer && $0.isDefault }
        ?? all.first { $0.kind == .jesusPrayer }
      languageCode = defaultJP?.resolvedLanguageCode
    }

    isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
    seasonColor = services.calendar.seasonColorToday()
    hasLoaded = true
    await checkIfFavorited()
  }

  private func checkIfFavorited() async {
    let all = (try? await services.presetStore.all()) ?? []
    let resolved = languageCode ?? LanguageCatalog.defaultCode
    matchingFavoriteId = all.first {
      $0.kind == .jesusPrayer
        && $0.resolvedLanguageCode == resolved
        && $0.jesusPrayer.target == effectiveTarget
    }?.id
  }

  private func toggleFavorite() {
    Task {
      if let id = matchingFavoriteId {
        if let existing = try? await services.presetStore.get(id: id) {
          try? await services.presetStore.delete(existing)
        }
        matchingFavoriteId = nil
      } else {
        let resolved = languageCode ?? LanguageCatalog.defaultCode
        let langName = LanguageCatalog.all.first { $0.code == resolved }?.nativeName ?? resolved
        let targetLabel: String
        switch effectiveTarget {
        case .count(let n): targetLabel = "× \(n)"
        case .unbounded:    targetLabel = "Unbounded"
        }
        let all = (try? await services.presetStore.all()) ?? []
        let isFirst = !all.contains { $0.kind == .jesusPrayer }
        let newFavorite = Prayer(
          name: "Jesus Prayer \(targetLabel) (\(langName))",
          kind: .jesusPrayer,
          isDefault: isFirst,
          languageCode: resolved,
          jesusPrayer: JesusPrayerOptions(target: effectiveTarget)
        )
        try? await services.presetStore.save(newFavorite)
        matchingFavoriteId = newFavorite.id
      }
    }
  }

  private func next() {
    if progress.isLastRep { returnHome(); return }
    progress.goNext()
  }

  private func returnHome() {
    path.removeLast(path.count)
  }
}

#Preview("Bounded — 33") {
  NavigationStack {
    JesusPrayerFlowView(path: .constant(NavigationPath()), target: .count(33))
      .environment(\.appServices, AppServices(presetStore: MockPresetStore(), rosaryEngine: MockRosaryEngine(), angelusEngine: MockAngelusEngine(), stationsEngine: MockStationsEngine(), franciscanCrownEngine: MockFranciscanCrownEngine(), sevenSorrowsEngine: MockSevenSorrowsEngine(), divineMercyEngine: MockDivineMercyEngine(), calendar: MockLiturgicalCalendar()))
  }
}

#Preview("Unbounded") {
  NavigationStack {
    JesusPrayerFlowView(path: .constant(NavigationPath()), target: .unbounded)
      .environment(\.appServices, AppServices(presetStore: MockPresetStore(), rosaryEngine: MockRosaryEngine(), angelusEngine: MockAngelusEngine(), stationsEngine: MockStationsEngine(), franciscanCrownEngine: MockFranciscanCrownEngine(), sevenSorrowsEngine: MockSevenSorrowsEngine(), divineMercyEngine: MockDivineMercyEngine(), calendar: MockLiturgicalCalendar()))
  }
}

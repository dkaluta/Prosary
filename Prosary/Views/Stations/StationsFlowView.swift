//
//  StationsFlowView.swift
//  Prosary
//

import SwiftUI

struct StationsFlowView: View {
  /// If provided (launched from Favorites), use this prayer's language and track it for the
  /// star button. If nil (launched from Home with no Stations favorite), use the app default.
  var prayer: Prayer? = nil

  @Environment(\.appServices) private var services
  @Environment(\.dismiss) private var dismiss

  @State private var steps: [RosaryStep] = []
  @State private var currentIndex = 0
  @State private var isRightToLeft = false
  @State private var seasonColor = Color.clear
  @State private var languageCode: String?
  @State private var matchingFavoriteId: Prayer.ID? = nil

  private var currentStep: RosaryStep? {
    steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
  }

  var body: some View {
    PrayerStepFlowView(
      navigationTitle: String(localized: "stationsFlow.title", defaultValue: "Stations of the Cross"),
      step: currentStep,
      currentIndex: currentIndex,
      totalSteps: steps.count,
      seasonColor: seasonColor,
      isRightToLeft: isRightToLeft,
      languageCode: languageCode,
      canGoBack: currentIndex > 0,
      onBack: back,
      onNext: next
    )
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
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
      let defaultStations = all.first { $0.kind == .stationsOfTheCross && $0.isDefault }
        ?? all.first { $0.kind == .stationsOfTheCross }
      languageCode = defaultStations?.resolvedLanguageCode
    }

    isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
    steps = services.engine.buildSteps(for: Prayer(kind: .stationsOfTheCross, languageCode: languageCode ?? LanguageCatalog.defaultSentinel))
    currentIndex = 0
    seasonColor = services.calendar.seasonColorToday()
    await checkIfFavorited()
  }

  private func checkIfFavorited() async {
    let all = (try? await services.presetStore.all()) ?? []
    let resolved = languageCode ?? LanguageCatalog.defaultCode
    matchingFavoriteId = all.first {
      $0.kind == .stationsOfTheCross && $0.resolvedLanguageCode == resolved
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
        let all = (try? await services.presetStore.all()) ?? []
        let isFirst = !all.contains { $0.kind == .stationsOfTheCross }
        let newFavorite = Prayer(
          name: "Stations of the Cross (\(langName))",
          kind: .stationsOfTheCross,
          isDefault: isFirst,
          languageCode: resolved
        )
        try? await services.presetStore.save(newFavorite)
        matchingFavoriteId = newFavorite.id
      }
    }
  }

  private func next() {
    if currentIndex >= steps.count - 1 { dismiss(); return }
    currentIndex += 1
  }

  private func back() {
    guard currentIndex > 0 else { return }
    currentIndex -= 1
  }
}

#Preview {
  let store = MockPresetStore()
  return NavigationStack {
    StationsFlowView()
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
}

#Preview("Hebrew — RTL") {
  let prayer = Prayer(name: "Hebrew", kind: .stationsOfTheCross, isDefault: true, languageCode: "he")
  let store = MockPresetStore(configs: [prayer])
  return NavigationStack {
    StationsFlowView(prayer: prayer)
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
}

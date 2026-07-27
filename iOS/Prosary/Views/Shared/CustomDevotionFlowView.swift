//
//  CustomDevotionFlowView.swift
//  Prosary
//
//  The single flow view for every PrayerKind.custom devotion (currently just Trisagion) —
//  mirrors AngelusFlowView/StationsFlowView's shape exactly, but reads its title/steps from
//  PrayerPackStore/PrayerEngine instead of a per-devotion hardcoded builder, so a new generic
//  devotion needs no new View at all.
//

import SwiftUI

struct CustomDevotionFlowView: View {
  let devotionId: String
  /// If provided (launched from Favorites with an existing favorite), used directly instead of
  /// re-querying the store — same convention as AngelusFlowView.
  var prayer: Prayer? = nil

  @Environment(\.appServices) private var services
  @Environment(\.dismiss) private var dismiss

  @State private var steps: [RosaryStep] = []
  @State private var currentIndex = 0
  @State private var isRightToLeft = false
  @State private var languageCode: String?
  @State private var matchingFavoriteId: Prayer.ID? = nil
  @State private var displayName: String = ""

  private var currentStep: RosaryStep? {
    steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
  }

  var body: some View {
    PrayerStepFlowView(
      navigationTitle: displayName,
      step: currentStep,
      currentIndex: currentIndex,
      totalSteps: steps.count,
      seasonColor: .clear,
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
    displayName = PrayerPackStore.info(for: devotionId)?.displayName ?? devotionId

    let all = (try? await services.presetStore.all()) ?? []
    let favorite = prayer ?? all.first { $0.kind == .custom && $0.customDevotionId == devotionId }
    matchingFavoriteId = favorite?.id
    languageCode = favorite?.resolvedLanguageCode ?? LanguageCatalog.resolve(LanguageCatalog.defaultSentinel).code

    isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
    steps = services.engine.buildSteps(for: Prayer(
      kind: .custom, languageCode: languageCode ?? LanguageCatalog.defaultSentinel, customDevotionId: devotionId))
    currentIndex = 0
  }

  private func toggleFavorite() {
    Task {
      if let id = matchingFavoriteId {
        if let existing = try? await services.presetStore.get(id: id) {
          try? await services.presetStore.delete(existing)
        }
        matchingFavoriteId = nil
      } else {
        let newFavorite = Prayer(
          name: displayName,
          kind: .custom,
          isDefault: true,
          languageCode: LanguageCatalog.defaultSentinel,
          customDevotionId: devotionId
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
    CustomDevotionFlowView(devotionId: "trisagion")
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
}

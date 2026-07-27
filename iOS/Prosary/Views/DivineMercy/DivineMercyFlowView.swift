//
//  DivineMercyFlowView.swift
//  Prosary
//
//  Combines AngelusFlowView's "launchable with no saved favorite" pattern (no options beyond
//  language, so there's nothing to configure before starting) with RosaryFlowView's bead-track
//  accessory (the Divine Mercy Chaplet is decade-based, unlike the Angelus/Stations of the
//  Cross) — the same combination FranciscanCrownFlowView/SevenSorrowsFlowView use.
//

import SwiftUI

struct DivineMercyFlowView: View {
  /// If provided (launched from Home/Favorites with an existing favorite), used directly instead
  /// of re-querying the store. The Divine Mercy Chaplet has no UI to configure a per-favorite
  /// language anymore (see FavoritesListView), but an existing favorite's saved language is still
  /// honored — only a freshly-created favorite (or no favorite at all) follows the app default.
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

  private var beadLayout: BeadLayout {
    BeadLayout.build(steps: steps, currentIndex: currentIndex, hasClosingCross: true)
  }

  private func beadColumnAreaWidth(hasRoomForSingleMinorColumn: Bool) -> CGFloat {
    let majorColumns = CGFloat(max(beadLayout.groupColumns.count, 1)) * 34 + 40
    guard beadLayout.showBottomBeads else { return majorColumns }
    return majorColumns + (hasRoomForSingleMinorColumn ? 44 : 74)
  }

  var body: some View {
    PrayerStepFlowView(
      navigationTitle: String(localized: "divineMercyFlow.title", defaultValue: "Divine Mercy Chaplet"),
      step: currentStep,
      currentIndex: currentIndex,
      totalSteps: steps.count,
      seasonColor: seasonColor,
      isRightToLeft: isRightToLeft,
      languageCode: languageCode,
      canGoBack: currentIndex > 0,
      onBack: back,
      onNext: next,
      accessory: { isWide, hasRoomForSingleMinorColumn in
        AnyView(
          BeadProgressView(layout: beadLayout, isWide: isWide,
                           hasRoomForSingleMinorColumn: hasRoomForSingleMinorColumn)
            .frame(width: beadColumnAreaWidth(hasRoomForSingleMinorColumn: hasRoomForSingleMinorColumn))
        )
      }
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
    let all = (try? await services.presetStore.all()) ?? []
    let favorite = prayer ?? all.first { $0.kind == .divineMercyChaplet }
    matchingFavoriteId = favorite?.id
    languageCode = favorite?.resolvedLanguageCode ?? LanguageCatalog.resolve(LanguageCatalog.defaultSentinel).code

    isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
    steps = services.engine.buildSteps(for: Prayer(kind: .divineMercyChaplet, languageCode: languageCode ?? LanguageCatalog.defaultSentinel))
    currentIndex = 0
    seasonColor = services.calendar.seasonColorToday()
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
          name: PrayerKind.divineMercyChaplet.defaultName,
          kind: .divineMercyChaplet,
          isDefault: true,
          languageCode: LanguageCatalog.defaultSentinel
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
    DivineMercyFlowView()
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
}

#Preview("Wide (Mac/iPad)") {
  let store = MockPresetStore()
  return NavigationStack {
    DivineMercyFlowView()
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
  .environment(\.horizontalSizeClass, .regular)
  .frame(width: 900, height: 600)
}

#Preview("Hebrew — RTL") {
  let prayer = Prayer(name: "Hebrew", kind: .divineMercyChaplet, isDefault: true, languageCode: "he")
  let store = MockPresetStore(configs: [prayer])
  return NavigationStack {
    DivineMercyFlowView(prayer: prayer)
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
}

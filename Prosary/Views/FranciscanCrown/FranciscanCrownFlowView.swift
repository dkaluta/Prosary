//
//  FranciscanCrownFlowView.swift
//  Prosary
//
//  Combines AngelusFlowView's "launchable with no saved favorite" pattern (no options beyond
//  language, so there's nothing to configure before starting) with RosaryFlowView's bead-track
//  accessory (the Franciscan Crown is decade-based, unlike the Angelus/Stations of the Cross).
//

import SwiftUI

struct FranciscanCrownFlowView: View {
  /// If provided (launched from Home/Favorites with an existing favorite), seeds the star as
  /// already-favorited immediately, without waiting on the initial favorites fetch. The
  /// Franciscan Crown has no per-favorite language anymore — it always follows the app default.
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
      navigationTitle: String(localized: "franciscanCrownFlow.title", defaultValue: "Franciscan Crown"),
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
    matchingFavoriteId = prayer?.id
    languageCode = LanguageCatalog.resolve(LanguageCatalog.defaultSentinel).code

    isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
    steps = services.engine.buildSteps(for: Prayer(kind: .franciscanCrown, languageCode: LanguageCatalog.defaultSentinel))
    currentIndex = 0
    seasonColor = services.calendar.seasonColorToday()
    await checkIfFavorited()
  }

  private func checkIfFavorited() async {
    let all = (try? await services.presetStore.all()) ?? []
    matchingFavoriteId = all.first { $0.kind == .franciscanCrown }?.id
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
          name: PrayerKind.franciscanCrown.defaultName,
          kind: .franciscanCrown,
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
    FranciscanCrownFlowView()
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
}

#Preview("Wide (Mac/iPad)") {
  let store = MockPresetStore()
  return NavigationStack {
    FranciscanCrownFlowView()
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
  .environment(\.horizontalSizeClass, .regular)
  .frame(width: 900, height: 600)
}

#Preview("Hebrew — RTL") {
  let prayer = Prayer(name: "Hebrew", kind: .franciscanCrown, isDefault: true, languageCode: "he")
  let store = MockPresetStore(configs: [prayer])
  return NavigationStack {
    FranciscanCrownFlowView(prayer: prayer)
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
}

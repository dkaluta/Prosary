//
//  SevenSorrowsFlowView.swift
//  Prosary
//
//  Combines AngelusFlowView's "launchable with no saved favorite" pattern (no options beyond
//  language, so there's nothing to configure before starting) with RosaryFlowView's bead-track
//  accessory (the Seven Sorrows is decade-based, unlike the Angelus/Stations of the Cross) — the
//  same combination FranciscanCrownFlowView uses.
//

import SwiftUI

struct SevenSorrowsFlowView: View {
  /// If provided (launched from Favorites), use this prayer's language and track it for the
  /// star button. If nil (launched from Home with no Seven Sorrows favorite), use the app
  /// default language.
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
      navigationTitle: String(localized: "sevenSorrowsFlow.title", defaultValue: "Seven Sorrows"),
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
    if let prayer {
      languageCode = prayer.resolvedLanguageCode
    } else {
      let all = (try? await services.presetStore.all()) ?? []
      let defaultSevenSorrows = all.first { $0.kind == .sevenSorrows && $0.isDefault }
        ?? all.first { $0.kind == .sevenSorrows }
      languageCode = defaultSevenSorrows?.resolvedLanguageCode
    }

    isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
    steps = services.engine.buildSteps(for: Prayer(kind: .sevenSorrows, languageCode: languageCode ?? LanguageCatalog.defaultSentinel))
    currentIndex = 0
    seasonColor = services.calendar.seasonColorToday()
    await checkIfFavorited()
  }

  private func checkIfFavorited() async {
    let all = (try? await services.presetStore.all()) ?? []
    let resolved = languageCode ?? LanguageCatalog.defaultCode
    matchingFavoriteId = all.first {
      $0.kind == .sevenSorrows && $0.resolvedLanguageCode == resolved
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
        let isFirst = !all.contains { $0.kind == .sevenSorrows }
        let newFavorite = Prayer(
          name: "Seven Sorrows (\(langName))",
          kind: .sevenSorrows,
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
    SevenSorrowsFlowView()
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
}

#Preview("Wide (Mac/iPad)") {
  let store = MockPresetStore()
  return NavigationStack {
    SevenSorrowsFlowView()
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
  .environment(\.horizontalSizeClass, .regular)
  .frame(width: 900, height: 600)
}

#Preview("Hebrew — RTL") {
  let prayer = Prayer(name: "Hebrew", kind: .sevenSorrows, isDefault: true, languageCode: "he")
  let store = MockPresetStore(configs: [prayer])
  return NavigationStack {
    SevenSorrowsFlowView(prayer: prayer)
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
}

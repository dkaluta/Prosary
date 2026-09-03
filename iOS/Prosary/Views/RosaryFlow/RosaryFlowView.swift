//
//  RosaryFlowView.swift
//  Prosary
//

import SwiftUI

struct RosaryFlowView: View {
  let prayer: Prayer

  @Environment(\.appServices) private var services
  @Environment(\.dismiss) private var dismiss

  @State private var steps: [RosaryStep] = []
  @State private var currentIndex = 0
  @State private var isRightToLeft = false
  @State private var seasonColor = Color.clear
  @State private var sessionPrayer: Prayer
  @State private var pendingContinuation: PrayerRunProgress?
  @State private var hasLoaded = false
  @State private var didFinish = false

  private let progressStore = PrayerRunProgressStore()

  init(prayer: Prayer) {
    self.prayer = prayer
    _sessionPrayer = State(initialValue: prayer)
  }

  private var currentStep: RosaryStep? {
    steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
  }

  private var beadLayout: BeadLayout {
    BeadLayout.build(steps: steps, currentIndex: currentIndex,
                     hasClosingCross: sessionPrayer.rosary.includeFinalSignOfCross)
  }

  private var previousMysteryIndex: Int? {
    RosaryMysteryNavigation.previousIndex(in: steps, from: currentIndex)
  }

  private var nextMysteryIndex: Int? {
    RosaryMysteryNavigation.nextIndex(in: steps, from: currentIndex)
  }

  private func beadColumnAreaWidth(hasRoomForSingleMinorColumn: Bool) -> CGFloat {
    let majorColumns = CGFloat(max(beadLayout.groupColumns.count, 1)) * 34 + 40
    guard beadLayout.showBottomBeads else { return majorColumns }
    return majorColumns + (hasRoomForSingleMinorColumn ? 44 : 74)
  }

  var body: some View {
    PrayerStepFlowView(
      navigationTitle: String(localized: "rosaryFlow.navigationTitle", defaultValue: "Praying the Rosary"),
      step: currentStep,
      currentIndex: currentIndex,
      totalSteps: steps.count,
      seasonColor: seasonColor,
      isRightToLeft: isRightToLeft,
      languageCode: sessionPrayer.resolvedLanguageCode,
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
      ToolbarItemGroup(placement: .primaryAction) {
        Button { jump(to: previousMysteryIndex) } label: {
          Image(systemName: "backward.end.fill")
        }
        .disabled(previousMysteryIndex == nil)
        .accessibilityLabel(String(localized: "rosaryFlow.previousMystery", defaultValue: "Previous mystery"))
        .accessibilityIdentifier("previousMysteryButton")

        Button { jump(to: nextMysteryIndex) } label: {
          Image(systemName: "forward.end.fill")
        }
        .disabled(nextMysteryIndex == nil)
        .accessibilityLabel(String(localized: "rosaryFlow.nextMystery", defaultValue: "Next mystery"))
        .accessibilityIdentifier("nextMysteryButton")

        if let languages = PrayerPackStore.info(for: "rosary")?.languages,
           languages.count > 1 || languages.contains("he") {
          Menu {
            languageButton(
              raw: LanguageCatalog.defaultSentinel,
              name: String(localized: "prayerFlow.language.appDefault", defaultValue: "App setting"))
            Divider()
            ForEach(LanguageCatalog.availableOptions(for: languages)) { option in
              languageButton(raw: option.code, name: option.nativeName)
            }
          } label: {
            Image(systemName: "globe")
          }
          .accessibilityLabel(String(localized: "prayerFlow.language", defaultValue: "Prayer language"))
          .accessibilityIdentifier("languageMenu")
        }
      }
    }
    .alert(
      String(localized: "prayerFlow.continue.title", defaultValue: "Continue this prayer?"),
      isPresented: .init(
        get: { pendingContinuation != nil },
        set: { if !$0 { pendingContinuation = nil } }),
      presenting: pendingContinuation
    ) { progress in
      Button(String(localized: "prayerFlow.continue", defaultValue: "Continue")) {
        resume(progress)
      }
      Button(String(localized: "prayerFlow.restart", defaultValue: "Restart"), role: .destructive) {
        restart()
      }
    } message: { _ in
      Text(String(localized: "prayerFlow.continue.message",
                  defaultValue: "You have an unfinished prayer. Continue where you left off or begin again?"))
    }
    .task { await load() }
    .onDisappear {
      guard hasLoaded, pendingContinuation == nil, !didFinish else { return }
      persistProgress()
    }
  }

  private func load() async {
    sessionPrayer = prayer
    isRightToLeft = LanguageCatalog.resolve(sessionPrayer.languageCode).isRightToLeft
    steps = services.engine.buildSteps(for: sessionPrayer)
    currentIndex = 0
    seasonColor = services.calendar.seasonColorToday()
    hasLoaded = true

    let runKey = PrayerRunKey.rosary(prayer)
    if let progress = progressStore.progress(for: runKey),
       progress.canResume(
        stepCount: steps.count,
        sameLocalDayOnly: true,
        expectedConfigurationSignature: PrayerRunSignature.rosary(sessionPrayer.rosary)) {
      sessionPrayer.languageCode = progress.languageCode
      isRightToLeft = LanguageCatalog.resolve(progress.languageCode).isRightToLeft
      steps = services.engine.buildSteps(for: sessionPrayer)
      pendingContinuation = progress
    } else {
      progressStore.clear(runKey: runKey)
    }
  }

  private func next() {
    if currentIndex >= steps.count - 1 {
      didFinish = true
      progressStore.clear(runKey: PrayerRunKey.rosary(prayer))
      dismiss()
      return
    }
    currentIndex += 1
    persistProgress()
  }

  private func back() {
    guard currentIndex > 0 else { return }
    currentIndex -= 1
    persistProgress()
  }

  private func jump(to index: Int?) {
    guard let index, steps.indices.contains(index) else { return }
    currentIndex = index
    persistProgress()
  }

  @ViewBuilder
  private func languageButton(raw: String, name: String) -> some View {
    Button { switchLanguage(to: raw) } label: {
      if raw == sessionPrayer.languageCode {
        Label(name, systemImage: "checkmark")
      } else {
        Text(name)
      }
    }
  }

  /// Rebuild only the text, retaining the exact mystery/bead index. The preset remembers the
  /// raw picker choice, and the run bookmark records that same choice for Continue.
  private func switchLanguage(to raw: String) {
    let position = currentIndex
    sessionPrayer.languageCode = raw
    isRightToLeft = LanguageCatalog.resolve(raw).isRightToLeft
    steps = services.engine.buildSteps(for: sessionPrayer)
    currentIndex = min(position, max(steps.count - 1, 0))
    persistProgress()

    Task {
      guard var favorite = try? await services.presetStore.get(id: prayer.id) else { return }
      favorite.languageCode = raw
      try? await services.presetStore.save(favorite)
    }
  }

  private func resume(_ progress: PrayerRunProgress) {
    pendingContinuation = nil
    sessionPrayer.languageCode = progress.languageCode
    isRightToLeft = LanguageCatalog.resolve(progress.languageCode).isRightToLeft
    steps = services.engine.buildSteps(for: sessionPrayer)
    currentIndex = min(progress.stepIndex, max(steps.count - 1, 0))
    persistProgress()
  }

  private func restart() {
    pendingContinuation = nil
    currentIndex = 0
    progressStore.clear(runKey: PrayerRunKey.rosary(prayer))
  }

  private func persistProgress() {
    progressStore.save(
      runKey: PrayerRunKey.rosary(prayer),
      stepIndex: currentIndex,
      languageCode: sessionPrayer.languageCode,
      configurationSignature: PrayerRunSignature.rosary(sessionPrayer.rosary))
  }
}

#Preview("iPhone") {
  let prayer = Prayer(rosary: RosaryOptions(mysterySelectionMode: .todaysMysteries))
  let store = MockPresetStore(configs: [prayer])
  return NavigationStack {
    RosaryFlowView(prayer: prayer)
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
}

#Preview("Wide (Mac/iPad)") {
  let prayer = Prayer(rosary: RosaryOptions(mysterySelectionMode: .twentyMystery))
  let store = MockPresetStore(configs: [prayer])
  return NavigationStack {
    RosaryFlowView(prayer: prayer)
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
  .environment(\.horizontalSizeClass, .regular)
  .frame(width: 900, height: 600)
}

#Preview("Hebrew — RTL") {
  let prayer = Prayer(languageCode: "he", rosary: RosaryOptions(mysterySelectionMode: .specific, specificMysteryGroup: .glorious))
  let store = MockPresetStore(configs: [prayer])
  return NavigationStack {
    RosaryFlowView(prayer: prayer)
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
}

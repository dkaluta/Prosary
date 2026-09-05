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
  @Binding var path: [AppRoute]

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
  @State private var chosenLanguage = LanguageCatalog.defaultSentinel
  @State private var hasLoaded = false
  @State private var matchingFavoriteId: Prayer.ID? = nil
  @State private var pendingContinuation: PrayerRunProgress?
  @State private var didFinish = false

  private let progressStore = PrayerRunProgressStore()

  private var effectiveTarget: JesusPrayerTarget {
    prayer?.jesusPrayer.target ?? target
  }

  init(path: Binding<[AppRoute]>, prayer: Prayer? = nil, target: JesusPrayerTarget = .count(33)) {
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
      imageOverrideKey: "christ_pantocrator")
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
      onBack: back,
      onNext: next,
      centralActionLabel: String(localized: "jesusPrayerFlow.pray", defaultValue: "Pray"),
      flowActions: AnyView(flowActions)
    )
    .alert(
      String(localized: "prayerFlow.continue.title", defaultValue: "Continue this prayer?"),
      isPresented: .init(
        get: { pendingContinuation != nil },
        set: { if !$0 { pendingContinuation = nil } }),
      presenting: pendingContinuation
    ) { saved in
      Button(String(localized: "prayerFlow.continue", defaultValue: "Continue")) {
        resume(saved)
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

  @ViewBuilder
  private var flowActions: some View {
    if case .unbounded = effectiveTarget {
      Button("prayerFlow.finish") { finish() }
    }
    Button { toggleFavorite() } label: {
      Image(systemName: matchingFavoriteId != nil ? "star.fill" : "star")
    }
    .accessibilityLabel(matchingFavoriteId != nil ? "prayerFlow.removeFromFavorites" : "prayerFlow.addToFavorites")
  }

  private func load() async {
    let configuredLanguage: String
    if let prayer {
      configuredLanguage = prayer.languageCode
    } else {
      let all = (try? await services.presetStore.all()) ?? []
      let defaultJP = all.first { $0.kind == .jesusPrayer && $0.isDefault }
        ?? all.first { $0.kind == .jesusPrayer }
      // No favorite yet: the app-level default language, never a silent Latin fallback.
      configuredLanguage = defaultJP?.languageCode ?? LanguageCatalog.defaultSentinel
    }

    chosenLanguage = configuredLanguage
    languageCode = LanguageCatalog.resolve(configuredLanguage).code

    isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
    seasonColor = services.calendar.seasonColorToday()
    hasLoaded = true
    await checkIfFavorited()

    if let saved = progressStore.progress(for: runKey),
       saved.canResume(
        stepCount: progress.targetCount ?? Int.max,
        expectedConfigurationSignature: PrayerRunSignature.jesus(effectiveTarget)) {
      chosenLanguage = saved.languageCode
      languageCode = LanguageCatalog.resolve(saved.languageCode).code
      isRightToLeft = LanguageCatalog.resolve(saved.languageCode).isRightToLeft
      pendingContinuation = saved
    } else {
      progressStore.clear(runKey: runKey)
    }
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
        case .unbounded:    targetLabel = String(localized: "jesusPrayerOptions.unbounded", defaultValue: "Unbounded")
        }
        let all = (try? await services.presetStore.all()) ?? []
        let isFirst = !all.contains { $0.kind == .jesusPrayer }
        let newFavorite = Prayer(
          name: String(localized: "jesusPrayer.favoriteName", defaultValue: "Jesus Prayer \(targetLabel) (\(langName))"),
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
    if progress.isLastRep { finish(); return }
    progress.goNext()
    persistProgress()
  }

  private func back() {
    progress.goBack()
    persistProgress()
  }

  private var runKey: String {
    PrayerRunKey.jesus(prayer, target: effectiveTarget)
  }

  private func resume(_ saved: PrayerRunProgress) {
    pendingContinuation = nil
    chosenLanguage = saved.languageCode
    languageCode = LanguageCatalog.resolve(saved.languageCode).code
    isRightToLeft = LanguageCatalog.resolve(saved.languageCode).isRightToLeft
    progress.currentIndex = saved.stepIndex
    persistProgress()
  }

  private func restart() {
    pendingContinuation = nil
    progress = JesusPrayerProgress(target: effectiveTarget)
    progressStore.clear(runKey: runKey)
  }

  private func persistProgress() {
    progressStore.save(
      runKey: runKey,
      stepIndex: progress.currentIndex,
      languageCode: chosenLanguage,
      configurationSignature: PrayerRunSignature.jesus(effectiveTarget))
  }

  private func finish() {
    didFinish = true
    progressStore.clear(runKey: runKey)
    returnHome()
  }

  private func returnHome() {
    path.removeLast(path.count)
  }
}

#Preview("Bounded — 33") {
  NavigationStack {
    JesusPrayerFlowView(path: .constant([]), target: .count(33))
      .environment(\.appServices, AppServices(presetStore: MockPresetStore(), engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
}

#Preview("Unbounded") {
  NavigationStack {
    JesusPrayerFlowView(path: .constant([]), target: .unbounded)
      .environment(\.appServices, AppServices(presetStore: MockPresetStore(), engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
}

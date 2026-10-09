//
//  RosaryFlowView.swift
//  Prosary
//

import SwiftUI

struct RosaryFlowView: View {
  let prayer: Prayer

  @Environment(\.appServices) private var services
  @Environment(\.dismiss) private var dismiss
  @Environment(\.finishPrayerSession) private var finishPrayerSession
  @Environment(\.prayerWindowTitle) private var prayerWindowTitle
  @Environment(\.prayerWindowIsModal) private var parentWindowIsModal
  @ObservedObject private var prayerLanguage = PrayerLanguageMonitor.shared

  @State private var steps: [RosaryStep] = []
  @State private var currentIndex = 0
  @State private var isRightToLeft = false
  @State private var seasonColor = Color.clear
  @State private var sessionPrayer: Prayer
  @State private var pendingContinuation: PrayerRunProgress?
  @State private var hasLoaded = false
  @State private var sessionLoader = PrayerSessionLoader()
  @State private var didFinish = false
  @State private var showsMysteryPicker = false
  @State private var pickerGroup: MysteryGroup?
  @State private var navigationGroup: String?
  @State private var navigationOrder: Int?
  private var requiresMysteryChoice: Bool { prayer.rosary.mysterySelectionMode == .chooseOnLaunch && navigationGroup == nil }
  private var mysteryPickerActionTitle: String {
    let title = String(localized: "flow.chooseMystery", defaultValue: "Choose Mystery", bundle: UILanguage.bundle, locale: UILanguage.locale)
    #if os(macOS)
    return title + "…"
    #else
    return title
    #endif
  }

  @Environment(\.prayerProgressNamespace) private var progressNamespace
  private var progressStore: PrayerRunProgressStore { PrayerRunProgressStore(namespace: progressNamespace) }

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
    // Reserve the session's minor track even on announcement steps, so advancing doesn't
    // change columns when a window is close to the wide-layout threshold.
    guard steps.contains(where: { $0.hailMaryIndexInDecade != nil }) else { return majorColumns }
    return majorColumns + (hasRoomForSingleMinorColumn ? 44 : 74)
  }

  var body: some View {
    PrayerStepFlowView(
      navigationTitle: prayerWindowTitle ?? String(localized: "rosaryFlow.navigationTitle", defaultValue: "Praying the Rosary", bundle: UILanguage.bundle, locale: UILanguage.locale),
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
            .frame(width: isWide ? beadColumnAreaWidth(hasRoomForSingleMinorColumn: hasRoomForSingleMinorColumn) : nil)
        )
      },
      accessoryWidth: { beadColumnAreaWidth(hasRoomForSingleMinorColumn: $0) },
      flowActions: AnyView(flowActions)
    )
    .alert(
      String(localized: "prayerFlow.continue.title", defaultValue: "Continue this prayer?", bundle: UILanguage.bundle, locale: UILanguage.locale),
      isPresented: .init(
        get: { pendingContinuation != nil },
        set: { if !$0 { pendingContinuation = nil } }),
      presenting: pendingContinuation
    ) { progress in
      Button(String(localized: "prayerFlow.continue", defaultValue: "Continue", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
        resume(progress)
      }
      .keyboardShortcut(.defaultAction)
      Button(String(localized: "prayerFlow.restart", defaultValue: "Restart", bundle: UILanguage.bundle, locale: UILanguage.locale), role: .destructive) {
        restart()
      }
    } message: { _ in
      Text(String(localized: "prayerFlow.continue.message",
                  defaultValue: "You have an unfinished prayer. Continue where you left off or begin again?", bundle: UILanguage.bundle, locale: UILanguage.locale))
    }
    .environment(\.prayerWindowIsModal, parentWindowIsModal || showsMysteryPicker || pendingContinuation != nil)
    .task { await sessionLoader.perform { await load() } }
    .sheet(isPresented: $showsMysteryPicker) {
      NavigationStack {
        List {
          Picker(String(localized: "flow.mysterySet", defaultValue: "Mystery Set", bundle: UILanguage.bundle, locale: UILanguage.locale), selection: $pickerGroup) {
            Text(verbatim: "—").tag(Optional<MysteryGroup>.none)
            ForEach(MysteryGroup.allCases) { group in Text(group.displayName).tag(Optional(group)) }
          }
          .accessibilityIdentifier("mysterySetSelector")
          if let group = pickerGroup {
            Button(String(localized: "flow.entireSet", defaultValue: "Entire Set", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
              chooseEntireSet(group)
            }
            .accessibilityIdentifier("chooseMystery.entireSet")
            ForEach(MysteryCatalog.forGroup(group)) { mystery in
              Button(HebrewDisplayText.unpointed(MysteryTranslations.get(
                languageCode: UILanguage.current, imageKey: mystery.imageKey).title)) { chooseMystery(mystery) }
                .accessibilityIdentifier("chooseMystery.\(group.rawValue).\(mystery.order)")
            }
          }
        }
        .accessibilityIdentifier("mysteryPickerList")
        .navigationTitle(String(localized: "flow.chooseMystery", defaultValue: "Choose Mystery", bundle: UILanguage.bundle, locale: UILanguage.locale))
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "common.cancel", defaultValue: "Cancel", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
              showsMysteryPicker = false
              if requiresMysteryChoice { finishSession() }
            }
            #if os(macOS)
            .keyboardShortcut(.cancelAction)
            #endif
          }
        }
      }
      #if os(macOS)
      .frame(minWidth: 480, minHeight: 560)
      #endif
      .interactiveDismissDisabled(requiresMysteryChoice)
    }
    .onChange(of: prayerLanguage.code) { _, _ in
      guard hasLoaded, !didFinish, sessionPrayer.languageCode.isEmpty else { return }
      isRightToLeft = LanguageCatalog.resolve(sessionPrayer.languageCode).isRightToLeft
      steps = services.engine.buildSteps(for: sessionPrayer)
      currentIndex = min(currentIndex, max(steps.count - 1, 0))
    }
    .onDisappear {
      guard hasLoaded, pendingContinuation == nil, !didFinish else { return }
      persistProgress()
    }
  }

  @ViewBuilder
  private var flowActions: some View {
    Button { pickerGroup = nil; showsMysteryPicker = true } label: {
      Label(mysteryPickerActionTitle, systemImage: "list.bullet")
    }
    #if !os(macOS)
    .labelStyle(.iconOnly)
    #endif
    .prayerControlTouchTarget()
    .accessibilityIdentifier("chooseMysteryButton")
    Button { jump(to: previousMysteryIndex) } label: {
      Label {
        Text(String(localized: "rosaryFlow.previousMystery", defaultValue: "Previous Mystery", bundle: UILanguage.bundle, locale: UILanguage.locale))
      } icon: {
        Image(systemName: "backward.end.fill")
          .prayerControlSymbolFont()
          .flipsForRightToLeftLayoutDirection(true)
      }
    }
    #if !os(macOS)
    .labelStyle(.iconOnly)
    #endif
    .disabled(previousMysteryIndex == nil)
    .accessibilityLabel(String(localized: "rosaryFlow.previousMystery", defaultValue: "Previous Mystery", bundle: UILanguage.bundle, locale: UILanguage.locale))
    .help(String(localized: "rosaryFlow.previousMystery", defaultValue: "Previous Mystery", bundle: UILanguage.bundle, locale: UILanguage.locale))
    .prayerControlTouchTarget()
    .accessibilityIdentifier("previousMysteryButton")

    Button { jump(to: nextMysteryIndex) } label: {
      Label {
        Text(String(localized: "rosaryFlow.nextMystery", defaultValue: "Next Mystery", bundle: UILanguage.bundle, locale: UILanguage.locale))
      } icon: {
        Image(systemName: "forward.end.fill")
          .prayerControlSymbolFont()
          .flipsForRightToLeftLayoutDirection(true)
      }
    }
    #if !os(macOS)
    .labelStyle(.iconOnly)
    #endif
    .disabled(nextMysteryIndex == nil)
    .accessibilityLabel(String(localized: "rosaryFlow.nextMystery", defaultValue: "Next Mystery", bundle: UILanguage.bundle, locale: UILanguage.locale))
    .help(String(localized: "rosaryFlow.nextMystery", defaultValue: "Next Mystery", bundle: UILanguage.bundle, locale: UILanguage.locale))
    .prayerControlTouchTarget()
    .accessibilityIdentifier("nextMysteryButton")

    if let languages = PrayerPackStore.info(for: "rosary")?.languages,
       languages.count > 1 || languages.contains("he") {
      Menu {
        PrayerLanguageMenuContent(code: sessionPrayer.languageCode,
                                 options: LanguageCatalog.availableOptions(for: languages)) { switchLanguage(to: $0) }
      } label: {
        Label(String(localized: "prayerFlow.language", defaultValue: "Prayer Language", bundle: UILanguage.bundle, locale: UILanguage.locale), systemImage: "globe")
      }
      #if !os(macOS)
      .labelStyle(.iconOnly)
      #endif
      .accessibilityLabel(String(localized: "prayerFlow.language", defaultValue: "Prayer Language", bundle: UILanguage.bundle, locale: UILanguage.locale))
      .help(String(localized: "prayerFlow.language", defaultValue: "Prayer Language", bundle: UILanguage.bundle, locale: UILanguage.locale))
      .prayerControlTouchTarget()
      .accessibilityIdentifier("languageMenu")
    }
  }

  private func load() async {
    guard !hasLoaded else { return }
    sessionPrayer = prayer
    isRightToLeft = LanguageCatalog.resolve(sessionPrayer.languageCode).isRightToLeft
    steps = services.engine.buildSteps(for: sessionPrayer)
    currentIndex = 0
    seasonColor = services.calendar.seasonColorToday()
    hasLoaded = true

    let runKey = PrayerRunKey.rosary(prayer)
    var continuation = progressStore.progress(for: runKey)
    #if os(macOS)
    continuation = PrayerCopyProgressIdentity.continuation(continuation, savedLanguageCode: prayer.languageCode)
    #endif
    if let progress = continuation,
       let options = prayer.rosary.navigationOptions(group: progress.rosaryNavigationGroup, order: progress.rosaryNavigationOrder) {
      var candidate = prayer
      candidate.rosary = options
      candidate.languageCode = progress.languageCode
      let candidateSteps = services.engine.buildSteps(for: candidate)
      if progress.canResume(stepCount: candidateSteps.count, sameLocalDayOnly: true,
          expectedConfigurationSignature: PrayerRunSignature.rosary(prayer.rosary,
            navigationGroup: progress.rosaryNavigationGroup, navigationOrder: progress.rosaryNavigationOrder)) {
        sessionPrayer = candidate
        navigationGroup = progress.rosaryNavigationGroup
        navigationOrder = progress.rosaryNavigationOrder
        isRightToLeft = LanguageCatalog.resolve(progress.languageCode).isRightToLeft
        steps = candidateSteps
        pendingContinuation = progress
      }
    }
    if pendingContinuation == nil { progressStore.clear(runKey: runKey) }
    if requiresMysteryChoice { pickerGroup = nil; showsMysteryPicker = true }
  }

  private func next() {
    if currentIndex >= steps.count - 1 {
      complete()
      finishSession()
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

  private func complete() {
    didFinish = true
    progressStore.clear(runKey: PrayerRunKey.rosary(prayer))
  }

  private func finishSession() {
    if let finishPrayerSession { finishPrayerSession() }
    else { dismiss() }
  }

  private func jump(to index: Int?) {
    guard let index else { return }
    if index == steps.count, !steps.isEmpty {
      complete()
      finishSession()
      return
    }
    guard steps.indices.contains(index) else { return }
    currentIndex = index
    persistProgress()
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
      _ = try? await services.presetStore.updateIfPresent(favorite)
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
    navigationGroup = nil
    navigationOrder = nil
    sessionPrayer.rosary = prayer.rosary
    steps = services.engine.buildSteps(for: sessionPrayer)
    if requiresMysteryChoice { pickerGroup = nil; showsMysteryPicker = true }
    progressStore.clear(runKey: PrayerRunKey.rosary(prayer))
  }

  private func persistProgress() {
    progressStore.save(
      runKey: PrayerRunKey.rosary(prayer),
      stepIndex: currentIndex,
      languageCode: sessionPrayer.languageCode,
      configurationSignature: PrayerRunSignature.rosary(prayer.rosary, navigationGroup: navigationGroup, navigationOrder: navigationOrder),
      rosaryNavigationGroup: navigationGroup, rosaryNavigationOrder: navigationOrder)
  }

  private func chooseMystery(_ mystery: Mystery) {
    let beginAtOpening = requiresMysteryChoice
    if prayer.rosary.mysterySelectionMode != .chooseOnLaunch,
       let target = RosaryMysteryNavigation.announcementIndices(in: steps).first(where: { steps[$0].mystery == mystery }) {
      showsMysteryPicker = false
      jump(to: target)
      return
    }
    let group = mystery.group.rawValue
    let order = prayer.rosary.mysterySelectionMode == .singleMystery || prayer.rosary.mysterySelectionMode == .chooseOnLaunch
      ? mystery.order : nil
    guard let options = prayer.rosary.navigationOptions(group: group, order: order) else { return }
    sessionPrayer.rosary = options
    navigationGroup = group
    navigationOrder = order
    steps = services.engine.buildSteps(for: sessionPrayer)
    currentIndex = beginAtOpening ? 0 : RosaryMysteryNavigation.announcementIndices(in: steps).first { steps[$0].mystery == mystery } ?? 0
    showsMysteryPicker = false
    persistProgress()
  }

  private func chooseEntireSet(_ group: MysteryGroup) {
    let beginAtOpening = requiresMysteryChoice
    guard let options = prayer.rosary.navigationOptions(group: group.rawValue, order: nil) else { return }
    sessionPrayer.rosary = options
    navigationGroup = group.rawValue
    navigationOrder = nil
    steps = services.engine.buildSteps(for: sessionPrayer)
    currentIndex = beginAtOpening ? 0 : RosaryMysteryNavigation.announcementIndices(in: steps).first { steps[$0].mystery?.group == group } ?? 0
    showsMysteryPicker = false
    persistProgress()
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

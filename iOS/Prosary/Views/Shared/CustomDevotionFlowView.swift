//
//  CustomDevotionFlowView.swift
//  Prosary
//
//  The single flow view for every PrayerKind.custom bundle devotion. It reads title, structure,
//  options, variants, days, and audio from PrayerPackStore/PrayerEngine, so a new generic
//  devotion needs no new View.
//

import SwiftUI

struct CustomDevotionFlowView: View {
  let devotionId: String
  /// If provided (launched with an existing saved configuration), used directly instead of
  /// re-querying the store.
  var prayer: Prayer? = nil
  /// Explicit continuation choices are session-only; an existing favorite remains unchanged.
  var initialLanguageCode: String? = nil
  var initialVariantId: String? = nil

  @Environment(\.appServices) private var services
  @Environment(\.dismiss) private var dismiss
  @Environment(\.windowNavigation) private var windowNavigation
  @Environment(\.finishPrayerSession) private var finishPrayerSession
  @Environment(\.prayerWindowTitle) private var prayerWindowTitle
  @ObservedObject private var prayerLanguage = PrayerLanguageMonitor.shared

  @State private var steps: [RosaryStep] = []
  @State private var currentIndex = 0
  @State private var isRightToLeft = false
  @State private var seasonColor = Color.clear
  @State private var languageCode: String?
  @State private var matchingFavoriteId: Prayer.ID? = nil
  @State private var isPinned = false
  @State private var displayName: String = ""
  @State private var variantId: String? = nil
  /// The favorite's raw language choice: an explicit code, or the sentinel ("follow the
  /// app-level default setting"). `languageCode` above is always the resolved code.
  @State private var chosenLanguage: String = LanguageCatalog.defaultSentinel
  /// The favorite's bundle-specific choices. These affect the generated sequence and are part
  /// of the continuation signature so an edited preset never resumes into its old step map.
  @State private var customOptions: [String: String] = [:]
  @State private var audio = AudioPlaybackController()
  @State private var suspendedAudioTime: Double?
  @State private var suspendedAudioWasPlaying = false
  /// Multi-day devotions: the day this session prays (0-based; sourced from the favorite).
  @State private var dayIndex = 0
  /// Set when a day was missed: the day that should have happened and the one today calls for.
  @State private var missedDayChoice: (missed: Int, next: Int)?
  @State private var runIsComplete = false
  /// Set when the last day of a series is finished and the bundle's `suggestedNext` resolves to
  /// something this device actually has.
  @State private var completionSuggestion: (id: String, name: String)?
  @State private var pendingContinuation: PrayerRunProgress?
  @State private var hasLoaded = false
  @State private var sessionLoader = PrayerSessionLoader()
  @State private var didFinish = false

  @Environment(\.prayerProgressNamespace) private var progressNamespace
  private var progressStore: PrayerRunProgressStore { PrayerRunProgressStore(namespace: progressNamespace) }

  private var currentStep: RosaryStep? {
    steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
  }

  /// A decade/bead-structured ("rosary" type) devotion gets the same bead track as the Rosary;
  /// flat devotions (no step carries a decadeIndex) get none — same conditional shape the
  /// hardcoded flow views used to hardcode per devotion.
  private var showsBeadTrack: Bool {
    steps.contains { $0.decadeIndex != nil }
  }

  private var hasClosingCross: Bool {
    // Per form, not per bundle: one recension of a chaplet can end with the cross where another
    // does not, and the bead track draws a closing bead on the strength of this.
    guard let definition = PrayerPackStore.definition(for: devotionId) else { return false }
    return definition
      .resolvedRosary(variantId: definition.effectiveVariantId(variantId, languageCode: languageCode))
      .hasClosingCross
  }

  private var beadLayout: BeadLayout {
    BeadLayout.build(steps: steps, currentIndex: currentIndex, hasClosingCross: hasClosingCross)
  }

  private func beadColumnAreaWidth(hasRoomForSingleMinorColumn: Bool) -> CGFloat {
    let majorColumns = CGFloat(max(beadLayout.groupColumns.count, 1)) * 34 + 40
    // Keep the column budget stable while the minor beads appear and disappear between steps.
    guard steps.contains(where: { $0.hailMaryIndexInDecade != nil }) else { return majorColumns }
    return majorColumns + (hasRoomForSingleMinorColumn ? 44 : 74)
  }

  var body: some View {
    PrayerStepFlowView(
      navigationTitle: prayerWindowTitle ?? displayName,
      step: currentStep,
      currentIndex: currentIndex,
      totalSteps: steps.count,
      seasonColor: seasonColor,
      isRightToLeft: isRightToLeft,
      languageCode: languageCode,
      canGoBack: currentIndex > 0,
      onBack: back,
      onNext: next,
      accessory: showsBeadTrack ? { isWide, hasRoomForSingleMinorColumn in
        AnyView(
          BeadProgressView(layout: beadLayout, isWide: isWide,
                           hasRoomForSingleMinorColumn: hasRoomForSingleMinorColumn)
            .frame(width: isWide ? beadColumnAreaWidth(hasRoomForSingleMinorColumn: hasRoomForSingleMinorColumn) : nil)
        )
      } : nil,
      accessoryWidth: showsBeadTrack ? { beadColumnAreaWidth(hasRoomForSingleMinorColumn: $0) } : nil,
      audioBar: audio.isLoaded ? AnyView(
        AudioPlaybackBar(controller: audio, seasonColor: seasonColor,
                         chapterTitles: resolvedChapterTitles)
      ) : nil,
      audioIsPlaying: audio.isPlaying,
      flowActions: AnyView(flowActions)
    )
    // The recording's chapters drive the text while it plays: entering a chapter that carries
    // a stepIndex hint turns the page. Hints are advisory (the built sequence is option- and
    // calendar-dependent), so out-of-range ones are ignored rather than trusted.
    .onChange(of: audio.currentChapterIndex) { _, chapterIndex in
      // The chapters are re-read (not trusted from the event) and bounds-checked: a language
      // switch can swap the track between the change being observed and delivered.
      guard let chapterIndex, let chapters = audio.track?.chapters,
            chapters.indices.contains(chapterIndex),
            let hint = chapters[chapterIndex].stepIndex,
            steps.indices.contains(hint), currentIndex != hint else { return }
      currentIndex = hint
      if hasLoaded, pendingContinuation == nil { persistProgress() }
    }
    .onDisappear {
      if hasLoaded, pendingContinuation == nil, !didFinish { persistProgress() }
      if audio.isLoaded {
        suspendedAudioTime = audio.currentTime
        suspendedAudioWasPlaying = audio.isPlaying
      }
      audio.stop()
    }
    .onChange(of: prayerLanguage.usesJaffaHailMaryWording) { _, _ in
      guard hasLoaded, !didFinish else { return }
      steps = builtSteps()
      currentIndex = min(currentIndex, max(steps.count - 1, 0))
    }
    .confirmationDialog(
      completionSuggestion.map {
        String(localized: "multiDay.completedTitle", defaultValue: "That completes it. Pray \($0.name) next?")
      } ?? "",
      isPresented: .init(
        get: { completionSuggestion != nil },
        set: { if !$0 { completionSuggestion = nil } }),
      titleVisibility: .visible
    ) {
      if let suggestion = completionSuggestion {
        Button(String(localized: "multiDay.prayNext", defaultValue: "Pray \(suggestion.name)")) {
          completionSuggestion = nil
          finishSession()
          windowNavigation?.openRoute(.custom(devotionId: suggestion.id))
        }
      }
      Button(String(localized: "multiDay.notNow", defaultValue: "Not Now"), role: .cancel) {
        completionSuggestion = nil
        finishSession()
      }
    }
    .confirmationDialog(
      String(localized: "multiDay.missedTitle", defaultValue: "You missed a day"),
      isPresented: .init(
        get: { pendingContinuation == nil && missedDayChoice != nil },
        set: { if !$0, pendingContinuation == nil { missedDayChoice = nil } }),
      titleVisibility: .visible
    ) {
      if let choice = missedDayChoice {
        Button(String(localized: "multiDay.prayMissed", defaultValue: "Pray Day \(choice.missed + 1)")) {
          switchDay(to: choice.missed)
          missedDayChoice = nil
        }
        Button(String(localized: "multiDay.prayToday", defaultValue: "Continue with Day \(choice.next + 1)")) {
          switchDay(to: choice.next)
          missedDayChoice = nil
        }
        Button(String(localized: "multiDay.startOver", defaultValue: "Start Over"), role: .destructive) {
          MultiDayRuns.startFresh(seriesRunID)
          refreshSeriesReminders()
          switchDay(to: 0)
          missedDayChoice = nil
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
      .keyboardShortcut(.defaultAction)
      Button(String(localized: "prayerFlow.restart", defaultValue: "Restart"), role: .destructive) {
        restart()
      }
    } message: { _ in
      Text(String(localized: "prayerFlow.continue.message",
                  defaultValue: "You have an unfinished prayer. Continue where you left off or begin again?"))
    }
    .task { await sessionLoader.perform { await load() } }
  }

  @ViewBuilder
  private var flowActions: some View {
    // Language switcher — the app-level prayer-language setting was the only way to change
    // a generic devotion's language, and testers didn't find it (they assumed the devotion
    // shipped fewer languages than it does). Mirrors the variant menu: rebuilds the session
    // in place and persists the choice to the matching favorite when one exists.
    if let languages = PrayerPackStore.info(for: devotionId)?.languages,
       languages.count > 1 || languages.contains("he") {
      Menu {
        PrayerLanguageMenuContent(code: chosenLanguage,
                                 options: LanguageCatalog.availableOptions(for: languages)) { switchLanguage(to: $0) }
      } label: {
        Label(String(localized: "prayerFlow.language", defaultValue: "Prayer Language"), systemImage: "globe")
      }
      #if !os(macOS)
      .labelStyle(.iconOnly)
      #endif
      .accessibilityLabel(String(localized: "prayerFlow.language", defaultValue: "Prayer Language"))
      .accessibilityIdentifier("languageMenu")
    }
    // Day picker — multi-day ("days"-type) devotions only: jump to any day; finishing a
    // session advances the favorite to the next one automatically.
    if let days = PrayerPackStore.definition(for: devotionId)?.days, days.count > 1 {
      Menu {
        ForEach(Array(days.enumerated()), id: \.offset) { index, day in
          Button {
            switchDay(to: index)
          } label: {
            let label = HebrewDisplayText.unpointed(
              day.period.map { "\($0) — \(day.localizedName)" } ?? day.localizedName)
            if index == dayIndex {
              Label(label, systemImage: "checkmark")
            } else {
              Text(label)
            }
          }
        }
      } label: {
        Label(String(localized: "prayerFlow.day", defaultValue: "Day"), systemImage: "calendar")
      }
      #if !os(macOS)
      .labelStyle(.iconOnly)
      #endif
      .accessibilityLabel(String(localized: "prayerFlow.day", defaultValue: "Day"))
      .accessibilityIdentifier("dayMenu")
    }
    // Variant switcher — only for bundles declaring alternate step-sets (e.g. the Stations'
    // traditional vs. scriptural forms). Switching rebuilds the session from step 0 and
    // persists the choice to the matching favorite when one exists.
    if CustomDevotionLaunch.allowsVariantChoice(devotionId),
       let definition = PrayerPackStore.definition(for: devotionId),
       let variants = definition.variants, variants.count > 1 {
      // "No explicit choice" resolves per the prayer language (a rite can declare a form its
      // own), so both the checkmark and the persistence baseline use the effective default.
      let defaultVariantId =
        definition.effectiveVariantId(nil, languageCode: languageCode) ?? variants[0].id
      Menu {
        ForEach(variants, id: \.id) { variant in
          Button {
            switchVariant(to: variant.id, defaultVariantId: defaultVariantId)
          } label: {
            if variant.id == (variantId ?? defaultVariantId) {
              Label(variant.localizedName, systemImage: "checkmark")
            } else {
              Text(variant.localizedName)
            }
          }
        }
      } label: {
        Label(String(localized: "macLibrary.form", defaultValue: "Form"), systemImage: "text.book.closed")
      }
      #if !os(macOS)
      .labelStyle(.iconOnly)
      #endif
      .help(String(localized: "macLibrary.form", defaultValue: "Form"))
      .accessibilityIdentifier("variantMenu")
    }
    #if !os(macOS)
    Button { toggleFavorite() } label: {
      Label(isPinned ? "prayerFlow.removeFromFavorites" : "prayerFlow.addToFavorites",
            systemImage: isPinned ? "star.fill" : "star")
    }
    .labelStyle(.iconOnly)
    .accessibilityLabel(isPinned ? "prayerFlow.removeFromFavorites" : "prayerFlow.addToFavorites")
    .accessibilityIdentifier("pinDevotionButton")
    #endif
  }

  private func load() async {
    if hasLoaded {
      // An ordinary reappearance resumes this live session without rereading its bookmark
      // or replacing its selected language, variant, step, or recording position.
      if !didFinish, let time = suspendedAudioTime, !audio.isLoaded {
        let index = currentIndex
        pickAudioTrack(allowStoredPosition: pendingContinuation == nil)
        currentIndex = index
        audio.seek(to: time)
        if suspendedAudioWasPlaying { audio.playPause() }
        suspendedAudioTime = nil
      }
      return
    }
    let all = (try? await services.presetStore.all()) ?? []
    let impliedPins = await impliedPinnedIds()
    displayName = PrayerPackStore.info(for: devotionId)?.localizedDisplayName ?? devotionId
    let favorite = prayer ?? all.first { $0.kind == .custom && $0.customDevotionId == devotionId }
    matchingFavoriteId = initialLanguageCode == nil && initialVariantId == nil ? favorite?.id : nil
    isPinned = FavoriteDevotions.contains(devotionId, defaultingTo: impliedPins)
    chosenLanguage = initialLanguageCode ?? favorite?.languageCode ?? LanguageCatalog.defaultSentinel
    customOptions = RosaryOptions.normalizedCustomOptions(favorite?.customOptions ?? [:], bundleId: devotionId)
    languageCode = PrayerPackStore.effectiveLanguage(for: devotionId, chosen: chosenLanguage)

    variantId = CustomDevotionLaunch.variantId(
      devotionId: devotionId, incoming: initialVariantId, saved: favorite?.variantId)
    dayIndex = favorite?.dayIndex ?? 0

    // A series decides its own day: today's if it is unprayed, the same day again if it was
    // already prayed today, and a choice when one was missed.
    if let definition = PrayerPackStore.definition(for: devotionId),
       let days = definition.days, days.count > 1,
       (definition.dayProgression ?? .series) == .series {
      let run = MultiDayRuns.run(for: seriesRunID)
      switch run?.resumption(dayCount: days.count) ?? .start {
      case .start:
        dayIndex = 0
      case .resume(let day):
        dayIndex = day
      case .choose(let missed, let next):
        dayIndex = missed
        missedDayChoice = (missed, next)
      case .complete:
        dayIndex = days.count - 1
        runIsComplete = true
      }
      if let run, run.hasPrayedToday(), let last = run.prayedDays.last {
        dayIndex = last
      }
    }

    isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
    steps = builtSteps()
    currentIndex = 0
    seasonColor = services.calendar.seasonColorToday()

    var continuation = progressStore.progress(for: runKey)
    #if os(macOS)
    continuation = PrayerCopyProgressIdentity.continuation(
      continuation, savedLanguageCode: prayer == nil ? nil : chosenLanguage)
    #endif
    if let progress = continuation {
      let savedSteps = builtSteps(languageChoice: progress.languageCode)
      if (initialLanguageCode == nil || progress.languageCode == chosenLanguage), progress.canResume(
        stepCount: savedSteps.count,
        expectedConfigurationSignature: configurationSignature(forLanguageChoice: progress.languageCode)
      ) {
        chosenLanguage = progress.languageCode
        languageCode = PrayerPackStore.effectiveLanguage(for: devotionId, chosen: progress.languageCode)
        isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
        steps = savedSteps
        pendingContinuation = progress
        pickAudioTrack(allowStoredPosition: false)
        currentIndex = 0
      } else {
        progressStore.clear(runKey: runKey)
        pickAudioTrack()
      }
    } else {
      progressStore.clear(runKey: runKey)
      pickAudioTrack()
    }
    hasLoaded = true
  }

  /// The recording for this session, if the bundle ships one: language must match, and the
  /// track's variant (nil = the bundle's single/default form) must match the session's.
  /// First declared match wins — audio.json order is the author's preference order.
  private func pickAudioTrack(allowStoredPosition: Bool = true) {
    let definition = PrayerPackStore.definition(for: devotionId)
    let defaultVariantId =
      definition?.effectiveVariantId(nil, languageCode: languageCode) ?? definition?.variants?.first?.id
    let effectiveVariant = variantId ?? defaultVariantId
    let match = PrayerPackStore.audioTracks(for: devotionId).first {
      $0.language == languageCode && ($0.variantId ?? defaultVariantId) == effectiveVariant
    }
    if let match {
      if audio.track?.id != match.id || !audio.isLoaded {
        audio.load(bundleId: devotionId, track: match, positionNamespace: audioPositionNamespace)
        if audio.didRestorePosition && allowStoredPosition {
          // Resumed mid-recording: pull the page to the restored chapter instead of
          // yanking the recording back to the step-0 chapter.
          if let chapterIndex = audio.currentChapterIndex,
             let hint = audio.track?.chapters[chapterIndex].stepIndex,
             steps.indices.contains(hint) {
            currentIndex = hint
          }
        } else {
          if !allowStoredPosition { audio.seek(to: 0) }
          alignAudioToCurrentStep()
        }
      } else if !allowStoredPosition {
        audio.seek(to: 0)
        alignAudioToCurrentStep()
      }
    } else {
      audio.stop()
    }
  }

  /// Titles for the loaded track's chapters, `titleKey` resolved through the same per-bundle
  /// content chain as step text (the track's own language, not the UI language).
  private var resolvedChapterTitles: [String] {
    guard let track = audio.track else { return [] }
    return track.chapters.map { chapter in
      HebrewDisplayText.unpointed(chapter.title
        ?? chapter.titleKey.map {
          PrayerPackStore.resolveBodyText(bundleId: devotionId, languageCode: track.language, key: $0)
        }
        ?? "")
    }
  }

  /// After a manual Back/Next, bring the recording to the chapter that narrates the new step —
  /// when one does; steps between chapter hints leave the audio where it is.
  private func alignAudioToCurrentStep() {
    guard audio.isLoaded, let chapters = audio.track?.chapters,
          let target = chapters.firstIndex(where: { $0.stepIndex == currentIndex }),
          audio.currentChapterIndex != target else { return }
    audio.seekToChapter(target)
  }

  private func builtSteps(languageChoice: String? = nil) -> [RosaryStep] {
    services.engine.buildSteps(for: Prayer(
      kind: .custom, languageCode: languageChoice ?? chosenLanguage,
      customDevotionId: devotionId, variantId: variantId, dayIndex: dayIndex,
      customOptions: customOptions))
  }

  /// Rebuilds the session in the chosen language. The current position is retained when the
  /// devotion keeps the same effective form; a language-owned form starts at its first step.
  private func switchLanguage(to raw: String) {
    let previousRunKey = runKey
    let previousEffectiveVariantId = effectiveVariantId
    chosenLanguage = raw
    languageCode = PrayerPackStore.effectiveLanguage(for: devotionId, chosen: raw)
    isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
    let position = currentIndex
    steps = builtSteps()
    let nextEffectiveVariantId = effectiveVariantId
    currentIndex = CustomDevotionLanguageSwitch.indexAfterSwitch(
      currentIndex: position,
      previousEffectiveVariantId: previousEffectiveVariantId,
      nextEffectiveVariantId: nextEffectiveVariantId,
      nextStepCount: steps.count)
    if previousEffectiveVariantId != nextEffectiveVariantId {
      progressStore.clear(runKey: previousRunKey)
      progressStore.clear(runKey: runKey)
    }
    pickAudioTrack(allowStoredPosition: false)
    persistProgress()

    // Remember the choice on the matching favorite, if one exists.
    guard let id = matchingFavoriteId else { return }
    Task {
      if var favorite = try? await services.presetStore.get(id: id) {
        favorite.languageCode = raw
        _ = try? await services.presetStore.updateIfPresent(favorite)
      }
    }
  }

  private func switchVariant(to newVariantId: String, defaultVariantId: String) {
    let previousRunKey = runKey
    variantId = newVariantId == defaultVariantId ? nil : newVariantId
    steps = builtSteps()
    currentIndex = 0
    pickAudioTrack(allowStoredPosition: false)
    progressStore.clear(runKey: previousRunKey)
    progressStore.clear(runKey: runKey)

    // Remember the choice on the matching favorite, if one exists.
    guard let id = matchingFavoriteId else { return }
    Task {
      if var favorite = try? await services.presetStore.get(id: id) {
        favorite.variantId = variantId
        _ = try? await services.presetStore.updateIfPresent(favorite)
      }
    }
  }

  private func toggleFavorite() {
    Task {
      // Pinning is what puts a devotion on Pray; the Prayer alongside it only carries this
      // devotion's language/variant/day, so unpinning leaves those settings intact.
      let implied = await impliedPinnedIds()
      FavoriteDevotions.toggle(devotionId, defaultingTo: implied)
      isPinned = FavoriteDevotions.contains(devotionId, defaultingTo: implied)

      // Unpinning keeps the Prayer: it holds the language/variant/day for next time.
      if isPinned, matchingFavoriteId == nil {
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

  /// A devotion counts as pinned by default when it already has a saved configuration — the
  /// same fallback the Pray tab uses, so the star agrees with what that tab shows.
  private func impliedPinnedIds() async -> [String] {
    let all = (try? await services.presetStore.all()) ?? []
    return all.compactMap { prayer in
      switch prayer.kind {
      case .rosary: return "rosary"
      case .jesusPrayer: return "jesusPrayer"
      case .custom: return prayer.customDevotionId
      }
    }
  }

  private func switchDay(to newDayIndex: Int) {
    let previousRunKey = runKey
    dayIndex = newDayIndex
    steps = builtSteps()
    currentIndex = 0
    pickAudioTrack(allowStoredPosition: false)
    progressStore.clear(runKey: previousRunKey)
    progressStore.clear(runKey: runKey)
    persistDayIndex(newDayIndex)
  }

  private func persistDayIndex(_ value: Int) {
    guard let id = matchingFavoriteId else { return }
    Task {
      if var favorite = try? await services.presetStore.get(id: id) {
        favorite.dayIndex = value
        _ = try? await services.presetStore.updateIfPresent(favorite)
      }
    }
  }

  private func next() {
    if currentIndex >= steps.count - 1 {
      didFinish = true
      progressStore.clear(runKey: runKey)
      // Finishing a multi-day session advances the favorite to the next day (staying on the
      // last one once the devotion is complete) — tomorrow opens where the novena left off.
      if let definition = PrayerPackStore.definition(for: devotionId),
         let days = definition.days, days.count > 1 {
        if (definition.dayProgression ?? .series) == .series {
          // A series advances by calendar day, so record *which* day was prayed and let the
          // run decide what comes next — praying twice today must not skip tomorrow's day.
          MultiDayRuns.recordPrayed(devotionId: seriesRunID, day: dayIndex)
          // The remaining days keep their prompts; the finished ones lose theirs.
          refreshSeriesReminders()

          // The last day earns the bundle's parting suggestion — but only when it names a
          // devotion this device has, so a hand-written series can point at its author's other
          // work without leaving a dead end on everyone else's phone.
          if MultiDayRuns.run(for: seriesRunID)?.isComplete(dayCount: days.count) == true,
             let suggestion = MultiDayStatus.suggestedNext(after: devotionId) {
            persistDayIndex(min(dayIndex + 1, days.count - 1))
            completionSuggestion = suggestion
            return
          }
        }
        persistDayIndex(min(dayIndex + 1, days.count - 1))
      }
      finishSession()
      return
    }
    currentIndex += 1
    alignAudioToCurrentStep()
    persistProgress()
  }

  private func back() {
    guard currentIndex > 0 else { return }
    currentIndex -= 1
    alignAudioToCurrentStep()
    persistProgress()
  }

  private var runKey: String {
    PrayerRunKey.custom(seriesRunID, variantId: variantId, dayIndex: dayIndex)
  }

  private var seriesRunID: String {
    #if os(macOS)
    PrayerCopyProgressIdentity.devotionID(devotionId, prayerID: prayer?.id)
    #else
    devotionId
    #endif
  }

  private var audioPositionNamespace: String? {
    #if os(macOS)
    prayer?.id.uuidString
    #else
    nil
    #endif
  }

  private func refreshSeriesReminders() {
    #if os(macOS)
    ReminderScheduler.refreshSeries(devotionId: devotionId, runID: seriesRunID, prayer: prayer)
    #else
    ReminderScheduler.refreshSeries(devotionId: devotionId)
    #endif
  }

  private func finishSession() {
    if let finishPrayerSession { finishPrayerSession() }
    else { dismiss() }
  }

  private var effectiveVariantId: String? {
    PrayerPackStore.definition(for: devotionId)?
      .effectiveVariantId(variantId, languageCode: languageCode)
  }

  private var configurationSignature: String {
    configurationSignature(forLanguageChoice: chosenLanguage)
  }

  private func configurationSignature(forLanguageChoice raw: String) -> String {
    let resolvedLanguage = PrayerPackStore.effectiveLanguage(for: devotionId, chosen: raw)
    let resolvedVariant = PrayerPackStore.definition(for: devotionId)?
      .effectiveVariantId(variantId, languageCode: resolvedLanguage)
    return PrayerRunSignature.custom(
      devotionId,
      effectiveVariantId: resolvedVariant,
      dayIndex: dayIndex,
      options: customOptions)
  }

  private func resume(_ progress: PrayerRunProgress) {
    pendingContinuation = nil
    chosenLanguage = progress.languageCode
    languageCode = PrayerPackStore.effectiveLanguage(for: devotionId, chosen: progress.languageCode)
    isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
    steps = builtSteps()
    pickAudioTrack()
    currentIndex = min(progress.stepIndex, max(steps.count - 1, 0))
    alignAudioToCurrentStep()
    persistProgress()
  }

  private func restart() {
    pendingContinuation = nil
    currentIndex = 0
    audio.seek(to: 0)
    progressStore.clear(runKey: runKey)
  }

  private func persistProgress() {
    progressStore.save(
      runKey: runKey,
      stepIndex: currentIndex,
      languageCode: chosenLanguage,
      configurationSignature: configurationSignature)
  }
}

#Preview {
  let store = MockPresetStore()
  return NavigationStack {
    CustomDevotionFlowView(devotionId: "trisagion")
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
}

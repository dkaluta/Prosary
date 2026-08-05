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
  @State private var seasonColor = Color.clear
  @State private var languageCode: String?
  @State private var matchingFavoriteId: Prayer.ID? = nil
  @State private var isPinned = false
  @State private var displayName: String = ""
  @State private var variantId: String? = nil
  /// The favorite's raw language choice: an explicit code, or the sentinel ("follow the
  /// app-level default setting"). `languageCode` above is always the resolved code.
  @State private var chosenLanguage: String = LanguageCatalog.defaultSentinel
  @State private var audio = AudioPlaybackController()
  /// Multi-day devotions: the day this session prays (0-based; sourced from the favorite).
  @State private var dayIndex = 0

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
    PrayerPackStore.definition(for: devotionId)?.hasClosingCross ?? false
  }

  private var beadLayout: BeadLayout {
    BeadLayout.build(steps: steps, currentIndex: currentIndex, hasClosingCross: hasClosingCross)
  }

  private func beadColumnAreaWidth(hasRoomForSingleMinorColumn: Bool) -> CGFloat {
    let majorColumns = CGFloat(max(beadLayout.groupColumns.count, 1)) * 34 + 40
    guard beadLayout.showBottomBeads else { return majorColumns }
    return majorColumns + (hasRoomForSingleMinorColumn ? 44 : 74)
  }

  var body: some View {
    PrayerStepFlowView(
      navigationTitle: displayName,
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
            .frame(width: beadColumnAreaWidth(hasRoomForSingleMinorColumn: hasRoomForSingleMinorColumn))
        )
      } : nil,
      audioBar: audio.isLoaded ? AnyView(
        AudioPlaybackBar(controller: audio, seasonColor: seasonColor,
                         chapterTitles: resolvedChapterTitles)
      ) : nil,
      audioIsPlaying: audio.isPlaying
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
    }
    .onDisappear { audio.stop() }
    .toolbar {
      // Language switcher — the app-level prayer-language setting was the only way to change
      // a generic devotion's language, and testers didn't find it (they assumed the devotion
      // shipped fewer languages than it does). Mirrors the variant menu: rebuilds the session
      // in place and persists the choice to the matching favorite when one exists.
      if let languages = PrayerPackStore.info(for: devotionId)?.languages, languages.count > 1 {
        ToolbarItem(placement: .primaryAction) {
          Menu {
            languageButton(
              raw: LanguageCatalog.defaultSentinel,
              name: String(localized: "prayerFlow.language.appDefault", defaultValue: "App setting"))
            Divider()
            ForEach(languages, id: \.self) { code in
              if let option = LanguageCatalog.all.first(where: { $0.code == code }) {
                languageButton(raw: option.code, name: option.nativeName)
              }
            }
          } label: {
            Image(systemName: "globe")
          }
          .accessibilityLabel(String(localized: "prayerFlow.language", defaultValue: "Prayer language"))
          .accessibilityIdentifier("languageMenu")
        }
      }
      // Day picker — multi-day ("days"-type) devotions only: jump to any day; finishing a
      // session advances the favorite to the next one automatically.
      if let days = PrayerPackStore.definition(for: devotionId)?.days, days.count > 1 {
        ToolbarItem(placement: .primaryAction) {
          Menu {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
              Button {
                switchDay(to: index)
              } label: {
                let label = day.period.map { "\($0) — \(day.localizedName)" } ?? day.localizedName
                if index == dayIndex {
                  Label(label, systemImage: "checkmark")
                } else {
                  Text(label)
                }
              }
            }
          } label: {
            Image(systemName: "calendar")
          }
          .accessibilityLabel(String(localized: "prayerFlow.day", defaultValue: "Day"))
          .accessibilityIdentifier("dayMenu")
        }
      }
      // Variant switcher — only for bundles declaring alternate step-sets (e.g. the Stations'
      // traditional vs. scriptural forms). Switching rebuilds the session from step 0 and
      // persists the choice to the matching favorite when one exists.
      if let variants = PrayerPackStore.definition(for: devotionId)?.variants, variants.count > 1 {
        ToolbarItem(placement: .primaryAction) {
          Menu {
            ForEach(variants, id: \.id) { variant in
              Button {
                switchVariant(to: variant.id, defaultVariantId: variants[0].id)
              } label: {
                if variant.id == (variantId ?? variants[0].id) {
                  Label(variant.localizedName, systemImage: "checkmark")
                } else {
                  Text(variant.localizedName)
                }
              }
            }
          } label: {
            Image(systemName: "text.book.closed")
          }
          .accessibilityIdentifier("variantMenu")
        }
      }
      ToolbarItem(placement: .primaryAction) {
        Button { toggleFavorite() } label: {
          Image(systemName: isPinned ? "star.fill" : "star")
        }
        .accessibilityLabel(isPinned ? "prayerFlow.removeFromFavorites" : "prayerFlow.addToFavorites")
        .accessibilityIdentifier("pinDevotionButton")
      }
    }
    .task { await load() }
  }

  private func load() async {
    displayName = PrayerPackStore.info(for: devotionId)?.localizedDisplayName ?? devotionId

    let all = (try? await services.presetStore.all()) ?? []
    let favorite = prayer ?? all.first { $0.kind == .custom && $0.customDevotionId == devotionId }
    matchingFavoriteId = favorite?.id
    isPinned = FavoriteDevotions.contains(devotionId, defaultingTo: await impliedPinnedIds())
    chosenLanguage = favorite?.languageCode ?? LanguageCatalog.defaultSentinel
    languageCode = PrayerPackStore.effectiveLanguage(for: devotionId, chosen: chosenLanguage)

    variantId = favorite?.variantId
    dayIndex = favorite?.dayIndex ?? 0

    isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
    steps = builtSteps()
    currentIndex = 0
    seasonColor = services.calendar.seasonColorToday()
    pickAudioTrack()
  }

  /// The recording for this session, if the bundle ships one: language must match, and the
  /// track's variant (nil = the bundle's single/default form) must match the session's.
  /// First declared match wins — audio.json order is the author's preference order.
  private func pickAudioTrack() {
    let defaultVariantId = PrayerPackStore.definition(for: devotionId)?.variants?.first?.id
    let effectiveVariant = variantId ?? defaultVariantId
    let match = PrayerPackStore.audioTracks(for: devotionId).first {
      $0.language == languageCode && ($0.variantId ?? defaultVariantId) == effectiveVariant
    }
    if let match {
      if audio.track?.id != match.id || !audio.isLoaded {
        audio.load(bundleId: devotionId, track: match)
        if audio.didRestorePosition {
          // Resumed mid-recording: pull the page to the restored chapter instead of
          // yanking the recording back to the step-0 chapter.
          if let chapterIndex = audio.currentChapterIndex,
             let hint = audio.track?.chapters[chapterIndex].stepIndex,
             steps.indices.contains(hint) {
            currentIndex = hint
          }
        } else {
          alignAudioToCurrentStep()
        }
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
      chapter.title
        ?? chapter.titleKey.map {
          PrayerPackStore.resolveBodyText(bundleId: devotionId, languageCode: track.language, key: $0)
        }
        ?? ""
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

  private func builtSteps() -> [RosaryStep] {
    services.engine.buildSteps(for: Prayer(
      kind: .custom, languageCode: chosenLanguage,
      customDevotionId: devotionId, variantId: variantId, dayIndex: dayIndex))
  }

  @ViewBuilder
  private func languageButton(raw: String, name: String) -> some View {
    Button {
      switchLanguage(to: raw)
    } label: {
      if raw == chosenLanguage {
        Label(name, systemImage: "checkmark")
      } else {
        Text(name)
      }
    }
  }

  /// Rebuilds the session in the chosen language, keeping the current position — unlike a
  /// variant switch, the step sequence is identical across languages, only its text changes.
  private func switchLanguage(to raw: String) {
    chosenLanguage = raw
    languageCode = PrayerPackStore.effectiveLanguage(for: devotionId, chosen: raw)
    isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
    let position = currentIndex
    steps = builtSteps()
    currentIndex = min(position, max(steps.count - 1, 0))
    pickAudioTrack()

    // Remember the choice on the matching favorite, if one exists.
    guard let id = matchingFavoriteId else { return }
    Task {
      if var favorite = try? await services.presetStore.get(id: id) {
        favorite.languageCode = raw
        try? await services.presetStore.save(favorite)
      }
    }
  }

  private func switchVariant(to newVariantId: String, defaultVariantId: String) {
    variantId = newVariantId == defaultVariantId ? nil : newVariantId
    steps = builtSteps()
    currentIndex = 0
    pickAudioTrack()

    // Remember the choice on the matching favorite, if one exists.
    guard let id = matchingFavoriteId else { return }
    Task {
      if var favorite = try? await services.presetStore.get(id: id) {
        favorite.variantId = variantId
        try? await services.presetStore.save(favorite)
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
    dayIndex = newDayIndex
    steps = builtSteps()
    currentIndex = 0
    persistDayIndex(newDayIndex)
  }

  private func persistDayIndex(_ value: Int) {
    guard let id = matchingFavoriteId else { return }
    Task {
      if var favorite = try? await services.presetStore.get(id: id) {
        favorite.dayIndex = value
        try? await services.presetStore.save(favorite)
      }
    }
  }

  private func next() {
    if currentIndex >= steps.count - 1 {
      // Finishing a multi-day session advances the favorite to the next day (staying on the
      // last one once the devotion is complete) — tomorrow opens where the novena left off.
      if let days = PrayerPackStore.definition(for: devotionId)?.days, days.count > 1 {
        persistDayIndex(min(dayIndex + 1, days.count - 1))
      }
      dismiss()
      return
    }
    currentIndex += 1
    alignAudioToCurrentStep()
  }

  private func back() {
    guard currentIndex > 0 else { return }
    currentIndex -= 1
    alignAudioToCurrentStep()
  }
}

#Preview {
  let store = MockPresetStore()
  return NavigationStack {
    CustomDevotionFlowView(devotionId: "trisagion")
      .environment(\.appServices, AppServices(presetStore: store, engine: PrayerEngine(calendar: MockLiturgicalCalendar()), calendar: MockLiturgicalCalendar()))
  }
}

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
  @State private var displayName: String = ""
  @State private var variantId: String? = nil
  /// The favorite's raw language choice: an explicit code, or the sentinel ("follow the
  /// app-level default setting"). `languageCode` above is always the resolved code.
  @State private var chosenLanguage: String = LanguageCatalog.defaultSentinel

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
      } : nil
    )
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
          Image(systemName: matchingFavoriteId != nil ? "star.fill" : "star")
        }
        .accessibilityLabel(matchingFavoriteId != nil ? "prayerFlow.removeFromFavorites" : "prayerFlow.addToFavorites")
      }
    }
    .task { await load() }
  }

  private func load() async {
    displayName = PrayerPackStore.info(for: devotionId)?.localizedDisplayName ?? devotionId

    let all = (try? await services.presetStore.all()) ?? []
    let favorite = prayer ?? all.first { $0.kind == .custom && $0.customDevotionId == devotionId }
    matchingFavoriteId = favorite?.id
    chosenLanguage = favorite?.languageCode ?? LanguageCatalog.defaultSentinel
    languageCode = LanguageCatalog.resolve(chosenLanguage).code

    variantId = favorite?.variantId

    isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
    steps = builtSteps()
    currentIndex = 0
    seasonColor = services.calendar.seasonColorToday()
  }

  private func builtSteps() -> [RosaryStep] {
    services.engine.buildSteps(for: Prayer(
      kind: .custom, languageCode: chosenLanguage,
      customDevotionId: devotionId, variantId: variantId))
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
    let resolved = LanguageCatalog.resolve(raw)
    languageCode = resolved.code
    isRightToLeft = resolved.isRightToLeft
    let position = currentIndex
    steps = builtSteps()
    currentIndex = min(position, max(steps.count - 1, 0))

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

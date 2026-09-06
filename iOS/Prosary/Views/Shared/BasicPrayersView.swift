//
//  BasicPrayersView.swift
//  Prosary
//
//  The basic prayers on their own, outside any devotion (Erez, 2026-08-07) — a plain list from
//  BasicPrayerCatalog, each row opening its prayer as a single step in the shared flow chrome.
//  Row titles resolve in the prayer language through the same chains the flows use, so the list
//  itself reads in the rite being prayed: in the Mission of St. Gamaliel's, the Holy God row is
//  קדישת over Erez's own acclamation.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct BasicPrayersView: View {
  /// App-setting mode follows the default prayer language; the monitor is the mechanism
  /// that survives the Mac's Settings menu — see PrayerLanguageMonitor's header for the
  /// graveyard of simpler attempts. Reading `.code` in body registers the dependency.
  @ObservedObject private var prayerLanguage = PrayerLanguageMonitor.shared
  @AppStorage(BasicPrayerCatalog.languageDefaultsKey) private var chosenLanguage = LanguageCatalog.defaultSentinel
  private var showsPrayerNameInPrayerLanguage: Bool { prayerLanguage.showsPrayerNameInPrayerLanguage }

  /// Kept explicit rather than relying on NavigationLink's internal write: two Mac clicks can
  /// arrive before this source row disappears, and every other app route is single-top.
  @Binding var path: [AppRoute]

  /// Bumped after a move so the list re-derives from the saved order — the order lives in
  /// BasicPrayersOrder, not in view state, so the flows and every future surface agree on it.
  @State private var orderGeneration = 0

  var body: some View {
    let _ = prayerLanguage.code  // dependency registration — see the property's comment
    let _ = orderGeneration
    let _ = CloudPreferencesGeneration.shared.value
    let language = LanguageCatalog.resolve(chosenLanguage)
    let ordered = BasicPrayersOrder.apply(BasicPrayerCatalog.all)
    List {
      ForEach(ordered) { prayer in
        HStack(spacing: 8) {
          Button {
            path.push(.basicPrayer(id: prayer.id))
          } label: {
            BasicPrayerRow(prayer: prayer, language: language,
                           showPrayerLanguage: showsPrayerNameInPrayerLanguage)
              .frame(maxWidth: .infinity, alignment: .leading)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("basicPrayer-\(prayer.id)")
          Button {
            BasicPrayerFavorites.toggle(prayer.id)
            orderGeneration += 1
          } label: {
            Image(systemName: BasicPrayerFavorites.contains(prayer.id) ? "pin.fill" : "pin")
              .foregroundStyle(BasicPrayerFavorites.contains(prayer.id) ? Color.accentColor : .secondary)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(BasicPrayerFavorites.contains(prayer.id)
            ? String(localized: "basicPrayers.unpin", defaultValue: "Unpin from home")
            : String(localized: "basicPrayers.pin", defaultValue: "Pin to home"))
          .accessibilityIdentifier("basicPrayerPin-\(prayer.id)")
        }
      }
      // Reorderable per Erez (2026-08-08): drag on macOS, Edit mode on iOS. The same
      // HomeOrder idea — persisted ids, catalog order for the rest.
      .onMove { from, to in
        var ids = ordered.map(\.id)
        ids.move(fromOffsets: from, toOffset: to)
        BasicPrayersOrder.save(ids)
        orderGeneration += 1
      }
    }
    .navigationTitle(String(localized: "basicPrayers.title", defaultValue: "Basic Prayers"))
    .toolbar {
      BasicPrayersLanguageMenu(chosenLanguage: $chosenLanguage)
      #if os(iOS)
      EditButton()
      #endif
    }
  }
}

private struct BasicPrayerRow: View {
  let prayer: BasicPrayer
  let language: LanguageOption
  let showPrayerLanguage: Bool

  var body: some View {
    // Re-rendered by the observing parent list; no monitor of its own needed.
    HStack(spacing: 12) {
      PrayerArtworkView(imageKey: prayer.imageKey)
        .aspectRatio(contentMode: .fill)
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
      let name = PrayerNamePresentation.basicPrayer(prayer, languageCode: language.code,
                                                    showPrayerLanguage: showPrayerLanguage)
      VStack(alignment: .leading, spacing: 3) {
        Text(name.title)
          .environment(\.layoutDirection, showPrayerLanguage
            ? (language.isRightToLeft ? .rightToLeft : .leftToRight)
            : (UILanguage.isRightToLeft(UILanguage.current) ? .rightToLeft : .leftToRight))
        if let translation = name.translation {
          Text(translation).font(.subheadline).foregroundStyle(.secondary)
        }
      }
    }
  }
}

#Preview("Basic Prayers") {
  NavigationStack {
    BasicPrayersView(path: .constant([]))
      .appRouteDestinations(path: .constant([]))
  }
}

/// One basic prayer as a bounded single-step flow: the same chrome every devotion uses —
/// typography, RTL, the transliteration toggle — with "Finish" as its only footer action.
struct BasicPrayerFlowView: View {
  let prayerId: String

  @Environment(\.appServices) private var services
  @Environment(\.dismiss) private var dismiss

  /// A basic prayer is a reference page, not a session — it re-derives live. See
  /// PrayerLanguageMonitor for why nothing simpler works.
  @ObservedObject private var prayerLanguage = PrayerLanguageMonitor.shared
  @AppStorage(BasicPrayerCatalog.languageDefaultsKey) private var chosenLanguage = LanguageCatalog.defaultSentinel

  @State private var seasonColor = Color.clear

  var body: some View {
    let _ = prayerLanguage.code
    let language = LanguageCatalog.resolve(chosenLanguage)
    let step = BasicPrayerCatalog.prayer(id: prayerId).map {
      BasicPrayerCatalog.step(for: $0, languageCode: language.code)
    }
    PrayerStepFlowView(
      navigationTitle: step?.title ?? "",
      step: step,
      currentIndex: 0,
      totalSteps: 1,
      seasonColor: seasonColor,
      isRightToLeft: language.isRightToLeft,
      languageCode: language.code,
      canGoBack: false,
      onBack: {},
      onNext: { dismiss() },
      flowActions: AnyView(BasicPrayersLanguageMenu(chosenLanguage: $chosenLanguage)))
    .onAppear {
      seasonColor = services.calendar.seasonColorToday()
    }
  }
}

private struct BasicPrayersLanguageMenu: View {
  @Binding var chosenLanguage: String

  var body: some View {
    Menu {
      PrayerLanguageMenuContent(code: chosenLanguage, identifierPrefix: "basicPrayerLanguage") { chosenLanguage = $0 }
    } label: {
      Image(systemName: "globe")
    }
    .accessibilityLabel(String(localized: "prayerFlow.language", defaultValue: "Prayer language"))
    .accessibilityIdentifier("languageMenu")
  }

}

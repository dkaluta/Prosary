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
  /// Names on this screen follow the default prayer language, so the screen must re-derive
  /// the moment that setting changes — including from the Mac's Settings window, which never
  /// re-triggers onAppear. Declaring this is NOT enough: SwiftUI only registers the dependency
  /// when body actually reads the value (verified live on the Mac, 2026-08-08 — the Settings
  /// window showed עברית while Pray behind it stayed English), which is what the
  /// `let _ = observedPrayerLanguage` at the top of body is for.
  @AppStorage("defaultLanguageCode") private var observedPrayerLanguage = LanguageCatalog.defaultCode

  var body: some View {
    List(BasicPrayerCatalog.all) { prayer in
      NavigationLink(value: AppRoute.basicPrayer(id: prayer.id)) {
        BasicPrayerRow(prayer: prayer)
      }
    }
    .navigationTitle(String(localized: "basicPrayers.title", defaultValue: "Basic Prayers"))
  }
}

private struct BasicPrayerRow: View {
  let prayer: BasicPrayer

  var body: some View {
    let language = LanguageCatalog.resolve(nil)
    HStack(spacing: 12) {
      resolvedImage(for: prayer.imageKey)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
      Text(PrayerPackStore.resolveBodyText(
        bundleId: prayer.bundleId, languageCode: language.code, key: prayer.titleKey))
        .environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)
    }
    .accessibilityIdentifier("basicPrayer-\(prayer.id)")
  }

  /// Pack image data first, asset catalog second — the same resolution the flow itself uses.
  private func resolvedImage(for imageKey: String) -> Image {
    if let data = PrayerPackStore.imageData(for: imageKey) {
      #if canImport(UIKit)
      if let uiImage = UIImage(data: data) { return Image(uiImage: uiImage) }
      #else
      if let nsImage = NSImage(data: data) { return Image(nsImage: nsImage) }
      #endif
    }
    return Image(imageKey)
  }
}

/// One basic prayer as a bounded single-step flow: the same chrome every devotion uses —
/// typography, RTL, the transliteration toggle — with "Finish" as its only footer action.
struct BasicPrayerFlowView: View {
  let prayerId: String

  @Environment(\.appServices) private var services
  @Environment(\.dismiss) private var dismiss

  @State private var step: RosaryStep?
  @State private var seasonColor = Color.clear

  var body: some View {
    let language = LanguageCatalog.resolve(nil)
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
      onNext: { dismiss() })
    .onAppear {
      if let prayer = BasicPrayerCatalog.prayer(id: prayerId) {
        step = BasicPrayerCatalog.step(for: prayer)
      }
      seasonColor = services.calendar.seasonColorToday()
    }
  }
}

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

  private var currentStep: RosaryStep? {
    steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
  }

  private var beadLayout: BeadLayout {
    BeadLayout.build(steps: steps, currentIndex: currentIndex,
                     hasClosingCross: prayer.rosary.includeFinalSignOfCross)
  }

  private func beadColumnAreaWidth(hasRoomForSingleMinorColumn: Bool) -> CGFloat {
    let majorColumns = CGFloat(max(beadLayout.groupColumns.count, 1)) * 34 + 40
    guard beadLayout.showBottomBeads else { return majorColumns }
    return majorColumns + (hasRoomForSingleMinorColumn ? 44 : 74)
  }

  var body: some View {
    PrayerStepFlowView(
      navigationTitle: "Praying the Rosary",
      step: currentStep,
      currentIndex: currentIndex,
      totalSteps: steps.count,
      seasonColor: seasonColor,
      isRightToLeft: isRightToLeft,
      languageCode: prayer.resolvedLanguageCode,
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
    .task { await load() }
  }

  private func load() async {
    isRightToLeft = LanguageCatalog.resolve(prayer.languageCode).isRightToLeft
    steps = services.rosaryEngine.buildSteps(for: prayer)
    currentIndex = 0
    seasonColor = services.calendar.seasonColorToday()
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

#Preview("iPhone") {
  let prayer = Prayer(rosary: RosaryOptions(mysterySelectionMode: .todaysMysteries))
  let store = MockPresetStore(configs: [prayer])
  return NavigationStack {
    RosaryFlowView(prayer: prayer)
      .environment(\.appServices, AppServices(presetStore: store, rosaryEngine: MockRosaryEngine(), angelusEngine: MockAngelusEngine(), calendar: MockLiturgicalCalendar()))
  }
}

#Preview("Wide (Mac/iPad)") {
  let prayer = Prayer(rosary: RosaryOptions(mysterySelectionMode: .twentyMystery))
  let store = MockPresetStore(configs: [prayer])
  return NavigationStack {
    RosaryFlowView(prayer: prayer)
      .environment(\.appServices, AppServices(presetStore: store, rosaryEngine: MockRosaryEngine(), angelusEngine: MockAngelusEngine(), calendar: MockLiturgicalCalendar()))
  }
  .environment(\.horizontalSizeClass, .regular)
  .frame(width: 900, height: 600)
}

#Preview("Hebrew — RTL") {
  let prayer = Prayer(languageCode: "he", rosary: RosaryOptions(mysterySelectionMode: .specific, specificMysteryGroup: .glorious))
  let store = MockPresetStore(configs: [prayer])
  return NavigationStack {
    RosaryFlowView(prayer: prayer)
      .environment(\.appServices, AppServices(presetStore: store, rosaryEngine: MockRosaryEngine(), angelusEngine: MockAngelusEngine(), calendar: MockLiturgicalCalendar()))
  }
}

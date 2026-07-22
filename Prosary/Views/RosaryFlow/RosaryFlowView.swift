//
//  RosaryFlowView.swift
//  Prosary
//

import SwiftUI

struct RosaryFlowView: View {
    let configId: RosaryConfig.ID

    @Environment(\.appServices) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var config: RosaryConfig?
    @State private var steps: [RosaryStep] = []
    @State private var currentIndex = 0
    @State private var isRightToLeft = false
    @State private var seasonColor = Color.clear

    private var currentStep: RosaryStep? {
        steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
    }

    private var beadLayout: BeadLayout {
        BeadLayout.build(steps: steps, currentIndex: currentIndex, hasClosingCross: config?.includeFinalSignOfCross ?? false)
    }

    /// Widens as a session spans more mystery-group columns (e.g. 3-4 for a 15/20-mystery
    /// session) rather than growing taller. Widens further still when minor beads are showing
    /// beside the major beads (mid-decade) — more so when they need two columns instead of one.
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
            languageCode: config?.languageCode,
            canGoBack: currentIndex > 0,
            onBack: back,
            onNext: next,
            accessory: { isWide, hasRoomForSingleMinorColumn in
                AnyView(
                    BeadProgressView(layout: beadLayout, isWide: isWide, hasRoomForSingleMinorColumn: hasRoomForSingleMinorColumn)
                        .frame(width: beadColumnAreaWidth(hasRoomForSingleMinorColumn: hasRoomForSingleMinorColumn))
                )
            }
        )
        .task { await load() }
    }

    private func load() async {
        var resolvedConfig = try? await services.presetStore.get(id: configId)
        if resolvedConfig == nil {
            resolvedConfig = try? await services.presetStore.defaultPreset()
        }
        guard let resolvedConfig else { return }

        config = resolvedConfig
        isRightToLeft = LanguageCatalog.resolve(resolvedConfig.languageCode).isRightToLeft
        steps = services.rosaryEngine.buildSteps(for: resolvedConfig)
        currentIndex = 0
        seasonColor = services.calendar.seasonColorToday()
    }

    private func next() {
        if currentIndex >= steps.count - 1 {
            dismiss()
            return
        }
        currentIndex += 1
    }

    private func back() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }
}

#Preview("iPhone") {
    let config = RosaryConfig(mysterySelectionMode: .todaysMysteries)
    let store = MockPresetStore(configs: [config])
    return NavigationStack {
        RosaryFlowView(configId: config.id)
            .environment(\.appServices, AppServices(presetStore: store, rosaryEngine: MockRosaryEngine(), angelusEngine: MockAngelusEngine(), calendar: MockLiturgicalCalendar()))
    }
}

#Preview("Wide (Mac/iPad)") {
    let config = RosaryConfig(mysterySelectionMode: .twentyMystery)
    let store = MockPresetStore(configs: [config])
    return NavigationStack {
        RosaryFlowView(configId: config.id)
            .environment(\.appServices, AppServices(presetStore: store, rosaryEngine: MockRosaryEngine(), angelusEngine: MockAngelusEngine(), calendar: MockLiturgicalCalendar()))
    }
    .environment(\.horizontalSizeClass, .regular)
    .frame(width: 900, height: 600)
}

#Preview("Hebrew — RTL") {
    let hebrewConfig = RosaryConfig(mysterySelectionMode: .specific, specificMysteryGroup: .glorious, languageCode: "he")
    let store = MockPresetStore(configs: [hebrewConfig])
    return NavigationStack {
        RosaryFlowView(configId: hebrewConfig.id)
            .environment(\.appServices, AppServices(presetStore: store, rosaryEngine: MockRosaryEngine(), angelusEngine: MockAngelusEngine(), calendar: MockLiturgicalCalendar()))
    }
}

//
//  AngelusFlowView.swift
//  Prosary
//

import SwiftUI

struct AngelusFlowView: View {
    @Environment(\.appServices) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var steps: [RosaryStep] = []
    @State private var currentIndex = 0
    @State private var isRightToLeft = false
    @State private var seasonColor = Color.clear
    @State private var languageCode: String?

    private var currentStep: RosaryStep? {
        steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
    }

    var body: some View {
        PrayerStepFlowView(
            navigationTitle: "The Angelus",
            step: currentStep,
            currentIndex: currentIndex,
            totalSteps: steps.count,
            seasonColor: seasonColor,
            isRightToLeft: isRightToLeft,
            languageCode: languageCode,
            canGoBack: currentIndex > 0,
            onBack: back,
            onNext: next
        )
        .task { await load() }
    }

    private func load() async {
        // Same language source HomeView already reads for the default Rosary preset — the
        // Angelus has no config of its own, so it borrows the user's usual prayer language
        // instead of introducing a separate picker.
        let preset = try? await services.presetStore.defaultPreset()
        languageCode = preset?.languageCode
        isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
        steps = services.angelusEngine.buildSteps(languageCode: languageCode)
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

#Preview {
    let store = MockPresetStore()
    return NavigationStack {
        AngelusFlowView()
            .environment(\.appServices, AppServices(presetStore: store, rosaryEngine: MockRosaryEngine(), angelusEngine: MockAngelusEngine(), calendar: MockLiturgicalCalendar()))
    }
}

#Preview("Hebrew — RTL") {
    let store = MockPresetStore(configs: [RosaryConfig(name: "Hebrew", isDefault: true, languageCode: "he")])
    return NavigationStack {
        AngelusFlowView()
            .environment(\.appServices, AppServices(presetStore: store, rosaryEngine: MockRosaryEngine(), angelusEngine: MockAngelusEngine(), calendar: MockLiturgicalCalendar()))
    }
}

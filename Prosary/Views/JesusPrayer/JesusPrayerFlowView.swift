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
    /// Bound (rather than using `@Environment(\.dismiss)`, as RosaryFlowView/AngelusFlowView do)
    /// because this screen sits two levels deep in the stack (Home → Setup → Flow) — a plain
    /// `dismiss()` would only pop back to Setup, not all the way to Home like finishing every
    /// other devotion does.
    @Binding var path: NavigationPath
    let target: JesusPrayerTarget

    @Environment(\.appServices) private var services

    @State private var progress: JesusPrayerProgress
    @State private var isRightToLeft = false
    @State private var seasonColor = Color.clear
    @State private var languageCode: String?
    @State private var hasLoaded = false

    init(path: Binding<NavigationPath>, target: JesusPrayerTarget) {
        _path = path
        self.target = target
        _progress = State(initialValue: JesusPrayerProgress(target: target))
    }

    private var currentStep: RosaryStep? {
        guard hasLoaded else { return nil }
        return RosaryStep(
            title: "Jesus Prayer", subtitle: nil,
            body: PrayerTranslations.get(languageCode: languageCode, key: .oratioIesu),
            imageOverrideKey: "jesus_portrait")
    }

    var body: some View {
        PrayerStepFlowView(
            navigationTitle: "The Jesus Prayer",
            step: currentStep,
            currentIndex: progress.currentIndex,
            totalSteps: progress.targetCount,
            seasonColor: seasonColor,
            isRightToLeft: isRightToLeft,
            languageCode: languageCode,
            canGoBack: progress.canGoBack,
            onBack: { progress.goBack() },
            onNext: next
        )
        .toolbar {
            // Unbounded has no target, so it never reaches "Finish" via the footer's Next button
            // (see JesusPrayerProgress.isLastRep) — this is the only way to end that session.
            if case .unbounded = target {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { returnHome() }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        // Same language source Angelus uses — no config of its own, so it borrows the user's
        // usual prayer language.
        let preset = try? await services.presetStore.defaultPreset()
        languageCode = preset?.languageCode
        isRightToLeft = LanguageCatalog.resolve(languageCode ?? LanguageCatalog.defaultCode).isRightToLeft
        seasonColor = services.calendar.seasonColorToday()
        hasLoaded = true
    }

    private func next() {
        if progress.isLastRep {
            returnHome()
            return
        }
        progress.goNext()
    }

    private func returnHome() {
        path.removeLast(path.count)
    }
}

#Preview("Bounded — 33") {
    NavigationStack {
        JesusPrayerFlowView(path: .constant(NavigationPath()), target: .count(33))
            .environment(\.appServices, AppServices(presetStore: MockPresetStore(), rosaryEngine: MockRosaryEngine(), angelusEngine: MockAngelusEngine(), calendar: MockLiturgicalCalendar()))
    }
}

#Preview("Unbounded") {
    NavigationStack {
        JesusPrayerFlowView(path: .constant(NavigationPath()), target: .unbounded)
            .environment(\.appServices, AppServices(presetStore: MockPresetStore(), rosaryEngine: MockRosaryEngine(), angelusEngine: MockAngelusEngine(), calendar: MockLiturgicalCalendar()))
    }
}

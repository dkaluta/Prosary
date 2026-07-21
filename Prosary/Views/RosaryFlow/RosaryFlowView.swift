//
//  RosaryFlowView.swift
//  Prosary
//

import SwiftUI

struct RosaryFlowView: View {
    let configId: RosaryConfig.ID

    @Environment(\.appServices) private var services
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dismiss) private var dismiss

    @State private var config: RosaryConfig?
    @State private var steps: [RosaryStep] = []
    @State private var currentIndex = 0
    @State private var isRightToLeft = false
    @State private var seasonColor = Color.clear

    /// Regular width (Mac, a wide iPad window, Vision) gets the taller three-column layout; so
    /// does a compact-*height* window, which is how even a non-Max iPhone reports itself in
    /// landscape (its width stays `.compact`) — that's a short, wide screen the single scrolling
    /// column would waste, so it gets the same wide layout as Mac. A narrow split-screen iPad
    /// (compact width, regular height) is the one case that keeps the single column.
    private var isWide: Bool { horizontalSizeClass == .regular || verticalSizeClass == .compact }

    /// An iPhone in landscape is wide *and* short — unlike Mac/iPad, which are wide with plenty
    /// of vertical room — so it needs smaller everything to keep the whole wide layout, footer
    /// included, from growing taller than the screen.
    private var isCompactHeight: Bool { verticalSizeClass == .compact }

    private var currentStep: RosaryStep? {
        steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
    }

    private var progress: Double {
        steps.isEmpty ? 0 : Double(currentIndex + 1) / Double(steps.count)
    }

    private var isLastStep: Bool { steps.isEmpty || currentIndex == steps.count - 1 }

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
        VStack(spacing: 0) {
            Rectangle()
                .fill(seasonColor)
                .frame(height: 6)

            VStack(spacing: 4) {
                ProgressView(value: progress)
                if !steps.isEmpty {
                    Text("\(currentIndex + 1) of \(steps.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, isCompactHeight ? 6 : 12)

            if let step = currentStep {
                if isWide {
                    // Measures the actual room available for this row — unlike a size class, this
                    // responds to a Mac window being resized short, not just to device/orientation.
                    GeometryReader { geo in
                        wideContent(step: step, availableHeight: geo.size.height)
                    }
                } else {
                    narrowContent(step: step)
                }
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }

            Divider()

            HStack {
                Button("Back") { back() }
                    .disabled(currentIndex == 0)
                    .prosarySecondaryButtonStyle()

                Spacer()

                Button(isLastStep ? "Finish" : "Next") { next() }
                    .prosaryProminentButtonStyle()
                    .tint(.brandPrimary)
                    #if os(macOS)
                    .keyboardShortcut(.space, modifiers: [])
                    #endif
            }
            .controlSize(isCompactHeight ? .regular : .large)
            .padding(isCompactHeight ? 8 : 16)
        }
        .navigationTitle("Praying the Rosary")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
    }

    @ViewBuilder
    private func narrowContent(step: RosaryStep) -> some View {
        VStack(spacing: 12) {
            BeadProgressView(layout: beadLayout, isWide: false)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 16) {
                    mysteryImage(step: step)
                        // Ties height to width so the image is always a square, however wide the
                        // phone is; sized at 3/4 of that width so it doesn't dominate the screen.
                        .aspectRatio(1, contentMode: .fit)
                        .containerRelativeFrame(.horizontal) { length, _ in length * 0.75 }
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    textBlock(step: step)
                }
                .padding()
            }
            .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
        }
    }

    @ViewBuilder
    private func wideContent(step: RosaryStep, availableHeight: CGFloat) -> some View {
        // A landscape iPhone is wide but short (compact height), unlike Mac/iPad which have
        // vertical room to spare — everything here shrinks in that case so the footer's Back/Next
        // buttons aren't pushed below the bottom edge.
        let imageSide: CGFloat = isCompactHeight ? 190 : 320

        // A single 10-tall minor-beads column needs roughly 254pt of height; below that —
        // an iPhone in landscape, a narrow-tall iPad split, or a Mac window resized short —
        // the two-column split fits in less than half that, so it takes over instead.
        let hasRoomForSingleMinorColumn = availableHeight >= 300

        HStack(alignment: .center, spacing: isCompactHeight ? 16 : 24) {
            mysteryImage(step: step)
                .frame(width: imageSide, height: imageSide)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            // Not a ScrollView — the bead track is compact enough now (two-column minor beads,
            // matched spacing) to just fit, and this lets it center vertically against the image
            // and text beside it instead of pinning to the top the way a ScrollView's content does.
            BeadProgressView(layout: beadLayout, isWide: true, hasRoomForSingleMinorColumn: hasRoomForSingleMinorColumn)
                .frame(width: beadColumnAreaWidth(hasRoomForSingleMinorColumn: hasRoomForSingleMinorColumn))

            ScrollView {
                textBlock(step: step)
                    .padding()
            }
            .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
            .frame(maxWidth: .infinity)
        }
        .padding(.leading, isCompactHeight ? 16 : 40)
        .padding(.trailing, isCompactHeight ? 12 : 28)
        .padding(.top, isCompactHeight ? 8 : 16)
    }

    /// Deliberately not clipped/framed here — `.aspectRatio(contentMode: .fill)` reports an
    /// oversized ideal size by design (it overflows to guarantee full coverage), so clipping must
    /// happen at each call site *after* that call site's own `.frame(...)`, not inside this
    /// shared helper, or the clip bounds itself against the pre-frame oversized size instead of
    /// the intended on-screen box.
    private func mysteryImage(step: RosaryStep) -> some View {
        Image(step.imageKey)
            .resizable()
            .aspectRatio(contentMode: .fill)
            // Decorative — the title/body text alongside it already conveys the same content.
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func textBlock(step: RosaryStep) -> some View {
        VStack(spacing: 8) {
            if let subtitle = step.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(step.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.brandHeadline)
                .multilineTextAlignment(.center)

            Text(step.body)
                .font(PrayerTypography.font(languageCode: config?.languageCode, isScripture: step.isScripture))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
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
        if isLastStep {
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
            .environment(\.appServices, AppServices(presetStore: store, rosaryEngine: MockRosaryEngine(), calendar: MockLiturgicalCalendar()))
    }
}

#Preview("Wide (Mac/iPad)") {
    let config = RosaryConfig(mysterySelectionMode: .twentyMystery)
    let store = MockPresetStore(configs: [config])
    return NavigationStack {
        RosaryFlowView(configId: config.id)
            .environment(\.appServices, AppServices(presetStore: store, rosaryEngine: MockRosaryEngine(), calendar: MockLiturgicalCalendar()))
    }
    .environment(\.horizontalSizeClass, .regular)
    .frame(width: 900, height: 600)
}

#Preview("Hebrew — RTL") {
    let hebrewConfig = RosaryConfig(mysterySelectionMode: .specific, specificMysteryGroup: .glorious, languageCode: "he")
    let store = MockPresetStore(configs: [hebrewConfig])
    return NavigationStack {
        RosaryFlowView(configId: hebrewConfig.id)
            .environment(\.appServices, AppServices(presetStore: store, rosaryEngine: MockRosaryEngine(), calendar: MockLiturgicalCalendar()))
    }
}

//
//  PrayerStepFlowView.swift
//  Prosary
//
//  Shared presentation chrome for any linear prayer flow: season-color bar, progress readout
//  (a fraction + "N of M" for a bounded flow, a bare running count for an open-ended one), wide
//  (Mac/iPad/landscape-iPhone) vs narrow adaptive layout with RTL-aware scrolling text, and a
//  Back/Next-or-Finish footer. Used by RosaryFlowView (passing the bead track as its accessory)
//  and by devotions with no equivalent progress track at all (Angelus, Jesus Prayer), which pass
//  no accessory — the layout simply omits that slot rather than reserving empty space for it.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct PrayerStepFlowView: View {
  let navigationTitle: String
  let step: RosaryStep?
  /// 0-based index of `step` within the flow.
  let currentIndex: Int
  /// Total steps for a bounded flow; nil for an open-ended one, which shows a running count
  /// instead of a fraction/progress bar.
  let totalSteps: Int?
  let seasonColor: Color
  let isRightToLeft: Bool
  let languageCode: String?
  let canGoBack: Bool
  let onBack: () -> Void
  let onNext: () -> Void
  /// The bead track (Rosary) or nothing (Angelus/Jesus Prayer). Receives the same
  /// isWide/hasRoomForSingleMinorColumn flags this view already resolved for its own layout, so
  /// a caller's accessory sizes itself consistently without re-deriving them.
  var accessory: ((_ isWide: Bool, _ hasRoomForSingleMinorColumn: Bool) -> AnyView)?

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.verticalSizeClass) private var verticalSizeClass

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

  /// Matches the pre-load "no step yet" instant to "last step" so the footer doesn't flash a
  /// "Next" label a moment before content briefly reads "Finish" (imperceptible in practice,
  /// since loading is a near-instant in-memory lookup) — mirrors RosaryFlowView's original
  /// `steps.isEmpty || currentIndex == steps.count - 1`.
  private var isLastStep: Bool {
    guard step != nil else { return true }
    guard let totalSteps else { return false }
    return currentIndex >= totalSteps - 1
  }

  var body: some View {
    VStack(spacing: 0) {
      Rectangle()
        .fill(seasonColor)
        .frame(height: 6)

      progressHeader
        .padding(.horizontal)
        .padding(.top, isCompactHeight ? 6 : 12)

      if let step {
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
        Button("prayerFlow.back") { onBack() }
          .disabled(!canGoBack)
          .prosarySecondaryButtonStyle()
          // Distinguishes this step-to-step Back button from the system navigation-bar
          // back button, which also reads as plain "Back" whenever the previous screen
          // (e.g. Home) has no navigationTitle of its own to show instead.
          .accessibilityIdentifier("prayerFlowBackButton")

        Spacer()

        Button(isLastStep ? "prayerFlow.finish" : "prayerFlow.next") { onNext() }
          .prosaryProminentButtonStyle()
          .tint(seasonColor)
          .accessibilityIdentifier("prayerFlowNextButton")
          #if os(macOS)
          .keyboardShortcut(.space, modifiers: [])
          #endif
      }
      .controlSize(isCompactHeight ? .regular : .large)
      .padding(isCompactHeight ? 8 : 16)
    }
    .navigationTitle(navigationTitle)
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
  }

  @ViewBuilder
  private var progressHeader: some View {
    if step == nil {
      ProgressView(value: 0)
    } else if let totalSteps, totalSteps > 0 {
      VStack(spacing: 4) {
        ProgressView(value: Double(currentIndex + 1) / Double(totalSteps))
        Text(String(localized: "prayerFlow.progressCount", defaultValue: "\(currentIndex + 1) of \(totalSteps)"))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    } else {
      Text(String(localized: "prayerFlow.progressCountUnbounded", defaultValue: "\(currentIndex + 1)"))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private func narrowContent(step: RosaryStep) -> some View {
    VStack(spacing: 12) {
      if let accessory {
        accessory(false, true)
          .padding(.top, 8)
      }

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

      if let accessory {
        accessory(true, hasRoomForSingleMinorColumn)
      }

      // Not a ScrollView — the bead track is compact enough now (two-column minor beads,
      // matched spacing) to just fit, and this lets it center vertically against the image
      // and text beside it instead of pinning to the top the way a ScrollView's content does.
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
    resolvedImage(for: step.imageKey)
      .resizable()
      .aspectRatio(contentMode: .fill)
      // Decorative — the title/body text alongside it already conveys the same content.
      .accessibilityHidden(true)
  }

  /// Prefers a loaded .prosaryprayer pack's own image data over the asset catalog, so a devotion
  /// with a shipped pack (currently Rosary/Angelus) renders that pack's artwork; devotions
  /// without one fall through to the asset catalog exactly as before this existed.
  private func resolvedImage(for imageKey: String) -> Image {
    if let data = PrayerPackStore.imageData(for: imageKey) {
      #if canImport(UIKit)
      if let uiImage = UIImage(data: data) {
        return Image(uiImage: uiImage)
      }
      #else
      if let nsImage = NSImage(data: data) {
        return Image(nsImage: nsImage)
      }
      #endif
    }
    return Image(imageKey)
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
        .font(PrayerTypography.font(languageCode: languageCode, isScripture: step.isScripture))
        .lineSpacing(4)
    }
    .frame(maxWidth: .infinity)
  }
}

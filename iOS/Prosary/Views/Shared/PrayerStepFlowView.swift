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
  /// When set ("Pray" — the Jesus Prayer), a large round button below the text becomes the
  /// flow's one big tap target and replaces the footer's Next entirely — for a counter flow,
  /// advancing is the only action, so it deserves more than a corner button.
  var centralActionLabel: String? = nil
  /// The audio transport strip (AudioPlaybackBar), when the session has a narrated recording —
  /// same optional-slot convention as `accessory`. Rendered above the footer divider.
  var audioBar: AnyView? = nil
  /// True while that recording is actually playing: the timer auto-advance stands down, since
  /// the audio's chapters are driving the steps and two advance drivers would fight.
  var audioIsPlaying: Bool = false

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.verticalSizeClass) private var verticalSizeClass

  /// Seconds between automatic advances (hands-free praying); 0 = off. One app-wide setting
  /// shared by every flow, so a choice made in the Rosary carries into the Stations.
  @AppStorage("autoAdvanceSeconds") private var autoAdvanceSeconds = 0

  /// The v0.7 reading aid: swap the body for its transliteration when the step carries one.
  /// Deliberately sticky across steps — someone praying along in an unfamiliar script wants
  /// it on for the whole session, not per page.
  @State private var showsTransliteration = false

  private static let autoAdvanceChoices = [3, 5, 10, 15]

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
        // Measured, not size-classed: a visionOS window resizes freely while its size class
        // stays .regular, so the wide three-column layout used to squeeze until text clipped
        // (and a narrow Mac window had the same failure). Below the same 700pt breakpoint the
        // Windows port uses, the single-column phone layout takes over regardless of class.
        GeometryReader { geo in
          if isWide && geo.size.width >= 700 {
            wideContent(step: step, availableHeight: geo.size.height)
          } else {
            narrowContent(step: step, available: geo.size)
          }
        }
      } else {
        Spacer()
        ProgressView()
        Spacer()
      }

      if let audioBar {
        audioBar
          .padding(.horizontal)
          .padding(.bottom, 6)
      }

      // A counter flow's only action is its central button: a lone Back beside it competes with
      // the thing the screen exists for, and "undo one repetition" isn't worth a permanent
      // control (the navigation bar still leaves the session). Dropping the whole footer also
      // gives the prayer text back the space.
      if centralActionLabel == nil {
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
    }
    .navigationTitle(navigationTitle)
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Menu {
          Picker(String(localized: "prayerFlow.autoAdvance", defaultValue: "Auto-advance"),
                 selection: $autoAdvanceSeconds) {
            Text(String(localized: "prayerFlow.autoAdvance.off", defaultValue: "Off")).tag(0)
            ForEach(Self.autoAdvanceChoices, id: \.self) { seconds in
              Text(String(localized: "prayerFlow.autoAdvance.everySeconds",
                          defaultValue: "Every \(seconds) seconds")).tag(seconds)
            }
          }
        } label: {
          Image(systemName: autoAdvanceSeconds > 0 ? "timer.circle.fill" : "timer")
        }
        .accessibilityLabel(String(localized: "prayerFlow.autoAdvance", defaultValue: "Auto-advance"))
        .accessibilityIdentifier("autoAdvanceMenu")
      }
    }
    // Restarts whenever the step, the interval, or the loaded state changes — so tapping
    // Back/Next resets the countdown, and turning the setting off cancels it. Never fires on
    // the last step: auto-"Finish" would dismiss the whole flow mid-prayer. Suspended outright
    // while a recording plays (audioIsPlaying is part of the id, so pausing re-arms it).
    .task(id: "\(autoAdvanceSeconds)-\(currentIndex)-\(step != nil)-\(audioIsPlaying)") {
      guard autoAdvanceSeconds > 0, step != nil, !isLastStep, !audioIsPlaying else { return }
      try? await Task.sleep(for: .seconds(autoAdvanceSeconds))
      guard !Task.isCancelled else { return }
      onNext()
    }
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
  private func narrowContent(step: RosaryStep, available: CGSize) -> some View {
    // Sized from the flow's own column, measured by the GeometryReader above.
    // containerRelativeFrame resolved against the whole window instead, so on a slim Mac
    // window the square overflowed the sidebar-split column — and because the scrolling
    // VStack then took that overflowed width, the prayer text laid out against it too and
    // clipped mid-word at the column's edge. Capping against the column's *height* as well
    // keeps the body visible without scrolling when the window is short.
    let contentWidth = max(available.width - Self.narrowContentPadding * 2, 0)
    let imageSide = max(min(contentWidth * 0.75, available.height * 0.4, 340), 120)

    VStack(spacing: 12) {
      if let accessory {
        accessory(false, true)
          .padding(.top, 8)
      }

      ScrollView {
        VStack(spacing: 16) {
          mysteryImage(step: step)
            .frame(width: imageSide, height: imageSide)
            .clipShape(RoundedRectangle(cornerRadius: 16))

          textBlock(step: step)
        }
        .frame(width: contentWidth)
        .padding(Self.narrowContentPadding)
      }
    }
  }

  private static let narrowContentPadding: CGFloat = 16

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
          // A ScrollView pins its content to the top, so on a tall window (full screen on a
          // Mac) a short prayer floated level with the title while the art sat centred half a
          // screen below it. Filling the viewport centres the prayer beside the art; anything
          // longer than the viewport still scrolls.
          .frame(minHeight: availableHeight - (isCompactHeight ? 8 : 16), alignment: .center)
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.leading, isCompactHeight ? 16 : 40)
    .padding(.trailing, isCompactHeight ? 12 : 28)
    .padding(.top, isCompactHeight ? 8 : 16)
    // Full screen on a Mac is ~1700pt: without a ceiling the three columns drift to opposite
    // edges — art in one corner, prayer in the other, nothing to read as one page. Capped and
    // centred, a wider window gives the prayer more room until it has enough, then stops.
    .frame(maxWidth: 1100)
    .frame(maxWidth: .infinity)
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

      if let acclamation = step.acclamation {
        // The versicle/response is a prayer, not part of the reading — it keeps the regular
        // prayer typeface even when the body below is scripture.
        Text(bodyAttributedString(acclamation))
          .font(PrayerTypography.font(languageCode: languageCode, isScripture: false))
          .lineSpacing(4)
      }

      if let transliteration = step.transliteratedBody {
        // The side toggle Erez asked for: read the prayer in its own script, or in the
        // transliteration the author provided (e.g. Hebrew letters for Tagalog).
        HStack {
          Spacer()
          Button {
            showsTransliteration.toggle()
          } label: {
            Image(systemName: showsTransliteration ? "character.book.closed.fill" : "character.book.closed")
          }
          .buttonStyle(.borderless)
          .accessibilityLabel(String(localized: "prayerFlow.transliteration",
                                     defaultValue: "Show transliteration"))
          .accessibilityIdentifier("transliterationToggle")
        }
        // A transliteration is in a different script from its language's own, so the face has
        // to follow the text rather than the language — otherwise Syriac letters are drawn with
        // a Hebrew face that has no glyphs for them, and the toggle shows a row of tofu.
        Text(bodyAttributedString(showsTransliteration ? transliteration : step.body))
          .font(PrayerTypography.font(
            languageCode: languageCode, isScripture: step.isScripture,
            script: showsTransliteration ? PrayerTypography.script(of: transliteration) : nil))
          .lineSpacing(4)
      } else {
        Text(bodyAttributedString(step.body))
          .font(PrayerTypography.font(languageCode: languageCode, isScripture: step.isScripture))
          .lineSpacing(4)
      }

      if let centralActionLabel {
        Button(action: onNext) {
          Text(centralActionLabel)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 104, height: 104)
            .background(Circle().fill(seasonColor))
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .accessibilityIdentifier("centralActionButton")
        #if os(macOS)
        .keyboardShortcut(.space, modifiers: [])
        #endif
      }
    }
    .frame(maxWidth: .infinity)
    // Scoped to the text, never to the scrolling container: mirroring a ScrollView that sits
    // inside a NavigationSplitView detail column made SwiftUI flip its content against the
    // WINDOW's bounds rather than the column's, sliding the image and prayer text left by the
    // column's own x-origin — under the sidebar, clipped mid-word (measured: column 472pt at
    // x=148, content drawn 148pt to the left of where it belonged).
    .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
  }

  /// Prayer bodies use `**bold**` for the traditional versicle/response typographic distinction
  /// — the versicle (leader's line) stays in the body's normal weight ("roman"), the response
  /// (people's reply) is `**bold**`, with no literal "V."/"R." labels at all; the alternating
  /// style alone marks who's speaking. `.inlineOnlyPreservingWhitespace` parses that inline
  /// styling while keeping the body's own `\n` line breaks intact, unlike the default markdown
  /// parsing option, which would collapse single newlines the way prose markdown normally treats
  /// soft line breaks. Falls back to the raw string (no styling, but never a blank body) if
  /// parsing ever fails.
  private func bodyAttributedString(_ body: String) -> AttributedString {
    (try? AttributedString(markdown: body, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
      ?? AttributedString(body)
  }
}

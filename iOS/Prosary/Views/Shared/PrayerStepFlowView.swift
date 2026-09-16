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
  /// The accessory's actual wide width, for this session and available vertical space.
  var accessoryWidth: ((_ hasRoomForSingleMinorColumn: Bool) -> CGFloat)? = nil
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
  /// Session-specific controls share the title's adaptive placement with auto-advance.
  /// Compact iOS windows place them below the navigation title; wider windows use the toolbar.
  var flowActions: AnyView? = nil
  var contentBundleID: String = "rosary"
  /// Basic-prayer navigation repeats its sourced heading. Devotion and user window titles
  /// stay independent of the prayer's writing system.
  var navigationTitleIsPrayerHeading = false

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @Environment(\.prayerWindowIsModal) private var windowIsModal
  #if os(macOS)
  @Environment(\.macPrayerPresentation) private var presentation
  #endif

  private var isPresenting: Bool {
    #if os(macOS)
    presentation?.isPresenting == true
    #else
    false
    #endif
  }

  /// Seconds between automatic advances; 0 = off. Saved Mac copies supply their remembered
  /// pace, while mobile and unsaved sessions continue using the app-wide preference.
  @AppStorage("autoAdvanceSeconds") private var globalAutoAdvanceSeconds = 0
  @Environment(\.prayerAutoAdvanceSeconds) private var prayerAutoAdvanceSeconds

  private var autoAdvanceBinding: Binding<Int> {
    prayerAutoAdvanceSeconds ?? $globalAutoAdvanceSeconds
  }

  private var autoAdvanceSeconds: Int { autoAdvanceBinding.wrappedValue }

  /// A gentle tap when the step changes — tester-requested (Erez), off by default, app-wide
  /// Keyed to the step change rather than the button, so Back and a
  /// timer advance feel the same as Next; a Mac quietly does nothing with it.
  @AppStorage("hapticsOnAdvance") private var hapticsOnAdvance = false

  @ObservedObject private var typography = PrayerTypographyMonitor.shared

  private var typefaces: PrayerTypography.Typefaces { typography.typefaces }

  /// The v0.7 reading aid: swap the body for its transliteration when the step carries one.
  /// Deliberately sticky across steps — someone praying along in an unfamiliar script wants
  /// it on for the whole session, not per page.
  @State private var showsTransliteration = false
  @State private var initializedScriptLanguage: String?
  @State private var aramaicSessionScript: String?
  @State private var readingPosition = PrayerReadingPosition()

  private var usesAlternateText: Bool {
    guard let script = aramaicSessionScript, let step else { return showsTransliteration }
    return PrayerTranslations.initialTransliteration(languageCode: languageCode, body: step.body,
      alternate: step.transliteratedBody, script: script) ?? showsTransliteration
  }

  private var usesSyriacScript: Bool {
    guard let step else { return false }
    return PrayerTypography.script(of: usesAlternateText ? step.transliteratedBody ?? step.body : step.body) == .syriac
  }

  private var displayedNavigationTitle: String {
    navigationTitleIsPrayerHeading
      ? PrayerTranslations.flowTitle(navigationTitle, languageCode: languageCode,
          sourceScript: usesSyriacScript, bundleId: contentBundleID)
      : HebrewDisplayText.unpointed(navigationTitle)
  }

  private func toggleTransliteration() {
    if let script = aramaicSessionScript {
      aramaicSessionScript = script == "Syrc" ? "Hebr" : "Syrc"
    } else { showsTransliteration.toggle() }
  }

  private func applyDefaultScript() {
    let language = LanguageCatalog.fallbackChain(for: languageCode).first
    guard step != nil, initializedScriptLanguage != language else { return }
    initializedScriptLanguage = language
    aramaicSessionScript = language == "arc"
      ? (UserDefaults.standard.string(forKey: PrayerTranslations.aramaicDefaultScriptKey) == "Syrc" ? "Syrc" : "Hebr")
      : nil
  }

  private static let autoAdvanceChoices = [3, 5, 10, 15]

  /// An iPhone in landscape is wide *and* short — unlike Mac/iPad, which are wide with plenty
  /// of vertical room — so it needs smaller everything to keep the whole wide layout, footer
  /// included, from growing taller than the screen.
  private var isCompactHeight: Bool { verticalSizeClass == .compact }

  private var footerControlSize: ControlSize {
    #if os(macOS)
    .regular
    #else
    isCompactHeight ? .regular : .large
    #endif
  }

  private var showsCompactHeader: Bool {
    #if os(iOS)
    horizontalSizeClass == .compact
    #else
    false
    #endif
  }

  /// Matches the pre-load "no step yet" instant to "last step" so the footer doesn't flash a
  /// "Next" label a moment before content briefly reads "Finish" (imperceptible in practice,
  /// since loading is a near-instant in-memory lookup) — mirrors RosaryFlowView's original
  /// `steps.isEmpty || currentIndex == steps.count - 1`.
  private var isLastStep: Bool {
    guard step != nil else { return true }
    guard let totalSteps else { return false }
    return currentIndex >= totalSteps - 1
  }

  private var regularContent: some View {
    VStack(spacing: 0) {
      Rectangle()
        .fill(seasonColor)
        .frame(height: 6)

      progressHeader
        .padding(.horizontal)
        .padding(.top, isCompactHeight ? 6 : 12)

      if let step {
        // Folding, split views, and desktop windows all use this column's available space.
        // Include every mystery group when budgeting the bead track, and let artwork yield
        // width before reducing the readable prayer column.
        GeometryReader { geo in
          let layout = PrayerFlowLayout(available: geo.size, compactHeight: isCompactHeight,
            accessoryWidth: accessoryWidth?(geo.size.height >= 300))
          if layout.isWide {
            wideContent(step: step, layout: layout)
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
    }
    .prosaryNavigationBar(edge: .top) {
      if showsCompactHeader { compactHeader }
    }
    .prosaryNavigationBar(edge: .bottom) {
      // Counter flows advance through their central action and need no duplicate footer.
      if centralActionLabel == nil {
        ProsaryGlassControlGroup {
          HStack {
            Button("prayerFlow.back") { onBack() }
              .disabled(!canGoBack)
              .prosaryNavigationButtonStyle()
              // Distinguishes step-to-step Back from the system navigation-bar Back.
              .accessibilityIdentifier("prayerFlowBackButton")

            Spacer()

            Button(isLastStep ? "prayerFlow.finish" : "prayerFlow.next") { onNext() }
              .prosaryProminentNavigationButtonStyle()
              .tint(Color.accentColor)
              .disabled(step == nil)
              .accessibilityIdentifier("prayerFlowNextButton")
              #if os(macOS)
              .keyboardShortcut(.defaultAction)
              #endif
          }
          .controlSize(footerControlSize)
          .padding(isCompactHeight ? 8 : 16)
        }
      }
    }
  }

  var body: some View {
    Group {
      #if os(macOS)
      if let presentation, presentation.isPresenting {
        MacPrayerPresenterView(step: presenterStep, title: displayedNavigationTitle, currentIndex: currentIndex,
          totalSteps: totalSteps, languageCode: languageCode, canGoBack: canGoBack,
          textSize: presentation.textSize, onBack: onBack, onNext: onNext, onExit: presentation.exit,
          primaryActionLabel: isLastStep ? nil : centralActionLabel, contentBundleID: contentBundleID,
          titleIsPrayerHeading: navigationTitleIsPrayerHeading)
      } else { regularContent }
      #else
      regularContent
      #endif
    }
    .navigationTitle(showsCompactHeader ? "" : displayedNavigationTitle)
    .onAppear { applyDefaultScript() }
    .onChange(of: languageCode) { _, _ in applyDefaultScript() }
    .onChange(of: step == nil) { _, _ in applyDefaultScript() }
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      if !isPresenting {
      if showsCompactHeader {
        ToolbarItem(placement: .principal) {
          Text(displayedNavigationTitle)
            .font(navigationTitleIsPrayerHeading
              ? PrayerTypography.aramaicHeadingFont(text: displayedNavigationTitle,
                  languageCode: languageCode, typefaces: typefaces, pointSize: 17) ?? .headline
              : .headline)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("prayerFlowTitle")
        }
      } else {
        ToolbarItemGroup(placement: .primaryAction) {
          flowActions
          autoAdvanceMenu
        }
      }
      }
    }
    // Restarts whenever the step, the interval, or the loaded state changes — so tapping
    // Back/Next resets the countdown, and turning the setting off cancels it. Never fires on
    // the last step: auto-"Finish" would dismiss the whole flow mid-prayer. Suspended outright
    // while a recording plays (audioIsPlaying is part of the id, so pausing re-arms it).
    #if !os(visionOS)
    .sensoryFeedback(.impact(weight: .light), trigger: currentIndex) { _, _ in
      hapticsOnAdvance && step != nil
    }
    #endif
    .task(id: "\(autoAdvanceSeconds)-\(currentIndex)-\(step != nil)-\(audioIsPlaying)-\(windowIsModal)") {
      guard autoAdvanceSeconds > 0, step != nil, !isLastStep, !audioIsPlaying, !windowIsModal else { return }
      try? await Task.sleep(for: .seconds(autoAdvanceSeconds))
      guard !Task.isCancelled else { return }
      onNext()
    }
  }

  #if os(macOS)
  private var presenterStep: RosaryStep? {
    guard var displayed = step else { return nil }
    if usesAlternateText, let alternate = displayed.transliteratedBody { displayed.body = alternate }
    return displayed
  }
  #endif

  private var compactHeader: some View {
    // The natural-width row centers when it fits this view's actual available width. Larger
    // controls or Dynamic Type fall through to scrolling without compressing any tap target.
    ViewThatFits(in: .horizontal) {
      compactActions
        .fixedSize(horizontal: true, vertical: false)
      ScrollView(.horizontal) {
        compactActions
      }
      .scrollIndicators(.hidden)
      .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, isCompactHeight ? 0 : 4)
    .padding(.bottom, isCompactHeight ? 4 : 8)
  }

  private var compactActions: some View {
    ProsaryGlassControlGroup {
      HStack(spacing: 12) {
        flowActions
        autoAdvanceMenu
      }
      .prosaryNavigationButtonStyle()
      #if !os(macOS)
      .labelStyle(.iconOnly)
      #endif
      .controlSize(.large)
      .frame(minHeight: 44)
      .padding(.horizontal)
    }
  }

  private var autoAdvanceMenu: some View {
    Menu {
      Picker(String(localized: "prayerFlow.autoAdvance", defaultValue: "Auto-Advance", bundle: UILanguage.bundle, locale: UILanguage.locale),
             selection: autoAdvanceBinding) {
        Text(String(localized: "prayerFlow.autoAdvance.off", defaultValue: "Off", bundle: UILanguage.bundle, locale: UILanguage.locale)).tag(0)
        ForEach(Self.autoAdvanceChoices, id: \.self) { seconds in
          Text(String(localized: "prayerFlow.autoAdvance.everySeconds",
                      defaultValue: "Every \(seconds) Seconds", bundle: UILanguage.bundle, locale: UILanguage.locale)).tag(seconds)
        }
      }
    } label: {
      Label(String(localized: "prayerFlow.autoAdvance", defaultValue: "Auto-Advance", bundle: UILanguage.bundle, locale: UILanguage.locale),
            systemImage: autoAdvanceSeconds > 0 ? "timer.circle.fill" : "timer")
    }
    #if !os(macOS)
    .labelStyle(.iconOnly)
    #endif
    .accessibilityLabel(String(localized: "prayerFlow.autoAdvance", defaultValue: "Auto-Advance", bundle: UILanguage.bundle, locale: UILanguage.locale))
    .help(String(localized: "prayerFlow.autoAdvance", defaultValue: "Auto-Advance", bundle: UILanguage.bundle, locale: UILanguage.locale))
    .accessibilityIdentifier("autoAdvanceMenu")
  }

  @ViewBuilder
  private var progressHeader: some View {
    if step == nil {
      ProgressView(value: 0)
    } else if let totalSteps, totalSteps > 0 {
      VStack(spacing: 4) {
        ProgressView(value: Double(currentIndex + 1) / Double(totalSteps))
        let aramaic = PrayerTranslations.aramaicProgress(currentIndex + 1, total: totalSteps,
          languageCode: languageCode, sourceScript: usesSyriacScript)
        Text(aramaic ?? String(localized: "prayerFlow.progressCount", defaultValue: "\(currentIndex + 1) of \(totalSteps)", bundle: UILanguage.bundle, locale: UILanguage.locale))
          .accessibilityIdentifier("prayerProgressText")
          .font(aramaic.map { PrayerTypography.font(languageCode: languageCode, isScripture: false,
              text: $0, typefaces: typefaces, pointSize: 13) } ?? .caption)
          .foregroundStyle(.secondary)
      }
    } else {
      Text(String(localized: "prayerFlow.progressCountUnbounded", defaultValue: "\(currentIndex + 1)", bundle: UILanguage.bundle, locale: UILanguage.locale))
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
  private func wideContent(step: RosaryStep, layout: PrayerFlowLayout) -> some View {
    HStack(alignment: .center, spacing: layout.spacing) {
      mysteryImage(step: step)
        .frame(width: layout.wideImageSide, height: layout.wideImageSide)
        .clipShape(RoundedRectangle(cornerRadius: 16))

      if let accessory {
        accessory(true, layout.hasRoomForSingleMinorColumn)
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
          .frame(minHeight: max(0, layout.available.height - layout.topPadding), alignment: .center)
      }
      .frame(minWidth: layout.minimumTextWidth, maxWidth: .infinity)
    }
    .padding(.leading, layout.leadingPadding)
    .padding(.trailing, layout.trailingPadding)
    .padding(.top, layout.topPadding)
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
    PrayerArtworkView(imageKey: step.imageKey)
      .aspectRatio(contentMode: .fill)
      // Decorative — the title/body text alongside it already conveys the same content.
      .accessibilityHidden(true)
  }

  @ViewBuilder
  private func textBlock(step: RosaryStep) -> some View {
    VStack(spacing: 8) {
      if let subtitle = step.subtitle {
        Text(HebrewDisplayText.unpointed(subtitle))
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      let heading = PrayerTranslations.flowTitle(step.title, languageCode: languageCode,
        sourceScript: usesSyriacScript, bundleId: contentBundleID)
      Text(heading)
        .font(PrayerTypography.aramaicHeadingFont(text: heading, languageCode: languageCode,
                typefaces: typefaces, pointSize: 22) ?? .title2.weight(.semibold))
        .foregroundStyle(Color.brandHeadline)
        .multilineTextAlignment(.center)
        .accessibilityIdentifier("prayerStepTitle")

      if let acclamation = step.acclamation {
        // The versicle/response is a prayer, not part of the reading — it keeps the regular
        // prayer typeface even when the body below is scripture.
        Text(bodyAttributedString(acclamation))
          .font(PrayerTypography.font(languageCode: languageCode, isScripture: false,
                                      text: acclamation, typefaces: typefaces))
          .lineSpacing(4)
      }

      if let transliteration = step.transliteratedBody {
        // The side toggle Erez asked for: read the prayer in its own script, or in the
        // transliteration the author provided (e.g. Hebrew letters for Tagalog).
        HStack {
          Spacer()
          Button {
            toggleTransliteration()
          } label: {
            Image(systemName: usesAlternateText ? "character.book.closed.fill" : "character.book.closed")
              .prosarySpatialTarget()
              #if os(iOS)
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
              #endif
          }
          #if os(visionOS)
          .buttonStyle(.bordered)
          .buttonBorderShape(.circle)
          #else
          .buttonStyle(.borderless)
          #endif
          .accessibilityLabel(transliterationActionLabel)
          .help(transliterationActionLabel)
          .accessibilityIdentifier("transliterationToggle")
        }
        // Both original bodies and transliterations follow their actual script; imported
        // Aramaic prayers can use Syriac letters even though built-in Aramaic uses Hebrew.
        Text(bodyAttributedString(usesAlternateText ? transliteration : step.body))
          .font(PrayerTypography.font(
            languageCode: languageCode, isScripture: step.isScripture,
            text: usesAlternateText ? transliteration : step.body, typefaces: typefaces))
          .accessibilityIdentifier("prayerBodyText")
          .lineSpacing(4)
          .textSelection(.enabled)
      } else {
        Text(bodyAttributedString(step.body))
          .font(PrayerTypography.font(languageCode: languageCode, isScripture: step.isScripture,
                                      text: step.body, typefaces: typefaces))
          .accessibilityIdentifier("prayerBodyText")
          .lineSpacing(4)
          .textSelection(.enabled)
      }

      if let centralActionLabel {
        #if os(macOS)
        Button(centralActionLabel, action: onNext)
          .buttonStyle(.borderedProminent)
          .tint(Color.accentColor)
          .controlSize(.large)
          .keyboardShortcut(.defaultAction)
          .padding(.top, 12)
          .accessibilityIdentifier("centralActionButton")
        #elseif os(visionOS)
        Button(centralActionLabel, action: onNext)
          .buttonStyle(.borderedProminent)
          .tint(Color.accentColor)
          .controlSize(.extraLarge)
          .padding(.top, 12)
          .accessibilityIdentifier("centralActionButton")
        #else
        Button(action: onNext) {
          Text(centralActionLabel)
            .font(.title3.weight(.bold))
            .foregroundStyle(Color(uiColor: .systemBackground))
            .frame(width: 104, height: 104)
            .background(Circle().fill(Color.accentColor))
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .accessibilityIdentifier("centralActionButton")
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
    .background { PrayerReadingAnchor(position: readingPosition, step: currentIndex).allowsHitTesting(false) }
  }

  private var transliterationActionLabel: String {
    usesAlternateText
      ? String(localized: "prayerFlow.originalText", defaultValue: "Show Original Text", bundle: UILanguage.bundle, locale: UILanguage.locale)
      : String(localized: "prayerFlow.transliteration", defaultValue: "Show Transliteration", bundle: UILanguage.bundle, locale: UILanguage.locale)
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

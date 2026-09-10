#if os(macOS)
import AppKit
import SwiftUI

/// Presentation changes the reading surface, never the prayer's source text or step sequence.
/// Pass the selected original/transliteration in `step.body`; acclamations keep their own font.
struct MacPrayerPresenterView: View {
  static let textSizeRange = 24.0...96.0
  static let defaultTextSize = 44.0

  let step: RosaryStep?
  let title: String
  let currentIndex: Int
  let totalSteps: Int?
  let languageCode: String?
  let canGoBack: Bool
  @Binding var textSize: Double
  let onBack: () -> Void
  let onNext: () -> Void
  let onExit: () -> Void
  var primaryActionLabel: String? = nil

  @Environment(\.layoutDirection) private var interfaceDirection
  @Environment(\.colorSchemeContrast) private var contrast
  @ObservedObject private var typography = PrayerTypographyMonitor.shared
  @State private var scrollMetrics = PresenterScrollMetrics()
  @State private var hasAttachedSheet = false
  @State private var windowReference = PresenterWindowReference()

  private var pointSize: CGFloat {
    CGFloat(min(max(textSize.isFinite ? textSize : Self.defaultTextSize,
                    Self.textSizeRange.lowerBound), Self.textSizeRange.upperBound))
  }

  private var isLastStep: Bool {
    guard let totalSteps, totalSteps > 0 else { return false }
    return currentIndex >= totalSteps - 1
  }

  private var nextLabel: String {
    primaryActionLabel ?? (isLastStep
      ? String(localized: "prayerFlow.finish", defaultValue: "Finish")
      : String(localized: "prayerFlow.next", defaultValue: "Next"))
  }

  var body: some View {
    VStack(spacing: 0) {
      presenterHeader
      Divider()
      GeometryReader { geometry in
        ScrollViewReader { proxy in
          ScrollView(.vertical) {
            VStack(spacing: 0) {
              Color.clear.frame(height: 1).id("presenterTop")
              readingContent
                .frame(maxWidth: max(1, min(geometry.size.width - 48, max(720, pointSize * 22))))
                .padding(.horizontal, 24)
                .padding(.vertical, 36)
                .frame(maxWidth: .infinity, minHeight: max(geometry.size.height - 1, 0), alignment: .center)
            }
            .background {
              PresenterScrollKeyboardBridge(
                reference: windowReference,
                interfaceIsRTL: interfaceDirection == .rightToLeft,
                canGoBack: canGoBack && step != nil,
                canGoNext: step != nil,
                onBack: onBack, onNext: onNext,
                onMetrics: { scrollMetrics = $0 })
            }
          }
          .scrollIndicators(.visible)
          .accessibilityIdentifier("presenterReadingScrollView")
          .onChange(of: step?.id) { _, _ in proxy.scrollTo("presenterTop", anchor: .top) }
          .onChange(of: currentIndex) { _, _ in proxy.scrollTo("presenterTop", anchor: .top) }
        }
      }
      continuationStatus
      Divider()
      presenterFooter
    }
    .background(Color(nsColor: .textBackgroundColor))
    .foregroundStyle(.primary)
    .background {
      MacWindowFocusReader(onActivate: {}, onClose: {}, onSheetChange: { hasAttachedSheet = $0 })
        .frame(width: 0, height: 0)
    }
    .accessibilityIdentifier("macPrayerPresenter")
  }

  private var presenterHeader: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(String(localized: "presenter.mode", defaultValue: "Presenter Mode"))
          .font(.caption.weight(.semibold))
          .foregroundStyle(contrast == .increased ? Color.primary : Color.secondary)
        Text(HebrewDisplayText.unpointed(title))
          .font(.headline)
          .lineLimit(1)
          .help(HebrewDisplayText.unpointed(title))
      }
      Spacer(minLength: 8)
      HStack(spacing: 6) {
        Button { textSize = max(Self.textSizeRange.lowerBound, Double(pointSize) - 4) } label: {
          Image(systemName: "textformat.size.smaller")
        }
        .disabled(Double(pointSize) <= Self.textSizeRange.lowerBound || hasAttachedSheet)
        .help(String(localized: "presenter.smallerText", defaultValue: "Smaller Text"))
        .accessibilityLabel(String(localized: "presenter.smallerText", defaultValue: "Smaller Text"))
        .accessibilityIdentifier("presenterSmallerTextButton")

        Text(Int(pointSize), format: .number)
          .monospacedDigit()
          .frame(minWidth: 25)
          .accessibilityLabel(String(localized: "presenter.textSize", defaultValue: "Text Size"))
          .accessibilityValue(String(localized: "presenter.textSizeValue", defaultValue: "\(Int(pointSize)) points"))
          .accessibilityIdentifier("presenterTextSize")

        Button { textSize = min(Self.textSizeRange.upperBound, Double(pointSize) + 4) } label: {
          Image(systemName: "textformat.size.larger")
        }
        .disabled(Double(pointSize) >= Self.textSizeRange.upperBound || hasAttachedSheet)
        .help(String(localized: "presenter.largerText", defaultValue: "Larger Text"))
        .accessibilityLabel(String(localized: "presenter.largerText", defaultValue: "Larger Text"))
        .accessibilityIdentifier("presenterLargerTextButton")
      }
      .controlSize(.regular)

      Button { perform { windowReference.window?.toggleFullScreen(nil) } } label: {
        Image(systemName: scrollMetrics.isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
      }
      .disabled(hasAttachedSheet)
      .help(fullScreenLabel)
      .accessibilityLabel(fullScreenLabel)
      .accessibilityIdentifier("presenterFullScreenButton")

      Button { perform(onExit) } label: {
        Image(systemName: "xmark")
      }
      .keyboardShortcut(.cancelAction)
      .disabled(hasAttachedSheet)
      .help(String(localized: "presenter.exit", defaultValue: "Exit Presenter Mode"))
      .accessibilityLabel(String(localized: "presenter.exit", defaultValue: "Exit Presenter Mode"))
      .accessibilityIdentifier("presenterExitButton")
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
  }

  private var fullScreenLabel: String {
    scrollMetrics.isFullScreen
      ? String(localized: "presenter.exitFullScreen", defaultValue: "Exit Full Screen")
      : String(localized: "presenter.enterFullScreen", defaultValue: "Enter Full Screen")
  }

  @ViewBuilder private var readingContent: some View {
    if let step {
      VStack(spacing: max(pointSize * 0.5, 20)) {
        if let subtitle = step.subtitle, !subtitle.isEmpty {
          Text(HebrewDisplayText.unpointed(subtitle))
            .font(.system(size: max(17, pointSize * 0.42), weight: .medium))
            .foregroundStyle(contrast == .increased ? Color.primary : Color.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("presenterSubtitle")
        }
        if !step.title.isEmpty {
          Text(PrayerTranslations.flowTitle(step.title, languageCode: languageCode,
            sourceScript: PrayerTypography.resolvedScript(text: step.body, languageCode: languageCode) == .syriac))
            .font(.system(size: max(23, pointSize * 0.65), weight: .semibold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("presenterStepTitle")
        }
        if let acclamation = step.acclamation, !acclamation.isEmpty {
          prayerText(acclamation, isScripture: false)
            .accessibilityIdentifier("presenterAcclamationText")
        }
        prayerText(step.body, isScripture: step.isScripture)
          .accessibilityIdentifier("presenterPrayerBodyText")
      }
    } else {
      ProgressView()
        .controlSize(.large)
        .accessibilityLabel(String(localized: "presenter.loading", defaultValue: "Loading Prayer"))
    }
  }

  private func prayerText(_ source: String, isScripture: Bool) -> some View {
    let isRTL = Self.isRightToLeft(PrayerTypography.resolvedScript(text: source, languageCode: languageCode))
    return Text(Self.attributedBody(source))
      .font(presenterFont(for: source, isScripture: isScripture))
      .lineSpacing(max(8, pointSize * 0.22))
      .multilineTextAlignment(.leading)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .textSelection(.enabled)
      // Scope script direction to the text, never the scrolling container or native controls.
      .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
  }

  private var continuationStatus: some View {
    HStack {
      if scrollMetrics.moreAbove {
        Label(String(localized: "presenter.moreAbove", defaultValue: "More Above"), systemImage: "arrow.up")
      }
      Spacer()
      if scrollMetrics.moreBelow {
        Label(String(localized: "presenter.moreBelow", defaultValue: "More Below"), systemImage: "arrow.down")
      }
    }
    .font(.caption.weight(.medium))
    .foregroundStyle(contrast == .increased ? Color.primary : Color.secondary)
    .frame(height: 22)
    .padding(.horizontal, 24)
    .help(String(localized: "presenter.scrollHelp", defaultValue: "Scroll or use Page Up and Page Down to read the whole prayer."))
    .accessibilityIdentifier("presenterContinuationStatus")
  }

  private var presenterFooter: some View {
    HStack(spacing: 16) {
      Button { perform(onBack) } label: {
        Label(String(localized: "prayerFlow.back", defaultValue: "Back"), systemImage: "chevron.backward")
      }
      .disabled(!canGoBack || step == nil || hasAttachedSheet)
      .help(interfaceDirection == .rightToLeft
        ? String(localized: "presenter.backHelpRTL", defaultValue: "Previous Step (Right Arrow)")
        : String(localized: "presenter.backHelp", defaultValue: "Previous Step (Left Arrow)"))
      .accessibilityIdentifier("presenterBackButton")

      Spacer(minLength: 8)
      if let totalSteps, totalSteps > 0 {
        Text(String(localized: "prayerFlow.progressCount", defaultValue: "\(currentIndex + 1) of \(totalSteps)"))
          .monospacedDigit()
          .accessibilityIdentifier("presenterProgressText")
      } else if step != nil {
        Text(String(localized: "presenter.step", defaultValue: "Step \(currentIndex + 1)"))
          .monospacedDigit()
          .accessibilityIdentifier("presenterProgressText")
      }
      Spacer(minLength: 8)

      Button { perform(onNext) } label: {
        Label(nextLabel, systemImage: isLastStep ? "checkmark" : "chevron.forward")
      }
      .keyboardShortcut(.defaultAction)
      .disabled(step == nil || hasAttachedSheet)
      .help(isLastStep
        ? String(localized: "presenter.finishHelp", defaultValue: "Finish Prayer (Return)")
        : interfaceDirection == .rightToLeft
          ? String(localized: "presenter.nextHelpRTL", defaultValue: "Next Step (Left Arrow or Return)")
          : String(localized: "presenter.nextHelp", defaultValue: "Next Step (Right Arrow or Return)"))
      .accessibilityIdentifier("presenterNextButton")
    }
    .controlSize(.large)
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
  }

  private func perform(_ action: () -> Void) {
    guard windowReference.canAct else { return }
    action()
  }

  /// Match the ordinary reading surface's font choices at the actual selected presentation
  /// size. The ordinary helper's smaller Mac scale and fixed Arabic/Latin sizes don't apply.
  private func presenterFont(for text: String, isScripture: Bool) -> Font {
    let faces = typography.typefaces
    let script = PrayerTypography.resolvedScript(text: text, languageCode: languageCode)
    let name: String
    switch script {
    case .hebrew:
      if isScripture {
        name = switch faces.hebrewScripture {
        case PrayerTypography.TypefaceValue.stamAshkenaz: FontRegistration.PostScriptName.stamAshkenaz
        case PrayerTypography.TypefaceValue.stamSefarad: FontRegistration.PostScriptName.stamSefarad
        case PrayerTypography.TypefaceValue.rashi: FontRegistration.PostScriptName.notoRashiHebrew
        default: FontRegistration.PostScriptName.shofar
        }
      } else if faces.hebrewPrayer == PrayerTypography.TypefaceValue.sansSerif {
        return .system(size: pointSize)
      } else {
        name = faces.hebrewPrayer == PrayerTypography.TypefaceValue.davidLibre
          ? FontRegistration.PostScriptName.davidLibre : FontRegistration.PostScriptName.frankRuhlLibre
      }
    case .arabic:
      name = isScripture ? FontRegistration.PostScriptName.scheherazadeNew : FontRegistration.PostScriptName.amiri
    case .syriac:
      name = switch faces.syriac {
      case PrayerTypography.TypefaceValue.western: FontRegistration.PostScriptName.notoSansSyriacWestern
      case PrayerTypography.TypefaceValue.eastern: FontRegistration.PostScriptName.notoSansSyriacEastern
      default: FontRegistration.PostScriptName.notoSansSyriac
      }
    case .latin, .cyrillic, .greek:
      if isScripture { name = FontRegistration.PostScriptName.cardo }
      else {
        let preference = script == .latin ? faces.latinPrayer : script == .cyrillic ? faces.cyrillicPrayer : PrayerTypography.TypefaceValue.default
        return .system(size: pointSize, design: preference == PrayerTypography.TypefaceValue.sansSerif ? .default : .serif)
      }
    }
    return .custom(name, fixedSize: pointSize)
  }

  static func isRightToLeft(_ script: PrayerTypography.Script) -> Bool {
    switch script {
    case .hebrew, .arabic, .syriac: true
    case .latin, .cyrillic, .greek: false
    }
  }

  static func attributedBody(_ source: String) -> AttributedString {
    (try? AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
      ?? AttributedString(source)
  }
}

private struct PresenterScrollMetrics: Equatable {
  var moreAbove = false
  var moreBelow = false
  var isFullScreen = false
}

@MainActor private final class PresenterWindowReference {
  weak var window: NSWindow?
  var canAct: Bool {
    guard let window else { return false }
    return window.isKeyWindow && window.attachedSheet == nil && NSApp.modalWindow == nil
  }
}

/// Uses the enclosing native scroll view for paging and continuation cues. Keyboard handling
/// is confined to this presenter's key window and yields to sheets, menus and text selection.
private struct PresenterScrollKeyboardBridge: NSViewRepresentable {
  let reference: PresenterWindowReference
  let interfaceIsRTL: Bool
  let canGoBack: Bool
  let canGoNext: Bool
  let onBack: () -> Void
  let onNext: () -> Void
  let onMetrics: (PresenterScrollMetrics) -> Void

  func makeNSView(context: Context) -> ReaderView { ReaderView() }
  func updateNSView(_ view: ReaderView, context: Context) {
    view.configuration = self
    view.attachSoon()
  }
  static func dismantleNSView(_ view: ReaderView, coordinator: ()) { view.detach() }

  final class ReaderView: NSView {
    var configuration: PresenterScrollKeyboardBridge?
    private weak var scrollView: NSScrollView?
    private var observers: [NSObjectProtocol] = []
    private var eventMonitor: Any?
    private var lastMetrics = PresenterScrollMetrics()

    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); attachSoon() }
    override func layout() { super.layout(); publishMetricsSoon() }

    func attachSoon() {
      DispatchQueue.main.async { [weak self] in self?.attach() }
    }

    private func attach() {
      guard let window, let enclosingScrollView, let document = enclosingScrollView.documentView,
            let configuration else { return }
      configuration.reference.window = window
      guard scrollView !== enclosingScrollView || eventMonitor == nil else { publishMetrics(); return }
      detach()
      configuration.reference.window = window
      scrollView = enclosingScrollView
      let clip = enclosingScrollView.contentView
      clip.postsBoundsChangedNotifications = true
      document.postsFrameChangedNotifications = true
      for (name, object) in [(NSView.boundsDidChangeNotification, clip as AnyObject),
                              (NSView.frameDidChangeNotification, document as AnyObject),
                              (NSWindow.didResizeNotification, window as AnyObject),
                              (NSWindow.didEnterFullScreenNotification, window as AnyObject),
                              (NSWindow.didExitFullScreenNotification, window as AnyObject)] {
        observers.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
          MainActor.assumeIsolated { self?.publishMetricsSoon() }
        })
      }
      eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        let consumed = MainActor.assumeIsolated {
          guard let self else { return false }
          return self.handle(event) == nil
        }
        return consumed ? nil : event
      }
      publishMetrics()
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
      guard let configuration, configuration.reference.canAct, event.window === window,
            RunLoop.current.currentMode != .eventTracking,
            event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else { return event }
      if let textView = window?.firstResponder as? NSTextView,
         textView.isEditable || textView.selectedRange().length > 0 { return event }
      switch event.keyCode {
      case 116: scrollPage(forward: false); return nil // Page Up
      case 121: scrollPage(forward: true); return nil  // Page Down
      case 123, 124:
        guard !event.isARepeat else { return nil }
        let backwards = event.keyCode == (configuration.interfaceIsRTL ? 124 : 123)
        if backwards { if configuration.canGoBack { configuration.onBack() } }
        else if configuration.canGoNext { configuration.onNext() }
        return nil
      default: return event
      }
    }

    private func scrollPage(forward: Bool) {
      guard let scrollView, let document = scrollView.documentView else { return }
      let visible = scrollView.documentVisibleRect
      let distance = max(visible.height * 0.85, 1)
      let direction: CGFloat = (forward == document.isFlipped) ? 1 : -1
      let maximum = max(document.bounds.maxY - visible.height, document.bounds.minY)
      let y = min(max(visible.minY + distance * direction, document.bounds.minY), maximum)
      document.scroll(NSPoint(x: visible.minX, y: y))
      scrollView.reflectScrolledClipView(scrollView.contentView)
      publishMetrics()
    }

    private func publishMetricsSoon() {
      DispatchQueue.main.async { [weak self] in self?.publishMetrics() }
    }

    private func publishMetrics() {
      guard let scrollView, let document = scrollView.documentView else { return }
      let visible = scrollView.documentVisibleRect
      let low = visible.minY > document.bounds.minY + 2
      let high = visible.maxY < document.bounds.maxY - 2
      let metrics = PresenterScrollMetrics(moreAbove: document.isFlipped ? low : high,
                                          moreBelow: document.isFlipped ? high : low,
                                          isFullScreen: window?.styleMask.contains(.fullScreen) == true)
      guard metrics != lastMetrics else { return }
      lastMetrics = metrics
      configuration?.onMetrics(metrics)
    }

    func detach() {
      observers.forEach(NotificationCenter.default.removeObserver)
      observers = []
      if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
      eventMonitor = nil
      scrollView = nil
      configuration?.reference.window = nil
    }

    deinit {
      observers.forEach(NotificationCenter.default.removeObserver)
      if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
    }
  }
}
#endif

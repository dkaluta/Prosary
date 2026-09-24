import SwiftUI
import Combine
#if os(macOS)
import AppKit
#else
import UIKit
import GameController
#endif

/// The two preferences are deliberately independent, and have the same keys on every port.
enum PrayerKeyboardNavigation {
  static let arrowsKey = "keyboardArrowNavigationEnabled"
  static let spaceKey = "keyboardSpaceAdvanceEnabled"

  enum Key { case left, right, space, other }
  enum Action { case previous, next }

  static func action(for key: Key, arrowsEnabled: Bool, spaceEnabled: Bool,
                     interfaceIsRTL: Bool, hasModifiers: Bool, isRepeat: Bool) -> Action? {
    guard !hasModifiers, !isRepeat else { return nil }
    switch key {
    case .left where arrowsEnabled: return interfaceIsRTL ? .next : .previous
    case .right where arrowsEnabled: return interfaceIsRTL ? .previous : .next
    case .space where spaceEnabled: return .next
    default: return nil
    }
  }
}

/// A Mac always has keyboard controls. Touch devices expose them only while a hardware
/// keyboard is connected, including connection changes while Settings is already open.
@MainActor
final class PrayerKeyboardAvailability: ObservableObject {
  static let shared = PrayerKeyboardAvailability()
  @Published private(set) var isAvailable: Bool
  private var observations: [NSObjectProtocol] = []

  private init() {
    #if os(macOS)
    isAvailable = true
    #else
    isAvailable = GCKeyboard.coalesced != nil
    for (name, connected) in [(Notification.Name.GCKeyboardDidConnect, true),
                               (.GCKeyboardDidDisconnect, false)] {
      observations.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.isAvailable = connected }
      })
    }
    observations.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                               object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.isAvailable = GCKeyboard.coalesced != nil }
    })
    #endif
  }
}

struct PrayerKeyboardNavigationModifier: ViewModifier {
  var canGoBack: Bool
  var canGoNext: Bool
  var isModal: Bool
  var onBack: () -> Void
  var onNext: () -> Void
  @Environment(\.layoutDirection) private var layoutDirection
  @AppStorage(PrayerKeyboardNavigation.arrowsKey) private var arrowsEnabled = true
  @AppStorage(PrayerKeyboardNavigation.spaceKey) private var spaceEnabled = true
  #if !os(macOS)
  @ObservedObject private var keyboard = PrayerKeyboardAvailability.shared
  @FocusState private var prayerHasFocus: Bool
  @State private var windowReference = PrayerKeyboardWindowReference()
  #endif

  func body(content: Content) -> some View {
    #if os(macOS)
    content.background {
      MacPrayerKeyboardBridge(arrowsEnabled: arrowsEnabled, spaceEnabled: spaceEnabled,
        interfaceIsRTL: layoutDirection == .rightToLeft, canGoBack: canGoBack,
        canGoNext: canGoNext, isModal: isModal, onBack: onBack, onNext: onNext)
        .frame(width: 0, height: 0)
    }
    #else
    content
      .background { PrayerKeyboardWindowReader(reference: windowReference).frame(width: 0, height: 0) }
      .focusable(keyboard.isAvailable)
      .focusEffectDisabled()
      .focused($prayerHasFocus)
      .onKeyPress(keys: [.leftArrow, .rightArrow, .space], phases: [.down, .repeat]) { press in
        guard !isModal, windowReference.canAct else { return .ignored }
        let key: PrayerKeyboardNavigation.Key = press.key == .space ? .space
          : press.key == .leftArrow ? .left : .right
        let configured = key == .space ? spaceEnabled : arrowsEnabled
        guard configured, press.modifiers.intersection([.command, .control, .option, .shift]).isEmpty else { return .ignored }
        // Consume a held navigation key without racing through the prayer.
        guard press.phase == .down else { return .handled }
        guard let action = PrayerKeyboardNavigation.action(for: key, arrowsEnabled: arrowsEnabled,
          spaceEnabled: spaceEnabled, interfaceIsRTL: layoutDirection == .rightToLeft,
          hasModifiers: false, isRepeat: false) else { return .ignored }
        if action == .previous { if canGoBack { onBack() } }
        else if canGoNext { onNext() }
        return .handled
      }
      .onAppear { prayerHasFocus = keyboard.isAvailable }
      .onChange(of: keyboard.isAvailable) { _, available in prayerHasFocus = available }
    #endif
  }
}

#if os(macOS)
struct MacPrayerKeyboardBridge: NSViewRepresentable {
  var arrowsEnabled: Bool
  var spaceEnabled: Bool
  var interfaceIsRTL: Bool
  var canGoBack: Bool
  var canGoNext: Bool
  var isModal: Bool
  var onBack: () -> Void
  var onNext: () -> Void

  func makeNSView(context: Context) -> KeyboardView { KeyboardView() }
  func updateNSView(_ view: KeyboardView, context: Context) { view.configuration = self }
  static func dismantleNSView(_ view: KeyboardView, coordinator: ()) { view.detach() }

  final class KeyboardView: NSView {
    var configuration: MacPrayerKeyboardBridge?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      detach()
      guard window != nil else { return }
      monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        let handled = MainActor.assumeIsolated { self?.handle(event) ?? false }
        return handled ? nil : event
      }
    }

    /// Events are accepted only by the visible flow in their own key window. In particular,
    /// sibling prayer windows never receive an advance through a global notification.
    func handle(_ event: NSEvent) -> Bool {
      guard let configuration, let window, window.isKeyWindow, event.window === window,
            !isHiddenOrHasHiddenAncestor, !configuration.isModal, window.attachedSheet == nil,
            NSApp.modalWindow == nil, RunLoop.current.currentMode != .eventTracking,
            event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else { return false }
      if let text = window.firstResponder as? NSTextView,
         text.isEditable || text.selectedRange().length > 0 { return false }
      // Keyboard navigation and Space belong to a focused native control while it is in use.
      if window.firstResponder is NSControl { return false }
      let key: PrayerKeyboardNavigation.Key
      switch event.keyCode {
      case 123: key = .left
      case 124: key = .right
      case 49: key = .space
      default: return false
      }
      guard key == .space ? configuration.spaceEnabled : configuration.arrowsEnabled else { return false }
      guard !event.isARepeat else { return true }
      guard let action = PrayerKeyboardNavigation.action(for: key,
        arrowsEnabled: configuration.arrowsEnabled, spaceEnabled: configuration.spaceEnabled,
        interfaceIsRTL: configuration.interfaceIsRTL, hasModifiers: false, isRepeat: false) else { return false }
      if action == .previous { if configuration.canGoBack { configuration.onBack() } }
      else if configuration.canGoNext { configuration.onNext() }
      return true
    }

    func detach() {
      if let monitor { NSEvent.removeMonitor(monitor) }
      monitor = nil
    }

    deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
  }
}
#else
@MainActor
private final class PrayerKeyboardWindowReference {
  weak var window: UIWindow?

  var canAct: Bool {
    guard let window, window.isKeyWindow, window.windowScene?.activationState == .foregroundActive,
          window.rootViewController?.presentedViewController == nil else { return false }
    if let responder = firstResponder(in: window) {
      if let text = responder as? UITextView { return !text.isEditable && (text.selectedTextRange?.isEmpty ?? true) }
      if responder is UIControl || responder is any UITextInput { return false }
    }
    return true
  }

  private func firstResponder(in view: UIView) -> UIView? {
    if view.isFirstResponder { return view }
    return view.subviews.lazy.compactMap { self.firstResponder(in: $0) }.first
  }
}

private struct PrayerKeyboardWindowReader: UIViewRepresentable {
  var reference: PrayerKeyboardWindowReference
  func makeUIView(context: Context) -> WindowView { WindowView(reference: reference) }
  func updateUIView(_ view: WindowView, context: Context) {}
  final class WindowView: UIView {
    let reference: PrayerKeyboardWindowReference
    init(reference: PrayerKeyboardWindowReference) { self.reference = reference; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func didMoveToWindow() { super.didMoveToWindow(); reference.window = window }
  }
}
#endif

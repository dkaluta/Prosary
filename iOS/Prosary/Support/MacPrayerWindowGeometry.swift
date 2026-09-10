#if os(macOS)
import AppKit
import SwiftUI

/// Attach to the prayer window root. The caller supplies the library item's stable identity,
/// so changing its settings preserves geometry while a duplicated library item gets its own.
struct MacPrayerWindowGeometry: NSViewRepresentable {
  let persistenceID: String

  func makeNSView(context: Context) -> GeometryView { GeometryView() }

  func updateNSView(_ view: GeometryView, context: Context) {
    view.configure(persistenceID: persistenceID)
  }

  static func dismantleNSView(_ view: GeometryView, coordinator: ()) { view.detach() }

  final class GeometryView: NSView {
    private static var slots = PrayerWindowFrameSlots()
    private var persistenceID = ""
    private var configuredID: String?
    private weak var observedWindow: NSWindow?
    private var autosaveName: String?
    private var observers: [NSObjectProtocol] = []

    func configure(persistenceID: String) {
      self.persistenceID = persistenceID
      scheduleAttachment()
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      scheduleAttachment()
    }

    private func scheduleAttachment() {
      // SwiftUI establishes its initial content constraints first. Restoring before that can
      // have the default scene size overwrite the restored frame during the initial layout.
      DispatchQueue.main.async { [weak self] in self?.attach() }
    }

    private func attach() {
      guard let window, !persistenceID.isEmpty else { return }
      guard observedWindow !== window || configuredID != persistenceID else { return }
      detach()
      observedWindow = window
      configuredID = persistenceID
      let slot = Self.slots.claim(persistenceID: persistenceID)
      autosaveName = slot.name

      let restored = window.setFrameUsingName(slot.name)
      guard window.setFrameAutosaveName(slot.name) else {
        Self.slots.release(slot.name)
        autosaveName = nil
        return
      }
      if !restored, slot.ordinal > 1,
         let sibling = NSApp.windows.first(where: {
           $0 !== window && $0.frameAutosaveName.hasPrefix(slot.familyPrefix)
         }) {
        _ = window.cascadeTopLeft(from: NSPoint(x: sibling.frame.minX + 24, y: sibling.frame.maxY - 24))
      }
      recoverIfNeeded()

      observers.append(NotificationCenter.default.addObserver(
        forName: NSWindow.willCloseNotification, object: window, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.detach() }
      })
      observers.append(NotificationCenter.default.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.recoverIfNeeded() }
      })
    }

    private func recoverIfNeeded() {
      guard let window = observedWindow, !window.styleMask.contains(.fullScreen),
            PrayerWindowFrameRecovery.needsRecovery(window.frame, visibleFrames: NSScreen.screens.map(\.visibleFrame)),
            let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
      // AppKit handles the screen's title-bar/menu-bar constraints and the window's own
      // sizing rules. Only intervene when the restored title bar cannot be reached at all.
      window.setFrame(window.constrainFrameRect(window.frame, to: screen), display: false)
      if let autosaveName { window.saveFrame(usingName: autosaveName) }
    }

    func detach() {
      observers.forEach(NotificationCenter.default.removeObserver)
      observers = []
      if let autosaveName {
        if let window = observedWindow {
          if !window.styleMask.contains(.fullScreen) { window.saveFrame(usingName: autosaveName) }
          _ = window.setFrameAutosaveName("")
        }
        Self.slots.release(autosaveName)
      }
      observedWindow = nil
      configuredID = nil
      autosaveName = nil
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
  }
}

struct PrayerWindowFrameSlot: Equatable {
  let familyPrefix: String
  let ordinal: Int
  var name: String { "\(familyPrefix)\(ordinal)" }
}

/// Native autosave names may belong to only one live window. Stable numbered slots preserve
/// separate frames for concurrent openings and reuse the first frame after a normal close.
struct PrayerWindowFrameSlots {
  private var claimed: Set<String> = []

  mutating func claim(persistenceID: String) -> PrayerWindowFrameSlot {
    let prefix = "Prosary.Prayer.\(Data(persistenceID.utf8).base64EncodedString()).slot."
    var slot = PrayerWindowFrameSlot(familyPrefix: prefix, ordinal: 1)
    while claimed.contains(slot.name) {
      slot = PrayerWindowFrameSlot(familyPrefix: prefix, ordinal: slot.ordinal + 1)
    }
    claimed.insert(slot.name)
    return slot
  }

  mutating func release(_ name: String) { claimed.remove(name) }
}

enum PrayerWindowFrameRecovery {
  static func needsRecovery(_ frame: NSRect, visibleFrames: [NSRect]) -> Bool {
    guard !visibleFrames.isEmpty else { return false }
    guard frame.origin.x.isFinite, frame.origin.y.isFinite,
          frame.width.isFinite, frame.height.isFinite, frame.width > 0, frame.height > 0 else { return true }
    let titleBar = NSRect(x: frame.minX, y: frame.maxY - 28, width: frame.width, height: 28)
    return !visibleFrames.contains { visible in
      let reachable = titleBar.intersection(visible)
      return !reachable.isNull && reachable.width >= min(100, frame.width) && reachable.height >= 20
    }
  }
}
#endif

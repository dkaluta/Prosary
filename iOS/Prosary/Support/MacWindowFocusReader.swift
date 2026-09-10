#if os(macOS)
import AppKit
import SwiftUI

/// App activation alone cannot identify which Mac window should receive an App Intent.
struct MacWindowFocusReader: NSViewRepresentable {
  let onActivate: () -> Void
  let onClose: () -> Void
  let onSheetChange: (Bool) -> Void

  func makeNSView(context: Context) -> FocusView { FocusView() }

  func updateNSView(_ view: FocusView, context: Context) {
    view.onActivate = onActivate
    view.onClose = onClose
    view.onSheetChange = onSheetChange
  }

  final class FocusView: NSView {
    var onActivate: (() -> Void)?
    var onClose: (() -> Void)?
    var onSheetChange: ((Bool) -> Void)?
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      observers.forEach(NotificationCenter.default.removeObserver)
      observers = []
      guard let window else { return }
      observers.append(NotificationCenter.default.addObserver(
        forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.onActivate?() }
      })
      observers.append(NotificationCenter.default.addObserver(
        forName: NSWindow.willCloseNotification, object: window, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.onClose?() }
      })
      for (name, presented) in [(NSWindow.willBeginSheetNotification, true), (NSWindow.didEndSheetNotification, false)] {
        observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
          MainActor.assumeIsolated { self?.onSheetChange?(presented) }
        })
      }
      DispatchQueue.main.async { [weak self, weak window] in
        self?.onSheetChange?(window?.attachedSheet != nil)
      }
      if window.isKeyWindow {
        DispatchQueue.main.async { [weak self] in self?.onActivate?() }
      }
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
  }
}
#endif

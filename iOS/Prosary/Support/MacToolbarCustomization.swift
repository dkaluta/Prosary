#if os(macOS)
import AppKit
import SwiftUI

/// SwiftUI owns the toolbar and its stable `.toolbar(id:)` identity. AppKit supplies
/// the native display-mode menu, customization palette, and configuration persistence.
struct MacToolbarCustomization: ViewModifier {
  func body(content: Content) -> some View {
    content.background {
      MacToolbarConfigurationReader().frame(width: 0, height: 0)
    }
  }

  /// Never assign displayMode here: reopening or redrawing must preserve the user's choice.
  @MainActor static func configure(_ toolbar: NSToolbar) {
    if !toolbar.allowsUserCustomization { toolbar.allowsUserCustomization = true }
    if !toolbar.autosavesConfiguration { toolbar.autosavesConfiguration = true }
    if #available(macOS 15.0, *) {
      if !toolbar.allowsDisplayModeCustomization { toolbar.allowsDisplayModeCustomization = true }
    }
  }
}

private struct MacToolbarConfigurationReader: NSViewRepresentable {
  func makeNSView(context: Context) -> ToolbarView { ToolbarView() }
  func updateNSView(_ view: ToolbarView, context: Context) { view.configureToolbar() }

  final class ToolbarView: NSView {
    private var toolbarObservation: NSKeyValueObservation?
    private var activationObserver: NSObjectProtocol?

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      toolbarObservation?.invalidate()
      toolbarObservation = nil
      if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
      activationObserver = nil
      guard let window else { return }

      // A NavigationStack can attach or replace its toolbar after this background view
      // enters the window. Observe that public property without replacing SwiftUI's delegate.
      toolbarObservation = window.observe(\.toolbar, options: [.initial, .new]) { [weak self] _, _ in
        DispatchQueue.main.async { [weak self] in self?.configureToolbar() }
      }
      activationObserver = NotificationCenter.default.addObserver(
        forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.configureToolbar() }
      }
      configureToolbar()
    }

    func configureToolbar() {
      guard let toolbar = window?.toolbar else { return }
      MacToolbarCustomization.configure(toolbar)
    }

    deinit {
      toolbarObservation?.invalidate()
      if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
    }
  }
}
#endif

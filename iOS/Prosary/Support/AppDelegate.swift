//
//  AppDelegate.swift
//  Prosary
//
//  Without this, closing the last window on Mac leaves the app running with nothing but a menu
//  bar — the standard AppKit default for document-style apps. Prosary isn't document-based, so
//  it should just quit like a typical single-window utility app.
//
//  applicationShouldTerminateAfterLastWindowClosed alone isn't reliable for SwiftUI-managed
//  WindowGroup/Window scenes (AppKit's "last window" bookkeeping doesn't always fire for them),
//  so this also watches window-close notifications directly and terminates once none remain.
//

#if os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Foundation.Notification) {
    // The Format menu: SwiftUI's empty .textFormatting replacement empties it but leaves the
    // menu in the bar, and AppKit re-adds its contents whenever a text view gains focus — so
    // prune the menu itself, again on every activation/key-window change (the moments AppKit
    // rebuilds it). Matched by both UI localizations' titles.
    DispatchQueue.main.async { Self.removeFormatMenu() }
    for name in [NSApplication.didBecomeActiveNotification, NSWindow.didBecomeKeyNotification] {
      NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
        DispatchQueue.main.async { Self.removeFormatMenu() }
      }
    }

    NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification, object: nil, queue: .main
    ) { _ in
      // The closing window hasn't been removed from NSApp.windows yet at the moment this
      // notification fires, so defer the check to the next run-loop turn.
      DispatchQueue.main.async {
        let hasVisibleWindow = NSApp.windows.contains { $0.isVisible && !$0.isMiniaturized }
        if !hasVisibleWindow {
          NSApp.terminate(nil)
        }
      }
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  private static func removeFormatMenu() {
    let titles: Set<String> = ["Format", "עיצוב"]
    NSApp.mainMenu?.items
      .filter { titles.contains($0.title) }
      .forEach { NSApp.mainMenu?.removeItem($0) }
  }
}
#endif

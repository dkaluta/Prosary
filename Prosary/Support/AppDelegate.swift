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
}
#endif

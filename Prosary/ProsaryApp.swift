//
//  ProsaryApp.swift
//  Prosary
//
//  Created by David Kaluta on 21/07/2026.
//

import SwiftUI

@main
struct ProsaryApp: App {
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        FontRegistration.registerBundledFontsIfNeeded()
    }

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            ContentView()
                // macOS windows always report a `.regular` horizontal size class — unlike iPad,
                // there's no automatic switch to a narrower layout as the window shrinks — so the
                // window itself needs a floor to keep the wide 3-column Rosary flow layout from
                // being resized into something cramped and broken. The ceiling just keeps the
                // window from looking sparse on very large displays.
                .frame(minWidth: 760, idealWidth: 1000, maxWidth: 1400, minHeight: 700, idealHeight: 750)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Prosary") {
                    openWindow(id: "about")
                }
            }
        }

        // A separate, singleton window — reachable only from the app menu above, matching how
        // "About This Mac" and every other Mac app's About panel behaves. There's deliberately
        // no in-app button on Mac for this (see HomeView).
        Window("About Prosary", id: "about") {
            NavigationStack {
                AboutView()
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 520, height: 640)
        #else
        WindowGroup {
            ContentView()
        }
        #endif
    }
}

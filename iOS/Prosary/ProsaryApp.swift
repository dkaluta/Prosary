//
//  ProsaryApp.swift
//  Prosary
//
//  Created by David Kaluta on 21/07/2026.
//

import SwiftUI
import SwiftData

@main
struct ProsaryApp: App {
  #if os(macOS)
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  #endif
  private let presetsMenuState = PresetsMenuState()

  init() {
    FontRegistration.registerBundledFontsIfNeeded()
    UserDefaults.standard.register(defaults: ["defaultLanguageCode": LanguageCatalog.defaultCode])
    // Pull pins/order written on another device, and keep listening for later ones.
    CloudSyncedList.startSyncing()
  }

  var body: some Scene {
    #if os(macOS)
    WindowGroup {
      ContentView()
        // The prayer flow now switches to the single-column layout below 700pt of measured
        // width (same fix as visionOS), so the old 760pt floor that protected the wide
        // three-column layout is gone — a slim Mac window beside your work is a feature,
        // not a breakage. The floor only guards against absurdity.
        // 620, not 480: the Mac keeps its sidebar at every width, so the floor must
        // leave a phone-width content column beside it — 480 total squeezed the column
        // into overflow (janky slim mode, user screenshot 2026-08-03).
        //
        // Deliberately no maxWidth: a ceiling here doesn't stop the window from growing, it
        // just stops the *content* from filling it — in full screen that left the sidebar
        // floating in the middle of a black band either side. Sparseness on a large display
        // is each screen's own business (Home caps its column at 1000pt and centres it).
        .frame(minWidth: 620, idealWidth: 1000, minHeight: 560, idealHeight: 750)
        .task { await presetsMenuState.reload() }
    }
    .modelContainer(AppServices.modelContainer)
    .commands {
      PrayersCommands(presetsState: presetsMenuState)
    }

    // A separate, singleton window — reachable only from the app menu above, matching how
    // "About This Mac" and every other Mac app's About panel behaves. There's deliberately
    // no in-app button on Mac for this (see HomeView).
    Window("about.navigationTitle", id: "about") {
      NavigationStack {
        AboutView()
      }
    }
    .windowResizability(.contentSize)
    .defaultSize(width: 520, height: 640)

    Settings {
      SettingsView()
    }
    #else
    WindowGroup {
      ContentView()
        #if os(visionOS)
        // visionOS windows resize freely with no size-class change — a floor keeps the
        // prayer text from ever being squeezed into clipping (user request, v0.7).
        .frame(minWidth: 560, minHeight: 560)
        #endif
        .task { await presetsMenuState.reload() }
    }
    .modelContainer(AppServices.modelContainer)
    // iPadOS surfaces these in its menu bar (and the hardware-keyboard shortcuts HUD) — the
    // same File → Import and Prayers menus the Mac gets.
    .commands {
      PrayersCommands(presetsState: presetsMenuState)
    }
    #endif
  }
}

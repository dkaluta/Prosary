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

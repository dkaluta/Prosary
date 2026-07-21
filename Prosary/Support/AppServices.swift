//
//  AppServices.swift
//  Prosary
//
//  The backend, as the UI sees it — three protocols, injected once at the app root and read via
//  @Environment everywhere else. Currently wired to the Mock* implementations (Mocks/) so the app
//  is fully interactive today; swap these for your real implementations (see Support/Stubs) once
//  they're ready — everything downstream only ever talks to the protocols.
//
//  `shared` is the single instance used both as the environment default (SwiftUI) and directly
//  by App Intents (AppIntents/), which run outside the view hierarchy and can't read @Environment
//  — using the same instance from both keeps in-memory mock state (e.g. saved presets) consistent
//  whichever entry point touched it.
//

import SwiftUI

struct AppServices {
    var presetStore: PresetStore
    var rosaryEngine: RosaryEngine
    var calendar: LiturgicalCalendarProviding

    static let shared = AppServices(
        presetStore: MockPresetStore(),
        rosaryEngine: MockRosaryEngine(),
        calendar: MockLiturgicalCalendar()
    )
}

private struct AppServicesKey: EnvironmentKey {
    static let defaultValue = AppServices.shared
}

extension EnvironmentValues {
    var appServices: AppServices {
        get { self[AppServicesKey.self] }
        set { self[AppServicesKey.self] = newValue }
    }
}

//
//  PrayRosaryIntent.swift
//  Prosary
//

import AppIntents

struct PrayRosaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Pray the Rosary"
    static var description = IntentDescription("Opens Prosary and starts praying, using the chosen preset or your default.")
    static var openAppWhenRun = true

    @Parameter(title: "Preset", description: "Which saved preset to pray. Defaults to your default preset if not specified.")
    var preset: RosaryConfigEntity?

    @MainActor
    func perform() async throws -> some IntentResult {
        let services = AppServices.shared

        let config: RosaryConfig?
        if let preset {
            config = try await services.presetStore.get(id: preset.id)
        } else {
            config = try await services.presetStore.defaultPreset()
        }

        if let config {
            NavigationCoordinator.shared.pendingRoute = .rosary(configId: config.id)
        }

        return .result()
    }
}

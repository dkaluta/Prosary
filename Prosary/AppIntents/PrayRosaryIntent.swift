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

    let prayer: Prayer?
    if let preset {
      prayer = try await services.presetStore.get(id: preset.id)
    } else {
      prayer = try await services.presetStore.defaultPreset()
    }

    if let prayer {
      NavigationCoordinator.shared.pendingRoute = .prayer(id: prayer.id)
    }

    return .result()
  }
}

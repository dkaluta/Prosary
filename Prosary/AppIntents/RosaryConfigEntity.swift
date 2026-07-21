//
//  RosaryConfigEntity.swift
//  Prosary
//
//  Exposes saved presets as pickable entities in Shortcuts (e.g. "Pray the Rosary" → choose a
//  preset by name), backed by the same PresetStore the app itself uses.
//

import AppIntents

struct RosaryConfigEntity: AppEntity {
    let id: RosaryConfig.ID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Rosary Preset"
    static var defaultQuery = RosaryConfigEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct RosaryConfigEntityQuery: EntityQuery {
    func entities(for identifiers: [RosaryConfig.ID]) async throws -> [RosaryConfigEntity] {
        let all = try await AppServices.shared.presetStore.all()
        return all
            .filter { identifiers.contains($0.id) }
            .map { RosaryConfigEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [RosaryConfigEntity] {
        let all = try await AppServices.shared.presetStore.all()
        return all.map { RosaryConfigEntity(id: $0.id, name: $0.name) }
    }
}

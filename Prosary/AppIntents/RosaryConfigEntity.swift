//
//  RosaryConfigEntity.swift
//  Prosary
//
//  Exposes saved Rosary favorites as pickable entities in Shortcuts.
//

import AppIntents

struct RosaryConfigEntity: AppEntity {
  let id: Prayer.ID
  let name: String

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Rosary Preset"
  static var defaultQuery = RosaryConfigEntityQuery()

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)")
  }
}

struct RosaryConfigEntityQuery: EntityQuery {
  func entities(for identifiers: [Prayer.ID]) async throws -> [RosaryConfigEntity] {
    let all = try await AppServices.shared.presetStore.all()
    return all
      .filter { $0.kind == .rosary && identifiers.contains($0.id) }
      .map { RosaryConfigEntity(id: $0.id, name: $0.name) }
  }

  func suggestedEntities() async throws -> [RosaryConfigEntity] {
    let all = try await AppServices.shared.presetStore.all()
    return all
      .filter { $0.kind == .rosary }
      .map { RosaryConfigEntity(id: $0.id, name: $0.name) }
  }
}

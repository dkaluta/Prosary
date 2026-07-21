//
//  PresetStore.swift
//  Prosary
//
//  What the UI needs from the backend to save/load Rosary presets. This is the persistence
//  boundary — implement `StubPresetStore` (see Support/Stubs/StubPresetStore.swift) with your
//  real storage (file, SwiftData, CloudKit, etc).
//

import Foundation

protocol PresetStore {
    func all() async throws -> [RosaryConfig]

    /// The preset used when the user just taps "Pray" without picking one explicitly. Every
    /// store is expected to always have at least one preset, so this never returns nil.
    func defaultPreset() async throws -> RosaryConfig

    func get(id: RosaryConfig.ID) async throws -> RosaryConfig?

    /// Inserts a new preset, or updates one that already exists (matched by `config.id`). If
    /// `config.isDefault` is true, every other saved preset should have its own flag cleared.
    func save(_ config: RosaryConfig) async throws

    /// Deletes a preset. If it was the default and other presets remain, the store should
    /// promote one of them to be the new default.
    func delete(_ config: RosaryConfig) async throws
}

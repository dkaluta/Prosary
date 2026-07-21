//
//  StubPresetStore.swift
//  Prosary
//
//  Skeleton for the real PresetStore implementation — fill in with your actual persistence
//  (file, SwiftData, CloudKit, etc). Not wired into the app by default; see MockPresetStore for
//  the fully-working in-memory version used to drive Previews and interactive testing today.
//

import Foundation

struct StubPresetStore: PresetStore {
    func all() async throws -> [RosaryConfig] {
        fatalError("StubPresetStore.all() not implemented")
    }

    func defaultPreset() async throws -> RosaryConfig {
        fatalError("StubPresetStore.defaultPreset() not implemented")
    }

    func get(id: RosaryConfig.ID) async throws -> RosaryConfig? {
        fatalError("StubPresetStore.get(id:) not implemented")
    }

    func save(_ config: RosaryConfig) async throws {
        fatalError("StubPresetStore.save(_:) not implemented")
    }

    func delete(_ config: RosaryConfig) async throws {
        fatalError("StubPresetStore.delete(_:) not implemented")
    }
}

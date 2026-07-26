
//
//  StubPresetStore.swift
//  Prosary
//
//  Production PresetStore backed by SwiftData. This thin wrapper exists so AppServices.shared
//  refers to a Stub* type consistently; the real persistence work is done by SwiftDataPresetStore.
//

import Foundation
import SwiftData

struct StubPresetStore: PresetStore {
  private let inner: SwiftDataPresetStore

  init(context: ModelContext) {
    inner = SwiftDataPresetStore(context: context)
  }

  func all() async throws -> [Prayer] { try await inner.all() }
  func defaultPreset(kind: PrayerKind) async throws -> Prayer? { try await inner.defaultPreset(kind: kind) }
  func get(id: Prayer.ID) async throws -> Prayer? { try await inner.get(id: id) }
  func save(_ prayer: Prayer) async throws { try await inner.save(prayer) }
  func delete(_ prayer: Prayer) async throws { try await inner.delete(prayer) }
}

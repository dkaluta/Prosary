//
//  PresetStore.swift
//  Prosary
//
//  Persistence boundary for saved prayer favorites. Implement `StubPresetStore` (see
//  Support/Stubs/StubPresetStore.swift) with your real storage — everything downstream
//  only ever talks to this protocol.
//

import Foundation

protocol PresetStore {
  /// All saved favorites, in any order.
  func all() async throws -> [Prayer]

  /// The starred (isDefault) Rosary favorite, or the first Rosary favorite if none is
  /// starred, or nil if no Rosary favorites exist at all.
  func defaultPreset() async throws -> Prayer?

  func get(id: Prayer.ID) async throws -> Prayer?

  /// Inserts a new favorite or updates an existing one (matched by id). When
  /// `prayer.isDefault` is true, every other saved favorite of the **same kind** has its
  /// flag cleared — each kind keeps its own independent default.
  func save(_ prayer: Prayer) async throws

  /// Deletes a favorite. If it was the default and other favorites of the same kind
  /// remain, the next one is promoted to default.
  func delete(_ prayer: Prayer) async throws
}

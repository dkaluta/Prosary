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

  /// The starred (isDefault) favorite of `kind`, or the first favorite of that kind if none is
  /// starred, or nil if no favorites of that kind exist at all.
  func defaultPreset(kind: PrayerKind) async throws -> Prayer?

  func get(id: Prayer.ID) async throws -> Prayer?

  /// Inserts a new favorite or updates an existing one (matched by id). When
  /// `prayer.isDefault` is true, every other saved favorite of the **same kind** has its
  /// flag cleared — each kind keeps its own independent default.
  func save(_ prayer: Prayer) async throws

  /// Updates a saved favorite only while its id still exists. Existing-window autosaves
  /// and editors use this instead of upsert so a deleted copy cannot be recreated.
  @discardableResult
  func updateIfPresent(_ prayer: Prayer) async throws -> Bool

  /// Deletes a favorite. If it was the default and other favorites of the same kind
  /// remain, the next one is promoted to default.
  func delete(_ prayer: Prayer) async throws
}

extension PresetStore {
  /// A store without conditional-update support must decline the write. A get/save
  /// fallback could suspend between its check and insert a row deleted in the meantime.
  @discardableResult
  func updateIfPresent(_ prayer: Prayer) async throws -> Bool { false }
}

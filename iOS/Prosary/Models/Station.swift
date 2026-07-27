//
//  Station.swift
//  Prosary
//

import Foundation

/// One of the fourteen Stations of the Cross. Carries no display text of its own — title and
/// meditation are looked up by `imageKey` from the content/localization layer in the currently
/// chosen prayer language. Structurally the Stations equivalent of `Mystery`, but with no
/// `MysteryGroup` — there's only one fixed sequence, no user-chosen variant.
struct Station: Identifiable, Hashable, Codable {
  var order: Int
  /// File stem (no extension) for the illustration in the asset catalog, and the lookup key
  /// into the content layer's station translations.
  var imageKey: String

  var id: String { imageKey }
}

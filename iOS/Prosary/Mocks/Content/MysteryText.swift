//
//  MysteryText.swift
//  Prosary
//
//  The localized display text for one mystery, in a single language.
//

import Foundation

struct MysteryText: Hashable, Decodable {
  var title: String
  var fruit: String
  var description: String
  /// Optional reading aid for the Scripture description, supplied by the same source override
  /// as `description` (for example, the Peshitta in Syriac alongside Hebrew-script Aramaic).
  var transliteratedDescription: String? = nil
  /// Alternate-script metadata stays paired with its independently resolved field.
  var transliteratedTitle: String? = nil
  var transliteratedFruit: String? = nil
}

/// A bundle may contribute only the source-specific fields it owns. Keeping these optional is
/// what lets an Aramaic Peshitta description inherit a mystery's title and fruit from another
/// language without copying either into the Aramaic source file.
struct MysteryTextOverride: Hashable, Decodable {
  var title: String?
  var fruit: String?
  var description: String?
  var transliteratedDescription: String?
  var transliteratedTitle: String? = nil
  var transliteratedFruit: String? = nil

  /// Packs load in a stable order. Each field and alternate form are one provenance pair:
  /// replacing a field also replaces (or removes) its reading aid.
  func merging(_ newer: MysteryTextOverride) -> MysteryTextOverride {
    MysteryTextOverride(
      title: newer.title ?? title,
      fruit: newer.fruit ?? fruit,
      description: newer.description ?? description,
      transliteratedDescription: newer.description != nil
        ? newer.transliteratedDescription
        : transliteratedDescription,
      transliteratedTitle: newer.title != nil ? newer.transliteratedTitle : transliteratedTitle,
      transliteratedFruit: newer.fruit != nil ? newer.transliteratedFruit : transliteratedFruit)
  }
}

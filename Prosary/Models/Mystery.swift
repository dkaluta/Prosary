//
//  Mystery.swift
//  Prosary
//

import Foundation

/// One of the twenty mysteries of the Rosary. Carries no display text of its own — title,
/// fruit, and description are looked up by `imageKey` from the content/localization layer in
/// the currently chosen prayer language.
struct Mystery: Identifiable, Hashable, Codable {
    var group: MysteryGroup
    var order: Int
    /// File stem (no extension) for the illustration in the asset catalog, and the lookup key
    /// into the content layer's mystery translations.
    var imageKey: String

    var id: String { imageKey }
}

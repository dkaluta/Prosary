//
//  FavoriteDevotions.swift
//  Prosary
//
//  Which devotions are pinned to the Pray tab. Deliberately separate from `Prayer`: a Prayer is
//  a *saved configuration* (a preset), while this is only "show it on Pray", so unpinning a
//  devotion never destroys the presets underneath it. Devotion ids are the ones the rest of the
//  app already uses — "rosary", "jesusPrayer", or a bundle id.
//

import Foundation

enum FavoriteDevotions {
  private static let key = "favoriteDevotionIds"

  /// Nil until the user first pins or unpins something, which is what lets a fresh install fall
  /// back to "whatever already has a preset" instead of an empty Pray tab.
  private static var stored: [String]? {
    UserDefaults.standard.stringArray(forKey: key)
  }

  static func ids(defaultingTo implied: [String]) -> [String] {
    stored ?? implied
  }

  static func contains(_ devotionId: String, defaultingTo implied: [String]) -> Bool {
    ids(defaultingTo: implied).contains(devotionId)
  }

  /// Pins or unpins, materialising the implied set on the first explicit choice so the other
  /// devotions keep their current state rather than silently vanishing.
  static func toggle(_ devotionId: String, defaultingTo implied: [String]) {
    var current = ids(defaultingTo: implied)
    if let index = current.firstIndex(of: devotionId) {
      current.remove(at: index)
    } else {
      current.append(devotionId)
    }
    UserDefaults.standard.set(current, forKey: key)
  }

  static func pin(_ devotionId: String, defaultingTo implied: [String]) {
    guard !contains(devotionId, defaultingTo: implied) else { return }
    toggle(devotionId, defaultingTo: implied)
  }

  static func reset() {
    UserDefaults.standard.removeObject(forKey: key)
  }
}

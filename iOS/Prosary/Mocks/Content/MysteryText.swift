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
}

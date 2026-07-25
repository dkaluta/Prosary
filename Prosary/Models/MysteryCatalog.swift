//
//  MysteryCatalog.swift
//  Prosary
//
//  The fixed catalog of all twenty mysteries, grouped and ordered. This is static structural
//  data (which mystery is 3rd Sorrowful, etc.), not business logic — display text lives in the
//  content layer, keyed by each mystery's `imageKey`.
//

import Foundation

enum MysteryCatalog {
  static let joyful: [Mystery] = [
    Mystery(group: .joyful, order: 1, imageKey: "joyful_01_annunciation"),
    Mystery(group: .joyful, order: 2, imageKey: "joyful_02_visitation"),
    Mystery(group: .joyful, order: 3, imageKey: "joyful_03_nativity"),
    Mystery(group: .joyful, order: 4, imageKey: "joyful_04_presentation"),
    Mystery(group: .joyful, order: 5, imageKey: "joyful_05_finding_in_the_temple"),
  ]

  static let sorrowful: [Mystery] = [
    Mystery(group: .sorrowful, order: 1, imageKey: "sorrowful_01_agony_in_the_garden"),
    Mystery(group: .sorrowful, order: 2, imageKey: "sorrowful_02_scourging_at_the_pillar"),
    Mystery(group: .sorrowful, order: 3, imageKey: "sorrowful_03_crowning_with_thorns"),
    Mystery(group: .sorrowful, order: 4, imageKey: "sorrowful_04_carrying_of_the_cross"),
    Mystery(group: .sorrowful, order: 5, imageKey: "sorrowful_05_crucifixion"),
  ]

  static let glorious: [Mystery] = [
    Mystery(group: .glorious, order: 1, imageKey: "glorious_01_resurrection"),
    Mystery(group: .glorious, order: 2, imageKey: "glorious_02_ascension"),
    Mystery(group: .glorious, order: 3, imageKey: "glorious_03_descent_of_the_holy_spirit"),
    Mystery(group: .glorious, order: 4, imageKey: "glorious_04_assumption"),
    Mystery(group: .glorious, order: 5, imageKey: "glorious_05_coronation"),
  ]

  static let luminous: [Mystery] = [
    Mystery(group: .luminous, order: 1, imageKey: "luminous_01_baptism"),
    Mystery(group: .luminous, order: 2, imageKey: "luminous_02_wedding_at_cana"),
    Mystery(group: .luminous, order: 3, imageKey: "luminous_03_proclamation_of_the_kingdom"),
    Mystery(group: .luminous, order: 4, imageKey: "luminous_04_transfiguration"),
    Mystery(group: .luminous, order: 5, imageKey: "luminous_05_institution_of_the_eucharist"),
  ]

  static func forGroup(_ group: MysteryGroup) -> [Mystery] {
    switch group {
    case .joyful: return joyful
    case .sorrowful: return sorrowful
    case .glorious: return glorious
    case .luminous: return luminous
    }
  }

  static var all: [Mystery] { joyful + sorrowful + glorious + luminous }
}

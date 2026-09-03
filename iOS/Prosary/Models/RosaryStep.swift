//
//  RosaryStep.swift
//  Prosary
//
//  What the UI needs from the backend to render one prayer "bead" in a fully built Rosary
//  session. The backend (RosaryEngine) is responsible for producing an ordered array of these
//  from a RosaryConfig; the UI only ever reads them.
//

import Foundation

struct RosaryStep: Identifiable, Hashable {
  var id = UUID()

  /// The prominent heading, e.g. "Hail Mary (3 of 10)" or "Our Father".
  var title: String
  /// Muted decade context shown above the title, e.g. "1st Mystery — The Annunciation". Nil for steps not tied to a decade.
  var subtitle: String?
  /// The full prayer text to display/read.
  var body: String
  /// Optional acclamation (the Stations' versicle/response) rendered above the body in the
  /// regular prayer typeface — kept out of `body` so a scripture body's typeface doesn't
  /// swallow the acclamation, which is a prayer, not part of the reading.
  var acclamation: String? = nil
  /// The mystery illustrated on screen for this step, if any.
  var mystery: Mystery?
  /// True only for the mystery-announcement step, whose body is an actual quoted Bible verse rather than a traditional prayer.
  var isScripture: Bool = false
  /// Optional reading aid (v0.7, Gamaliel item 5): the body transliterated into another
  /// script (author's choice — e.g. Hebrew letters for a Tagalog prayer). The flow shows a
  /// toggle beside the text whenever this is present.
  var transliteratedBody: String? = nil
  /// True only for the Marian antiphon step (the "M" bead in the progress indicator).
  var isAntiphon: Bool = false
  /// 0-based index of this step's decade, counted globally across every mystery group in the session (0..<N for an N-decade session). Nil for steps not tied to a decade (opening, antiphon, closing, etc).
  var decadeIndex: Int?
  /// 1-10 for the ten Hail Mary steps within a decade; nil otherwise.
  var hailMaryIndexInDecade: Int?
  /// Image key for steps not tied to a Mystery but that still want a specific illustration (e.g. "crucifix" for the Sign of the Cross/Apostles' Creed, "madonna_and_child" for the antiphon) instead of the generic placeholder.
  var imageOverrideKey: String?
  /// Alternate-artwork override the engine sets on Mystery-carrying steps when the favorite's
  /// `mysteryImageStyle` selects a non-default set (e.g. "eastern_joyful_01_annunciation").
  /// A separate field rather than a rewritten `Mystery.imageKey`, because the mystery's own
  /// key is its identity and its MysteryTranslations lookup key.
  var imageVariantKey: String?

  /// A step is already a presentation model, so Hebrew heading normalization belongs here rather
  /// than in the canonical translation tables. Body/acclamation/transliteration are copied byte
  /// for byte; only the user-visible title and subtitle lose Hebrew pointing.
  init(
    id: UUID = UUID(),
    title: String,
    subtitle: String? = nil,
    body: String,
    acclamation: String? = nil,
    mystery: Mystery? = nil,
    isScripture: Bool = false,
    transliteratedBody: String? = nil,
    isAntiphon: Bool = false,
    decadeIndex: Int? = nil,
    hailMaryIndexInDecade: Int? = nil,
    imageOverrideKey: String? = nil,
    imageVariantKey: String? = nil
  ) {
    self.id = id
    self.title = HebrewDisplayText.unpointed(title)
    self.subtitle = subtitle.map(HebrewDisplayText.unpointed)
    self.body = body
    self.acclamation = acclamation
    self.mystery = mystery
    self.isScripture = isScripture
    self.transliteratedBody = transliteratedBody
    self.isAntiphon = isAntiphon
    self.decadeIndex = decadeIndex
    self.hailMaryIndexInDecade = hailMaryIndexInDecade
    self.imageOverrideKey = imageOverrideKey
    self.imageVariantKey = imageVariantKey
  }

  /// The asset-catalog image name this step should display: the alternate-artwork variant,
  /// the mystery's own image, an explicit override, or the neutral placeholder.
  var imageKey: String {
    imageVariantKey ?? mystery?.imageKey ?? imageOverrideKey ?? "cross_placeholder"
  }
}

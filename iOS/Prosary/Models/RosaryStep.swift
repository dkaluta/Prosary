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

  /// The asset-catalog image name this step should display: the mystery's own image, an
  /// explicit override, or the neutral placeholder.
  var imageKey: String {
    mystery?.imageKey ?? imageOverrideKey ?? "cross_placeholder"
  }
}

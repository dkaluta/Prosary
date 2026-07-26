//
//  BeadModels.swift
//  Prosary
//
//  Pure UI-computed presentation state for the bead progress indicator — derived from the
//  backend's RosaryStep array plus the current index, not something the backend provides.
//

import SwiftUI

enum BeadKind {
  case cross
  case decade
  case antiphon
}

enum BeadState {
  case completed
  case current
  case upcoming
}

/// One dot/glyph in the Rosary progress indicator.
struct BeadInfo: Identifiable {
  let id = UUID()
  var kind: BeadKind
  var state: BeadState
  /// True for the first bead of each group-of-5, so the UI can add extra spacing there.
  var isGroupStart: Bool = false

  var circleSize: CGFloat { kind == .antiphon ? 20 : 14 }

  var color: Color {
    switch state {
    // Not `.brandPrimary` — that dark-mode variant is deliberately a pale, low-saturation
    // pink for text legibility, which reads as barely different from the neutral gray
    // "upcoming"/"completed" beads against a near-black background. `BeadCurrent` keeps the
    // same light-mode maroon but uses a more saturated dark-mode value so the current bead
    // still visibly pops against its gray neighbors.
    case .current: return Color("BeadCurrent")
    case .completed: return Color(hex: "#6E6E6E")
    case .upcoming: return Color(hex: "#ACACAC")
    }
  }
}

/// One mystery group's column of decade beads, for the wide layout's grid (one column per
/// group in the session, e.g. 3 columns for a 15-mystery session, so a long session grows wider
/// rather than awkwardly taller). `group` is nil for devotions whose decades aren't tied to a
/// Rosary `Mystery` at all (Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet) — those
/// sessions always collapse to a single ungrouped column, since there's no group-switching to
/// grow multiple columns for in the first place.
struct BeadColumn: Identifiable {
  let id = UUID()
  var group: MysteryGroup?
  var beads: [BeadInfo]
}

/// The full computed bead layout for the current step of a Rosary session.
struct BeadLayout {
  /// Decade beads grouped into rows of 5 — like the physical layout of a rosary's Our-Father
  /// beads — for the narrow layout's wrapped horizontal grid.
  var topRows: [[BeadInfo]] = []

  /// Opening cross, for the wide layout.
  var openingCross: BeadInfo?
  /// One column per mystery group in the session, each holding that group's decade beads in
  /// order, for the wide layout's grid.
  var groupColumns: [BeadColumn] = []
  /// Marian antiphon "M" bead, for the wide layout.
  var antiphon: BeadInfo?
  /// Closing cross, for the wide layout.
  var closingCross: BeadInfo?

  /// Progress through the current decade's 10 Hail Marys.
  var bottomBeads: [BeadInfo] = []
  var showBottomBeads: Bool = false

  static func build(steps: [RosaryStep], currentIndex: Int, hasClosingCross: Bool) -> BeadLayout {
    guard steps.indices.contains(currentIndex) else { return BeadLayout() }
    let step = steps[currentIndex]

    let totalDecades = (steps.compactMap(\.decadeIndex).max()).map { $0 + 1 } ?? 0
    let firstDecadeStepIndex = steps.firstIndex { $0.decadeIndex != nil } ?? -1
    let antiphonStepIndex = steps.firstIndex { $0.isAntiphon } ?? -1

    let crossBead = BeadInfo(kind: .cross, state: currentIndex == 0 ? .current : .completed)

    var decadeBeads: [BeadInfo] = []
    for d in 0..<totalDecades {
      let state: BeadState
      if let currentDecade = step.decadeIndex {
        state = d < currentDecade ? .completed : (d == currentDecade ? .current : .upcoming)
      } else {
        // Not tied to a decade: upcoming before the first decade step, completed once
        // past all decades (antiphon/closing phase).
        state = (firstDecadeStepIndex < 0 || currentIndex < firstDecadeStepIndex) ? .upcoming : .completed
      }
      decadeBeads.append(BeadInfo(kind: .decade, state: state))
    }

    var antiphonBead: BeadInfo?
    if antiphonStepIndex >= 0 {
      let state: BeadState = currentIndex < antiphonStepIndex ? .upcoming : (currentIndex == antiphonStepIndex ? .current : .completed)
      antiphonBead = BeadInfo(kind: .antiphon, state: state)
    }

    var closingCrossBead: BeadInfo?
    if hasClosingCross {
      let closingCrossIndex = steps.count - 1
      closingCrossBead = BeadInfo(kind: .cross, state: currentIndex < closingCrossIndex ? .upcoming : .current)
    }

    // Grouped into rows of 5 decade beads, mirroring the physical layout of a rosary's
    // Our-Father beads — the opening cross rides along with the first row, and the
    // antiphon/closing-cross beads (if any) tag onto whatever's left of the last row.
    var rows: [[BeadInfo]] = [[crossBead]]
    for (index, decadeBead) in decadeBeads.enumerated() {
      rows[rows.count - 1].append(decadeBead)
      let decadeCountInRow = rows[rows.count - 1].filter { $0.kind == .decade }.count
      if decadeCountInRow % 5 == 0 && index != decadeBeads.count - 1 {
        rows.append([])
      }
    }
    if let antiphon = antiphonBead { rows[rows.count - 1].append(antiphon) }
    if let closing = closingCrossBead { rows[rows.count - 1].append(closing) }

    // One column per mystery group (in session order), each holding that group's decade
    // beads — a 15/20-mystery session grows into more columns instead of one long,
    // awkwardly-tall strip. Single-group sessions naturally collapse to one column. Decades
    // with no mystery at all (Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet — none of
    // which are "mysteries" in the Rosary sense) collapse into one shared ungrouped (nil-group)
    // column instead of being dropped entirely, which is what an earlier version of this
    // function did before it accounted for `s.mystery` being nil.
    var decadeGroupOf: [Int: MysteryGroup?] = [:]
    var decadesSeen = Set<Int>()
    for s in steps {
      guard let d = s.decadeIndex, !decadesSeen.contains(d) else { continue }
      decadesSeen.insert(d)
      // `decadeGroupOf[d] = s.mystery?.group` would be wrong here: when the right-hand side
      // evaluates to nil, plain subscript assignment on a `[Key: Value?]` dictionary REMOVES
      // the entry instead of storing an explicit `.some(nil)` — the exact case this needs to
      // preserve (mystery-less decades). `updateValue(_:forKey:)` takes a non-optional `Value`
      // parameter (here `Value` is itself `MysteryGroup?`), so it stores nil values unconditionally.
      decadeGroupOf.updateValue(s.mystery?.group, forKey: d)
    }

    var orderedGroups: [MysteryGroup?] = []
    for d in 0..<totalDecades {
      if let group = decadeGroupOf[d], !orderedGroups.contains(group) {
        orderedGroups.append(group)
      }
    }

    var groupColumns = orderedGroups.map { BeadColumn(group: $0, beads: []) }
    for d in 0..<totalDecades {
      guard let group = decadeGroupOf[d], let columnIndex = orderedGroups.firstIndex(of: group) else { continue }
      groupColumns[columnIndex].beads.append(decadeBeads[d])
    }

    guard let decadeIndex = step.decadeIndex else {
      return BeadLayout(
        topRows: rows, openingCross: crossBead, groupColumns: groupColumns,
        antiphon: antiphonBead, closingCross: closingCrossBead,
        bottomBeads: [], showBottomBeads: false)
    }

    let decadeStepIndices = steps.indices.filter {
      steps[$0].decadeIndex == decadeIndex && steps[$0].hailMaryIndexInDecade != nil
    }
    guard let firstHailMaryIndex = decadeStepIndices.min(), let lastHailMaryIndex = decadeStepIndices.max() else {
      return BeadLayout(
        topRows: rows, openingCross: crossBead, groupColumns: groupColumns,
        antiphon: antiphonBead, closingCross: closingCrossBead,
        bottomBeads: [], showBottomBeads: false)
    }

    // Hail-Marys-per-decade isn't always 10 (Seven Sorrows uses 7) — derive it from the
    // session's own step data instead of hardcoding, so this stays correct for every devotion.
    let hailMarysPerDecade = steps.compactMap(\.hailMaryIndexInDecade).max() ?? 10

    var bottom: [BeadInfo] = []
    for h in 1...hailMarysPerDecade {
      let state: BeadState
      if currentIndex < firstHailMaryIndex {
        state = .upcoming
      } else if currentIndex > lastHailMaryIndex {
        state = .completed
      } else if let current = step.hailMaryIndexInDecade {
        state = h < current ? .completed : (h == current ? .current : .upcoming)
      } else {
        state = .upcoming
      }
      bottom.append(BeadInfo(kind: .decade, state: state, isGroupStart: h > 1 && (h - 1) % 5 == 0))
    }

    return BeadLayout(
      topRows: rows, openingCross: crossBead, groupColumns: groupColumns,
      antiphon: antiphonBead, closingCross: closingCrossBead,
      bottomBeads: bottom, showBottomBeads: true)
  }

  /// A single spoken summary of where the beads currently show progress — the dots themselves
  /// carry no individual meaning to VoiceOver, so the whole track is exposed as one element
  /// with this label instead of dozens of unlabeled circles.
  var accessibilityDescription: String {
    if let closingCross, closingCross.state == .current {
      return "Closing sign of the cross"
    }
    if let antiphon, antiphon.state == .current {
      return "Marian antiphon"
    }

    let decadeBeads = groupColumns.flatMap(\.beads)
    if let currentDecade = decadeBeads.firstIndex(where: { $0.state == .current }) {
      var description = "Decade \(currentDecade + 1) of \(decadeBeads.count)"
      if showBottomBeads, let currentHailMary = bottomBeads.firstIndex(where: { $0.state == .current }) {
        description += ", Hail Mary \(currentHailMary + 1) of \(bottomBeads.count)"
      }
      return description
    }

    if let openingCross, openingCross.state == .current {
      return "Opening sign of the cross"
    }

    // Not on a decade, the opening cross, the antiphon, or the closing cross — one of the
    // closing steps between the last decade and the closing cross (e.g. Franciscan Crown's/Seven
    // Sorrows' extra closing Hail Marys and closing prayer) if every decade bead already reads
    // completed, otherwise the pre-decade opening prayers.
    if !decadeBeads.isEmpty && decadeBeads.allSatisfy({ $0.state == .completed }) {
      return "Closing prayers"
    }

    return "Opening prayers"
  }
}

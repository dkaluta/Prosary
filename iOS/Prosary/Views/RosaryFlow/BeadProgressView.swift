//
//  BeadProgressView.swift
//  Prosary
//
//  The two-part bead progress indicator: a "major beads" track (opening cross, one bead per
//  decade grouped in stacks, the Marian antiphon's "M" bead, and a closing cross) and a "minor
//  beads" row/column for progress through the current decade's 10 Hail Marys.
//
//  On narrow width (iPhone, or a compact-width iPad/Mac window) the major beads wrap into rows
//  of 5 and the minor beads sit in one horizontal row. On regular width (Mac, wide iPad, Vision)
//  there's more vertical room, so both become a single taller vertical track instead.
//

import SwiftUI

/// The single gap used everywhere in the major/minor bead tracks, so cross-to-decade,
/// decade-to-decade, and decade-to-antiphon gaps all read as one consistent rhythm.
private let beadSpacing: CGFloat = 6

private struct MajorBeadsNarrowView: View {
  let rows: [[BeadInfo]]

  var body: some View {
    VStack(spacing: beadSpacing) {
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        HStack(spacing: beadSpacing) {
          ForEach(row) { bead in
            BeadDotView(bead: bead)
          }
        }
      }
    }
  }
}

/// One column per mystery group, each a plain vertical stack of that group's decade beads — a
/// 15/20-mystery session grows wider (more columns) rather than one long, awkwardly-tall strip.
private struct GroupColumnsGridView: View {
  let columns: [BeadColumn]

  var body: some View {
    HStack(alignment: .top, spacing: beadSpacing) {
      ForEach(columns) { column in
        VStack(spacing: beadSpacing) {
          ForEach(column.beads) { bead in
            BeadDotView(bead: bead)
          }
        }
      }
    }
  }
}

private struct MinorBeadsRowView: View {
  let beads: [BeadInfo]

  var body: some View {
    HStack(spacing: beadSpacing) {
      ForEach(beads) { bead in
        BeadDotView(bead: bead)
          // A single extra-wide gap marks the group-of-5 boundary, instead of extra
          // space on both sides isolating that one bead.
          .padding(.leading, bead.isGroupStart ? beadSpacing : 0)
      }
    }
  }
}

private struct MinorBeadsColumnView: View {
  let beads: [BeadInfo]

  var body: some View {
    VStack(spacing: beadSpacing) {
      ForEach(beads) { bead in
        BeadDotView(bead: bead)
      }
    }
  }
}

/// Splits the 10 minor beads into two 5-bead columns (matching the group-of-5 boundary already
/// encoded in `isGroupStart`) instead of one 10-tall column — half the height, for when there
/// isn't enough vertical room for the single tall column (an iPhone in landscape, or a Mac window
/// resized short).
private struct MinorBeadsTwoColumnView: View {
  let beads: [BeadInfo]

  private var columns: [[BeadInfo]] {
    let half = (beads.count + 1) / 2
    return [Array(beads.prefix(half)), Array(beads.dropFirst(half))]
  }

  var body: some View {
    HStack(alignment: .top, spacing: beadSpacing) {
      ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
        VStack(spacing: beadSpacing) {
          ForEach(column) { bead in
            BeadDotView(bead: bead)
          }
        }
      }
    }
  }
}

struct BeadProgressView: View {
  let layout: BeadLayout
  let isWide: Bool
  /// Whether there's enough vertical room for the minor beads' single 10-tall column. Ignored
  /// when `isWide` is false. Defaults to `true` (Mac/iPad's usual case) for call sites that
  /// don't measure their available height.
  var hasRoomForSingleMinorColumn: Bool = true

  var body: some View {
    Group {
      if isWide {
        // Minor beads sit beside the major-beads column rather than stacked below it —
        // that keeps the whole track's height pinned to the major-beads column alone, so
        // it still fits a short, compact-height window (an iPhone in landscape) instead of
        // growing taller than the screen. Centered rather than top-aligned, since the
        // minor beads are usually shorter than the major-beads block.
        HStack(alignment: .center, spacing: beadSpacing) {
          VStack(spacing: beadSpacing) {
            if let cross = layout.openingCross {
              BeadDotView(bead: cross)
            }
            GroupColumnsGridView(columns: layout.groupColumns)
            if let antiphon = layout.antiphon {
              BeadDotView(bead: antiphon)
            }
            if let closing = layout.closingCross {
              BeadDotView(bead: closing)
            }
          }

          if layout.showBottomBeads {
            Divider().padding(.horizontal, 4)
            if hasRoomForSingleMinorColumn {
              MinorBeadsColumnView(beads: layout.bottomBeads)
            } else {
              MinorBeadsTwoColumnView(beads: layout.bottomBeads)
            }
          }
        }
      } else {
        VStack(spacing: beadSpacing) {
          MajorBeadsNarrowView(rows: layout.topRows)
          if layout.showBottomBeads {
            MinorBeadsRowView(beads: layout.bottomBeads)
          }
        }
      }
    }
    // The individual dots carry no meaning of their own to VoiceOver — expose the whole
    // track as a single element with a spoken summary instead of dozens of unlabeled circles.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("beadTrack.accessibilityLabel")
    .accessibilityValue(layout.accessibilityDescription)
  }
}

#Preview("Narrow — 5 decades") {
  let steps = PrayerEngine().buildSteps(for: Prayer(rosary: RosaryOptions(mysterySelectionMode: .specific, specificMysteryGroup: .joyful)))
  let layout = BeadLayout.build(steps: steps, currentIndex: steps.count / 2, hasClosingCross: true)
  BeadProgressView(layout: layout, isWide: false)
    .padding()
}

#Preview("Narrow — 20 decades (wraps)") {
  let steps = PrayerEngine().buildSteps(for: Prayer(rosary: RosaryOptions(mysterySelectionMode: .twentyMystery)))
  let layout = BeadLayout.build(steps: steps, currentIndex: steps.count - 5, hasClosingCross: true)
  BeadProgressView(layout: layout, isWide: false)
    .padding()
    .frame(width: 350)
}

#Preview("Wide — 5 decades, single minor column") {
  let steps = PrayerEngine().buildSteps(for: Prayer(rosary: RosaryOptions(mysterySelectionMode: .specific, specificMysteryGroup: .sorrowful)))
  let layout = BeadLayout.build(steps: steps, currentIndex: steps.count / 3, hasClosingCross: true)
  BeadProgressView(layout: layout, isWide: true)
    .padding()
}

#Preview("Wide — 5 decades, split minor columns (short window)") {
  let steps = PrayerEngine().buildSteps(for: Prayer(rosary: RosaryOptions(mysterySelectionMode: .specific, specificMysteryGroup: .sorrowful)))
  let layout = BeadLayout.build(steps: steps, currentIndex: steps.count / 3, hasClosingCross: true)
  BeadProgressView(layout: layout, isWide: true, hasRoomForSingleMinorColumn: false)
    .padding()
}

#Preview("Wide — 20 decades") {
  let steps = PrayerEngine().buildSteps(for: Prayer(rosary: RosaryOptions(mysterySelectionMode: .twentyMystery)))
  let layout = BeadLayout.build(steps: steps, currentIndex: steps.count / 2, hasClosingCross: true)
  ScrollView {
    BeadProgressView(layout: layout, isWide: true)
      .padding()
  }
}

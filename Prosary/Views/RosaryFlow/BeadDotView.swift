//
//  BeadDotView.swift
//  Prosary
//

import SwiftUI

struct BeadDotView: View {
  let bead: BeadInfo

  var body: some View {
    ZStack {
      switch bead.kind {
      case .cross:
        CrossShape()
          .fill(bead.color)
          .frame(width: 13, height: 17)
      case .decade:
        Circle()
          .fill(bead.color)
          .frame(width: bead.circleSize, height: bead.circleSize)
      case .antiphon:
        Circle()
          .fill(bead.color)
          .frame(width: bead.circleSize, height: bead.circleSize)
        Text("M")
          .font(.system(.caption2, weight: .bold))
          .foregroundStyle(.white)
      }
    }
    .frame(width: 20, height: 20)
  }
}

#Preview {
  HStack {
    BeadDotView(bead: BeadInfo(kind: .cross, state: .completed))
    BeadDotView(bead: BeadInfo(kind: .decade, state: .completed))
    BeadDotView(bead: BeadInfo(kind: .decade, state: .current))
    BeadDotView(bead: BeadInfo(kind: .decade, state: .upcoming))
    BeadDotView(bead: BeadInfo(kind: .antiphon, state: .upcoming))
    BeadDotView(bead: BeadInfo(kind: .cross, state: .upcoming))
  }
  .padding()
}

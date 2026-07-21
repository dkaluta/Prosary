//
//  CrossShape.swift
//  Prosary
//
//  A simple Latin cross, drawn directly rather than via the "cross.fill" SF Symbol — that symbol's
//  glyph isn't horizontally centered within its own bounding box the way a Circle is, which threw
//  off alignment against the decade beads in the same column. A hand-drawn shape is centered by
//  construction.
//

import SwiftUI

struct CrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        let armThickness = rect.width * 0.34
        let horizontalBarY = rect.minY + rect.height * 0.22

        var path = Path()
        path.addRect(CGRect(x: rect.midX - armThickness / 2, y: rect.minY, width: armThickness, height: rect.height))
        path.addRect(CGRect(x: rect.minX, y: horizontalBarY, width: rect.width, height: armThickness))
        return path
    }
}

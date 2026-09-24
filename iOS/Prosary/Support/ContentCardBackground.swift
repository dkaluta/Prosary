//
//  ContentCardBackground.swift
//  Prosary
//

import SwiftUI

extension View {
  /// Cards belong to the scrolling content layer. Keep their fill opaque on iPhone and Mac;
  /// the spatial window uses a standard material to distinguish content groups within glass.
  @ViewBuilder
  func prosaryContentCardBackground(cornerRadius: CGFloat = 14) -> some View {
    #if os(visionOS)
    background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    #elseif os(macOS)
    background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: cornerRadius))
    #else
    background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: cornerRadius))
    #endif
  }
}

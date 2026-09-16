import SwiftUI

extension View {
  /// Custom visionOS controls need enough room for both gaze and direct touch.
  /// Apply to the label so the Button's interaction region includes the space.
  @ViewBuilder
  func prosarySpatialTarget(alignment: Alignment = .center) -> some View {
    #if os(visionOS)
    self
      .frame(minWidth: 60, minHeight: 60, alignment: alignment)
      .contentShape(Rectangle())
    #else
    self
    #endif
  }

  /// Plain content buttons opt back into the system's private, gaze-driven feedback.
  /// Keep its rounded highlight on the actionable surface, never the reading text.
  @ViewBuilder
  func prosarySpatialHoverEffect<S: Shape>(in shape: S) -> some View {
    #if os(visionOS)
    self
      .contentShape(.hoverEffect, shape)
      .hoverEffect(.highlight)
    #else
    self
    #endif
  }
}

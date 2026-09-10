import SwiftUI

extension View {
  /// Lists keep their native arrow-key selection and invoke the selected row with Return.
  @ViewBuilder
  func macListActivation(perform action: @escaping () -> Bool) -> some View {
    #if os(macOS)
    onKeyPress(.return) { action() ? .handled : .ignored }
    #else
    self
    #endif
  }
}

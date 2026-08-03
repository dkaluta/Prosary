//
//  GlassButtonStyles.swift
//  Prosary
//
//  Liquid Glass button styles, with a fallback to the pre-Liquid-Glass bordered styles so the app
//  still builds and looks right against the iOS 17 / macOS 14 minimum deployment target.
//

import SwiftUI

extension View {
  @ViewBuilder
  func prosaryProminentButtonStyle() -> some View {
    #if os(visionOS)
    self.buttonStyle(.borderedProminent)
    #else
    if #available(iOS 26.0, macOS 26.0, *) {
      self.buttonStyle(.glassProminent)
    } else {
      self.buttonStyle(.borderedProminent)
    }
    #endif
  }

  @ViewBuilder
  func prosarySecondaryButtonStyle() -> some View {
    #if os(visionOS)
    self.buttonStyle(.bordered)
    #else
    if #available(iOS 26.0, macOS 26.0, *) {
      self.buttonStyle(.glass)
    } else {
      self.buttonStyle(.bordered)
    }
    #endif
  }
}

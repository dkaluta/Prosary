//
//  GlassButtonStyles.swift
//  Prosary
//
//  Liquid Glass belongs to navigation above content. Inline actions use standard button
//  styles; native toolbars and presentations supply their own materials. visionOS keeps its
//  spatial system controls rather than adopting the iOS/macOS Liquid Glass treatment.
//

import SwiftUI

extension View {
  @ViewBuilder
  func prosaryProminentNavigationButtonStyle() -> some View {
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
  func prosaryNavigationButtonStyle() -> some View {
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

  /// Register custom navigation with the system scroll-edge treatment on supported systems.
  @ViewBuilder
  func prosaryNavigationBar<Bar: View>(edge: VerticalEdge, @ViewBuilder content: () -> Bar) -> some View {
    #if os(visionOS)
    self.safeAreaInset(edge: edge, spacing: 0, content: content)
    #else
    if #available(iOS 26.0, macOS 26.0, *) {
      self.safeAreaBar(edge: edge, spacing: 0, content: content)
    } else {
      self.safeAreaInset(edge: edge, spacing: 0, content: content)
    }
    #endif
  }
}

/// Group neighboring glass controls without placing another glass surface behind them.
struct ProsaryGlassControlGroup<Content: View>: View {
  var spacing: CGFloat = 12
  @ViewBuilder var content: () -> Content

  var body: some View {
    #if os(visionOS)
    content()
    #else
    if #available(iOS 26.0, macOS 26.0, *) {
      GlassEffectContainer(spacing: spacing, content: content)
    } else {
      content()
    }
    #endif
  }
}

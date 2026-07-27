//
//  Color+Hex.swift
//  Prosary
//

import SwiftUI

extension Color {
  init(hex: String) {
    var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexString = hexString.replacingOccurrences(of: "#", with: "")

    var value: UInt64 = 0
    Scanner(string: hexString).scanHexInt64(&value)

    let r = Double((value >> 16) & 0xFF) / 255
    let g = Double((value >> 8) & 0xFF) / 255
    let b = Double(value & 0xFF) / 255

    self.init(red: r, green: g, blue: b)
  }

  /// Returns a `Color` that resolves to different hex values in light vs. dark mode.
  static func adaptive(light: String, dark: String) -> Color {
    #if canImport(UIKit)
    Color(uiColor: UIColor(dynamicProvider: { trait in
      trait.userInterfaceStyle == .dark
        ? UIColor(Color(hex: dark))
        : UIColor(Color(hex: light))
    }))
    #else
    Color(nsColor: NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(Color(hex: dark))
        : NSColor(Color(hex: light))
    })
    #endif
  }
}

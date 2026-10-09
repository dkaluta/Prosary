import SwiftUI
import XCTest
@testable import Prosary

@MainActor
final class AppColorTests: XCTestCase {
  func testMissingAndUnknownChoicesUseMaryBlue() {
    XCTAssertEqual(AppColor.resolved(nil), .blue)
    XCTAssertEqual(AppColor.resolved(""), .blue)
    XCTAssertEqual(AppColor.resolved("future-color"), .blue)
    XCTAssertEqual(AppColor.blue.lightHex, "#1768AC")
    XCTAssertNil(AppColor.blue.alternateIconName)
  }

  func testEveryPaletteChoiceHasItsOwnBundledIconAndReadableAccent() {
    XCTAssertEqual(AppColor.allCases.map(\.rawValue), ["blue", "green", "red", "purple", "rose", "white", "gold"])
    XCTAssertEqual(Set(AppColor.allCases.compactMap(\.alternateIconName)).count, 6)
    for color in AppColor.allCases {
      XCTAssertEqual(AppColor.resolved(color.rawValue), color)
      #if os(macOS)
      XCTAssertNotNil(NSImage(named: color.previewAssetName), color.rawValue)
      #else
      XCTAssertNotNil(UIImage(named: color.previewAssetName), color.rawValue)
      #endif
      XCTAssertGreaterThanOrEqual(contrast(color.lightHex, "#FFFFFF"), 4.5, color.rawValue)
      XCTAssertGreaterThanOrEqual(contrast(color.darkHex, "#1C1C1E"), 4.5, color.rawValue)
    }
    XCTAssertNotEqual(AppColor.white.lightHex, "#FFFFFF", "The white icon needs a readable gold accent in the interface")
  }

  #if os(macOS)
  func testMacAccentUsesTheSystemColorAndMarianMulticolorDefault() throws {
    XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "NSAccentColorName") as? String, "AccentColor")
    let actual = try XCTUnwrap(NSColor(Color.appAccent).usingColorSpace(.deviceRGB))
    let system = try XCTUnwrap(NSColor.controlAccentColor.usingColorSpace(.deviceRGB))
    XCTAssertEqual(actual.redComponent, system.redComponent, accuracy: 0.001)
    XCTAssertEqual(actual.greenComponent, system.greenComponent, accuracy: 0.001)
    XCTAssertEqual(actual.blueComponent, system.blueComponent, accuracy: 0.001)
    XCTAssertEqual(Color.appAccent, Color.appAccent, "AppKit bridges must recognize the semantic accent across calls")

    try XCTUnwrap(NSAppearance(named: .aqua)).performAsCurrentDrawingAppearance {
      let fallback = NSColor(named: "AccentColor")!.usingColorSpace(.deviceRGB)!
      let blue = NSColor(AppColor.blue.color).usingColorSpace(.deviceRGB)!
      XCTAssertEqual(fallback.redComponent, blue.redComponent, accuracy: 0.001)
      XCTAssertEqual(fallback.greenComponent, blue.greenComponent, accuracy: 0.001)
      XCTAssertEqual(fallback.blueComponent, blue.blueComponent, accuracy: 0.001)
    }
  }

  func testMacBrandingKeepsTheDefaultIconRegardlessOfStoredPalette() {
    for color in AppColor.allCases {
      XCTAssertEqual(AppColor.appearanceChoice(color.rawValue), .blue)
      XCTAssertNil(color.dockIconAssetName(isDark: true), color.rawValue)
      XCTAssertNil(color.dockIconAssetName(isDark: false), color.rawValue)
    }
  }
  #endif

  #if os(iOS)
  func testSavedMobilePaletteChoicesRemainEffective() {
    for color in AppColor.allCases {
      XCTAssertEqual(AppColor.appearanceChoice(color.rawValue), color)
    }
  }

  func testEveryAlternateIconIsDeclaredForIPhoneAndIPad() throws {
    XCTAssertTrue(UIApplication.shared.supportsAlternateIcons)
    let deviceFamilies = try XCTUnwrap(Bundle.main.infoDictionary?["UIDeviceFamily"] as? [Int])
    XCTAssertTrue(deviceFamilies.contains(1))
    XCTAssertTrue(deviceFamilies.contains(2))
    // Icon Composer emits the shared dictionary for both device families. If a separate
    // iPad override is introduced, it must retain the same complete set of choices.
    let keys = ["CFBundleIcons"] + (Bundle.main.infoDictionary?["CFBundleIcons~ipad"] == nil ? [] : ["CFBundleIcons~ipad"])
    for key in keys {
      let icons = try XCTUnwrap(Bundle.main.infoDictionary?[key] as? [String: Any], key)
      let alternates = try XCTUnwrap(icons["CFBundleAlternateIcons"] as? [String: Any], key)
      XCTAssertEqual(Set(alternates.keys), Set(AppColor.allCases.compactMap(\.alternateIconName)), key)
    }
  }
  #endif

  private func contrast(_ first: String, _ second: String) -> Double {
    func luminance(_ hex: String) -> Double {
      let value = UInt32(hex.dropFirst(), radix: 16)!
      let components = [16, 8, 0].map { shift -> Double in
        let channel = Double((value >> shift) & 255) / 255
        return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
      }
      return zip(components, [0.2126, 0.7152, 0.0722]).reduce(0) { $0 + $1.0 * $1.1 }
    }
    let a = luminance(first), b = luminance(second)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)
  }
}

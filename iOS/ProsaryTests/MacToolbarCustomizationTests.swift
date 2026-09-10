#if os(macOS)
import AppKit
import XCTest
@testable import Prosary

@MainActor
final class MacToolbarCustomizationTests: XCTestCase {
  func testConfigurationEnablesNativeCustomizationWithoutReplacingDisplayMode() {
    let toolbar = NSToolbar(identifier: "Prosary.ToolbarTests.\(UUID().uuidString)")
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    if #available(macOS 15.0, *) { toolbar.allowsDisplayModeCustomization = false }

    for mode in [NSToolbar.DisplayMode.iconAndLabel, .iconOnly, .labelOnly] {
      toolbar.displayMode = mode
      MacToolbarCustomization.configure(toolbar)
      MacToolbarCustomization.configure(toolbar)
      XCTAssertEqual(toolbar.displayMode, mode)
      XCTAssertTrue(toolbar.allowsUserCustomization)
      XCTAssertTrue(toolbar.autosavesConfiguration)
      if #available(macOS 15.0, *) { XCTAssertTrue(toolbar.allowsDisplayModeCustomization) }
    }
    toolbar.autosavesConfiguration = false
  }
}
#endif

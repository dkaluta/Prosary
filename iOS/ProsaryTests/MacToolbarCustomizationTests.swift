#if os(macOS)
import AppKit
import XCTest
@testable import Prosary

@MainActor
final class MacToolbarCustomizationTests: XCTestCase {
  func testConfigurationEnablesNativeCustomizationWithoutReplacingDisplayMode() {
    for identifier in ["Prosary.Library.Toolbar", "Prosary.Prayer.Toolbar"] {
      // Never write autosaved configurations under the user's actual toolbar identities.
      let toolbar = ConfigurationTrackingToolbar(identifier: NSToolbar.Identifier(identifier))
      for mode in [NSToolbar.DisplayMode.iconAndLabel, .iconOnly, .labelOnly] {
        toolbar.displayMode = mode
        MacToolbarCustomization.configure(toolbar)
        let writes = toolbar.configurationWrites
        MacToolbarCustomization.configure(toolbar)
        XCTAssertEqual(toolbar.displayMode, mode)
        XCTAssertTrue(toolbar.allowsUserCustomization)
        XCTAssertTrue(toolbar.autosavesConfiguration)
        if #available(macOS 15.0, *) { XCTAssertTrue(toolbar.allowsDisplayModeCustomization) }
        XCTAssertEqual(toolbar.configurationWrites, writes, "An unchanged toolbar needs no repeated setters")
      }
    }
  }

  func testNavigationOwnedToolbarReplacementReceivesNoCustomizationSetters() {
    let library = ConfigurationTrackingToolbar(identifier: "Prosary.Library.Toolbar")
    let navigation = ConfigurationTrackingToolbar(identifier: "SwiftUI.Navigation.Toolbar")
    let prayer = ConfigurationTrackingToolbar(identifier: "Prosary.Prayer.Toolbar")
    navigation.displayMode = .iconOnly

    for toolbar in [library, navigation, prayer, navigation] {
      MacToolbarCustomization.configure(toolbar)
    }

    XCTAssertTrue(library.allowsUserCustomization)
    XCTAssertTrue(prayer.allowsUserCustomization)
    XCTAssertEqual(navigation.configurationWrites, 0,
                   "An inherited reader must not mutate a SwiftUI-owned replacement toolbar")
    XCTAssertFalse(navigation.allowsUserCustomization)
    XCTAssertFalse(navigation.autosavesConfiguration)
    if #available(macOS 15.0, *) { XCTAssertFalse(navigation.allowsDisplayModeCustomization) }
    XCTAssertEqual(navigation.displayMode, .iconOnly)
  }

  func testUnrelatedAppKitToolbarIsNotClaimedByTheLibraryReader() {
    let toolbar = ConfigurationTrackingToolbar(identifier: "Another.Toolbar")
    MacToolbarCustomization.configure(toolbar)
    XCTAssertEqual(toolbar.configurationWrites, 0)
  }
}

@MainActor
private final class ConfigurationTrackingToolbar: NSToolbar {
  private var customization = false
  private var savesConfiguration = false
  private var displayCustomization = false
  private var mode: NSToolbar.DisplayMode = .default
  private(set) var configurationWrites = 0

  override var allowsUserCustomization: Bool {
    get { customization }
    set { customization = newValue; configurationWrites += 1 }
  }

  override var autosavesConfiguration: Bool {
    get { savesConfiguration }
    set { savesConfiguration = newValue; configurationWrites += 1 }
  }

  @available(macOS 15.0, *)
  override var allowsDisplayModeCustomization: Bool {
    get { displayCustomization }
    set { displayCustomization = newValue; configurationWrites += 1 }
  }

  override var displayMode: NSToolbar.DisplayMode {
    get { mode }
    set { mode = newValue }
  }
}
#endif

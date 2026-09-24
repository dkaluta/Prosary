import XCTest
@testable import Prosary
#if os(macOS)
import AppKit
#endif

final class PrayerKeyboardNavigationTests: XCTestCase {
  func testIndependentSettingsAndInterfaceDirection() {
    for rtl in [false, true] {
      XCTAssertEqual(action(.left, rtl: rtl), rtl ? .next : .previous)
      XCTAssertEqual(action(.right, rtl: rtl), rtl ? .previous : .next)
      XCTAssertEqual(action(.space, rtl: rtl), .next)
      XCTAssertNil(action(.left, arrows: false, rtl: rtl))
      XCTAssertNil(action(.right, arrows: false, rtl: rtl))
      XCTAssertEqual(action(.space, arrows: false, rtl: rtl), .next)
      XCTAssertNil(action(.space, space: false, rtl: rtl))
      XCTAssertEqual(action(.right, space: false, rtl: rtl), rtl ? .previous : .next)
    }
    XCTAssertNil(action(.other))
    XCTAssertNil(action(.space, modifiers: true))
    XCTAssertNil(action(.right, repeated: true))
  }

  private func action(_ key: PrayerKeyboardNavigation.Key, arrows: Bool = true, space: Bool = true,
                      rtl: Bool = false, modifiers: Bool = false, repeated: Bool = false) -> PrayerKeyboardNavigation.Action? {
    PrayerKeyboardNavigation.action(for: key, arrowsEnabled: arrows, spaceEnabled: space,
      interfaceIsRTL: rtl, hasModifiers: modifiers, isRepeat: repeated)
  }
}

#if os(macOS)
@MainActor
final class MacPrayerKeyboardNavigationTests: XCTestCase {
  func testNativeEventsOnlyAdvanceTheOwningActiveWindow() {
    let first = Fixture(), second = Fixture()
    defer { first.close(); second.close() }
    first.window.testIsKey = true
    second.window.testIsKey = false
    XCTAssertTrue(first.view.handle(first.key(124)))
    XCTAssertFalse(second.view.handle(first.key(124)))
    XCTAssertFalse(second.view.handle(second.key(124)))
    XCTAssertEqual(first.next, 1)
    XCTAssertEqual(second.next, 0)
    first.window.testIsKey = false
    second.window.testIsKey = true
    XCTAssertFalse(first.view.handle(first.key(49)))
    XCTAssertTrue(second.view.handle(second.key(49)))
    XCTAssertEqual(first.next, 1)
    XCTAssertEqual(second.next, 1)
  }

  func testPreferencesRepeatsBoundsAndScrollingKeys() {
    let fixture = Fixture()
    defer { fixture.close() }
    fixture.view.configuration?.arrowsEnabled = false
    XCTAssertFalse(fixture.view.handle(fixture.key(124)))
    XCTAssertTrue(fixture.view.handle(fixture.key(49)))
    fixture.view.configuration?.arrowsEnabled = true
    fixture.view.configuration?.spaceEnabled = false
    XCTAssertFalse(fixture.view.handle(fixture.key(49)))
    XCTAssertTrue(fixture.view.handle(fixture.key(124)))
    XCTAssertTrue(fixture.view.handle(fixture.key(124, repeated: true)))
    XCTAssertFalse(fixture.view.handle(fixture.key(124, modifiers: .shift)))
    for code: UInt16 in [125, 126, 116, 121] { XCTAssertFalse(fixture.view.handle(fixture.key(code))) }
    XCTAssertEqual(fixture.next, 2)
    fixture.view.configuration?.canGoBack = false
    XCTAssertTrue(fixture.view.handle(fixture.key(123)))
    XCTAssertEqual(fixture.previous, 0)
    fixture.view.configuration?.canGoNext = false
    XCTAssertTrue(fixture.view.handle(fixture.key(124)))
    XCTAssertEqual(fixture.next, 2)
  }

  func testEditingSelectionControlsAndModalStateKeepTheirKeys() {
    let fixture = Fixture()
    defer { fixture.close() }
    let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 30))
    fixture.window.contentView?.addSubview(editor)
    editor.string = "Prayer text"
    XCTAssertTrue(fixture.window.makeFirstResponder(editor))
    XCTAssertFalse(fixture.view.handle(fixture.key(49)))
    editor.isEditable = false
    editor.setSelectedRange(NSRange(location: 0, length: 6))
    XCTAssertFalse(fixture.view.handle(fixture.key(124)))
    editor.setSelectedRange(NSRange(location: 0, length: 0))
    XCTAssertTrue(fixture.view.handle(fixture.key(124)))
    let control = FocusableButton()
    fixture.window.contentView?.addSubview(control)
    XCTAssertTrue(fixture.window.makeFirstResponder(control))
    XCTAssertFalse(fixture.view.handle(fixture.key(49)))
    fixture.window.makeFirstResponder(nil)
    fixture.view.configuration?.isModal = true
    XCTAssertFalse(fixture.view.handle(fixture.key(124)))
    fixture.view.configuration?.isModal = false
    fixture.view.isHidden = true
    XCTAssertFalse(fixture.view.handle(fixture.key(124)))
    XCTAssertEqual(fixture.next, 1)
  }

  /// Native windows/events/responders, without ordering test windows over the user's work.
  private final class TestWindow: NSWindow {
    var testIsKey = true
    override var isKeyWindow: Bool { testIsKey }
  }
  private final class FocusableButton: NSButton {
    override var acceptsFirstResponder: Bool { true }
  }
  private final class Fixture {
    let window = TestWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
      styleMask: [.titled], backing: .buffered, defer: false)
    let view = MacPrayerKeyboardBridge.KeyboardView()
    var previous = 0
    var next = 0
    init() {
      window.isReleasedWhenClosed = false
      view.configuration = MacPrayerKeyboardBridge(arrowsEnabled: true, spaceEnabled: true,
        interfaceIsRTL: false, canGoBack: true, canGoNext: true, isModal: false,
        onBack: { [weak self] in self?.previous += 1 }, onNext: { [weak self] in self?.next += 1 })
      window.contentView?.addSubview(view)
    }
    func key(_ code: UInt16, modifiers: NSEvent.ModifierFlags = [], repeated: Bool = false) -> NSEvent {
      NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
        windowNumber: window.windowNumber, context: nil, characters: code == 49 ? " " : "",
        charactersIgnoringModifiers: code == 49 ? " " : "", isARepeat: repeated, keyCode: code)!
    }
    func close() { view.detach(); window.close() }
  }
}
#endif

#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import Prosary

@MainActor
final class MacPrayerCollectionTests: XCTestCase {
  func testEveryTileSurfaceKeepsItsNativeItemHitTarget() throws {
    let harness = Harness()
    defer { harness.close() }
    let tile = try XCTUnwrap(harness.collection.item(at: IndexPath(item: 1, section: 0))).view
    let labels = descendants(of: tile).compactMap { $0 as? NSTextField }.filter { !$0.isHidden }
    XCTAssertTrue(labels.contains { $0.stringValue == "Prayer 1" })
    XCTAssertTrue(labels.contains { $0.stringValue == "English" })
    let icon = try XCTUnwrap(descendants(of: tile).first { $0 is NSImageView && !$0.isHidden })
    let surfaces = labels.map { tile.convert($0.bounds, from: $0) }
      + [tile.convert(icon.bounds, from: icon), tile.bounds.insetBy(dx: 4, dy: 4)]
    for surface in surfaces {
      let point = NSPoint(x: surface.midX, y: surface.midY)
      let hit = tile.hitTest(tile.convert(point, to: tile.superview))
      XCTAssertTrue(hit === tile, "Labels, symbols and padding must route clicks through their prayer tile")
      XCTAssertEqual(harness.collection.indexPathForItem(at: tile.convert(point, to: harness.collection)),
                     IndexPath(item: 1, section: 0))
    }
    XCTAssertNil(tile.hitTest(NSPoint(x: -100, y: -100)))
    XCTAssertFalse(harness.window.isVisible)
  }

  func testSecondaryClickMenuActionsTargetTheClickedPrayerWithoutChangingSelection() throws {
    let harness = Harness()
    defer { harness.close() }
    for index in [1, 2, 1] {
      let event = try harness.event(at: index)
      let menu = try XCTUnwrap(harness.collection.menu(for: event))
      XCTAssertEqual(harness.coordinator.contextPath, IndexPath(item: index, section: 0))
      for (title, expected) in [
        (String(localized: "macLibrary.open", defaultValue: "Open"), "open"),
        (String(localized: "macLibrary.duplicate", defaultValue: "Duplicate"), "duplicate"),
        (String(localized: "macLibrary.prayerSettings", defaultValue: "Prayer Settings…"), "edit"),
        (String(localized: "macLibrary.removeFromLibrary", defaultValue: "Remove from Library…"), "remove"),
      ] {
        let command = try XCTUnwrap(menu.items.first { $0.title == title })
        XCTAssertTrue(command.isEnabled)
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(command.action), to: command.target, from: command))
        XCTAssertEqual(harness.state.actions.last, "\(expected):item-\(index)")
      }
      XCTAssertEqual(harness.state.selection, "item-0")
      XCTAssertEqual(harness.collection.selectionIndexPaths, [IndexPath(item: 0, section: 0)])
      harness.coordinator.menuDidClose(menu)
      XCTAssertNil(harness.coordinator.contextPath)
    }
  }

  func testControlClickAndBlankSpaceUseTheContextMenuAtThePointer() throws {
    let harness = Harness()
    defer { harness.close() }
    let controlClick = try harness.event(at: 2, controlClick: true)
    let menu = try XCTUnwrap(harness.collection.menu(for: controlClick))
    let open = try XCTUnwrap(menu.items.first)
    XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(open.action), to: open.target, from: open))
    XCTAssertEqual(harness.state.actions, ["open:item-2"])
    harness.coordinator.menuDidClose(menu)

    let blank = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown,
      location: harness.collection.convert(NSPoint(x: 5, y: 5), to: nil), modifierFlags: [],
      timestamp: 0, windowNumber: harness.window.windowNumber, context: nil,
      eventNumber: 0, clickCount: 1, pressure: 1))
    let blankMenu = try XCTUnwrap(harness.collection.menu(for: blank))
    XCTAssertNil(harness.coordinator.contextPath)
    XCTAssertEqual(blankMenu.items.count, 1)
    let command = try XCTUnwrap(blankMenu.items.first)
    XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(command.action), to: command.target, from: command))
    XCTAssertEqual(harness.state.actions.last, "import")
    XCTAssertEqual(harness.state.selection, "item-0")
  }

  func testMenuCommandsStayDisabledWhileTheLibraryIsBusy() throws {
    let harness = Harness(isBusy: true)
    defer { harness.close() }
    let menu = try XCTUnwrap(harness.collection.menu(for: harness.event(at: 1)))
    let commands = menu.items.filter { $0.action != nil }
    XCTAssertFalse(commands.isEmpty)
    XCTAssertTrue(commands.allSatisfy { !$0.isEnabled })
    XCTAssertTrue(harness.state.actions.isEmpty)
  }

  private func descendants(of view: NSView) -> [NSView] {
    view.subviews.flatMap { [$0] + descendants(of: $0) }
  }

  @MainActor private final class State {
    var selection: String? = "item-0"
    var actions: [String] = []
  }

  /// Hidden AppKit windows exercise actual hit testing without touching the person's library.
  @MainActor private final class Harness {
    let state = State()
    let coordinator: MacPrayerCollection.Coordinator
    let scroll: NSScrollView
    let collection: PrayerCollectionView
    let window: NSWindow

    init(isBusy: Bool = false) {
      let state = state
      let items = (0..<3).map { index in
        MacPrayerLibraryItem(id: "item-\(index)", title: "Prayer \(index)", subtitle: "English",
          systemImage: "book.closed", iconGlyph: nil, color: .blue, prayer: nil,
          devotionID: "test-\(index)", tagIDs: [])
      }
      let view = MacPrayerCollection(items: items, tags: [],
        selectedID: Binding(get: { state.selection }, set: { state.selection = $0 }), isBusy: isBusy,
        onOpen: { state.actions.append("open:\($0.id)") },
        onDuplicate: { state.actions.append("duplicate:\($0.id)") },
        onEdit: { state.actions.append("edit:\($0.id)") },
        onRemove: { state.actions.append("remove:\($0.id)") },
        onTag: { _, _, _ in XCTFail("A menu command should not alter tags") },
        onClearTags: { state.actions.append("clear:\($0.id)") },
        onEditTags: { state.actions.append("tags:\($0.id)") },
        onImport: { state.actions.append("import") })
      coordinator = view.makeCoordinator()
      scroll = coordinator.makeScrollView()
      collection = scroll.documentView as! PrayerCollectionView
      window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 400),
        styleMask: .borderless, backing: .buffered, defer: true)
      window.isReleasedWhenClosed = false
      window.contentView = scroll
      scroll.setFrameSize(NSSize(width: 980, height: 400))
      coordinator.update(view)
      for _ in 0..<3 {
        scroll.tile()
        scroll.layoutSubtreeIfNeeded()
        collection.layoutSubtreeIfNeeded()
      }
    }

    func event(at index: Int, controlClick: Bool = false) throws -> NSEvent {
      let tile = try XCTUnwrap(collection.item(at: IndexPath(item: index, section: 0))).view
      return try XCTUnwrap(NSEvent.mouseEvent(with: controlClick ? .leftMouseDown : .rightMouseDown,
        location: tile.convert(NSPoint(x: tile.bounds.midX, y: tile.bounds.midY), to: nil),
        modifierFlags: controlClick ? [.control] : [], timestamp: 0,
        windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }

    func close() { window.close() }
  }
}
#endif

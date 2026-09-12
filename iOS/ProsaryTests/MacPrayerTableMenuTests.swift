#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import Prosary

@MainActor
final class MacPrayerTableMenuTests: XCTestCase {
  func testFirstContextLookupFindsTableCreatedAfterInitialAttachmentPass() async throws {
    let harness = Harness()
    defer { harness.close() }
    let (root, anchor) = harness.prepareDelayedTable()
    harness.coordinator.parent = harness.makeAdapter(items: harness.items, selectedID: nil)
    harness.coordinator.attach(from: anchor)
    await nextMainQueueTurn()
    XCTAssertNil(harness.coordinator.table)
    XCTAssertNil(harness.table.menu)

    // The native table arrives later, without moving the anchor or changing selection.
    root.addSubview(harness.table)
    XCTAssertNil(harness.coordinator.parent.selectedID)
    XCTAssertTrue(harness.coordinator.tableForContext(in: harness.window) === harness.table,
      "The first contextual gesture must attach without an ordinary selection click")
    XCTAssertTrue(harness.table.menu === harness.coordinator.menu)
    XCTAssertNil(harness.coordinator.parent.selectedID)
  }

  func testContextLookupReplacesAnOldTableAndStaysInsideAnchorWindow() async throws {
    let harness = Harness()
    defer { harness.close() }
    let (root, anchor) = harness.prepareDelayedTable()
    root.addSubview(harness.table)
    harness.coordinator.attach(from: anchor)
    await nextMainQueueTurn()
    XCTAssertTrue(harness.coordinator.table === harness.table)

    let replacement = NSTableView(frame: harness.table.frame)
    replacement.setAccessibilityIdentifier("macLibrary.listView")
    harness.table.removeFromSuperview()
    root.addSubview(replacement)
    XCTAssertTrue(harness.coordinator.tableForContext(in: harness.window) === replacement)
    XCTAssertNil(harness.table.menu, "A replaced table must relinquish the adapter's menu")
    XCTAssertTrue(replacement.menu === harness.coordinator.menu)

    let other = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
    other.isReleasedWhenClosed = false
    defer { other.close() }
    XCTAssertNil(harness.coordinator.tableForContext(in: other))
    XCTAssertNil(harness.coordinator.tableForContext(in: nil))
    XCTAssertTrue(harness.coordinator.table === replacement)
  }

  func testDismantlingBeforeDeferredAttachmentCannotReattachMenu() async throws {
    let harness = Harness()
    defer { harness.close() }
    let (root, anchor) = harness.prepareDelayedTable()
    harness.coordinator.attach(from: anchor)
    MacPrayerTableMenu.dismantleNSView(anchor, coordinator: harness.coordinator)
    root.addSubview(harness.table)
    await nextMainQueueTurn()
    XCTAssertFalse(harness.coordinator.isActive)
    XCTAssertNil(harness.coordinator.table)
    XCTAssertNil(harness.table.menu)
    XCTAssertNil(harness.coordinator.tableForContext(in: harness.window))
    harness.coordinator.attach(from: anchor)
    await nextMainQueueTurn()
    XCTAssertNil(harness.coordinator.table)
    XCTAssertNil(harness.table.menu)
  }

  func testPointerTargetsUnselectedRowAndKeyboardTargetsSelection() throws {
    let harness = Harness()
    defer { harness.close() }
    let pointer = try harness.event(row: 2)
    XCTAssertFalse(harness.coordinator.handles(pointer, in: harness.table),
      "Synthetic events for an unregistered hidden window must not be intercepted")
    XCTAssertEqual(harness.coordinator.row(for: pointer, in: harness.table), 2)
    XCTAssertEqual(harness.coordinator.row(for: nil, in: harness.table), 0)
    XCTAssertEqual(harness.table.selectedRow, 0, "A context target is independent of the selection")
    harness.coordinator.menuNeedsUpdate(harness.coordinator.menu)
    let open = try XCTUnwrap(harness.coordinator.menu.items.first)
    XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(open.action), to: open.target, from: open))
    XCTAssertEqual(harness.opened, ["item-0"])
    let control = try harness.event(row: 1, type: .leftMouseDown, modifiers: .control)
    XCTAssertEqual(harness.coordinator.row(for: control, in: harness.table), 1)
    let ordinary = try harness.event(row: 1, type: .leftMouseDown)
    XCTAssertFalse(harness.coordinator.handles(ordinary, in: harness.table), "Ordinary selection and double-click stay with SwiftUI")
  }

  func testFilteredRowsAndBlankSpaceResolveAgainstCurrentItems() throws {
    let harness = Harness()
    defer { harness.close() }
    harness.coordinator.parent = harness.makeAdapter(items: [harness.items[2]], selectedID: "item-2")
    harness.rowCount = 1
    harness.table.reloadData()
    XCTAssertEqual(harness.coordinator.row(for: try harness.event(row: 0), in: harness.table), 0)
    XCTAssertEqual(harness.coordinator.parent.items[0].id, "item-2")
    harness.coordinator.menuNeedsUpdate(harness.coordinator.menu)
    let open = try XCTUnwrap(harness.coordinator.menu.items.first)
    XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(open.action), to: open.target, from: open))
    XCTAssertEqual(harness.opened, ["item-2"])
    let blank = try harness.event(y: 150)
    XCTAssertEqual(harness.coordinator.row(for: blank, in: harness.table), -1)
    harness.coordinator.parent = harness.makeAdapter(items: [harness.items[2]], selectedID: nil)
    harness.coordinator.menuNeedsUpdate(harness.coordinator.menu)
    let command = try XCTUnwrap(harness.coordinator.menu.items.first)
    XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(command.action), to: command.target, from: command))
    XCTAssertEqual(harness.imports, 1)
  }

  private func nextMainQueueTurn() async {
    await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
  }

  @MainActor private final class Harness: NSObject, NSTableViewDataSource {
    let items = (0..<3).map { index in
      MacPrayerLibraryItem(id: "item-\(index)", title: "Prayer \(index)", subtitle: "English",
        systemImage: "book.closed", iconGlyph: nil, color: .blue, prayer: nil,
        devotionID: "test-\(index)", tagIDs: [])
    }
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 240),
      styleMask: .borderless, backing: .buffered, defer: true)
    let table = NSTableView(frame: NSRect(x: 0, y: 0, width: 400, height: 240))
    var coordinator: MacPrayerTableMenu.Coordinator!
    var opened: [String] = []
    var imports = 0
    var rowCount = 3

    override init() {
      super.init()
      window.isReleasedWhenClosed = false
      table.addTableColumn(NSTableColumn(identifier: .init("name")))
      table.rowHeight = 30
      table.dataSource = self
      window.contentView = table
      table.reloadData()
      table.selectRowIndexes([0], byExtendingSelection: false)
      coordinator = makeAdapter(items: items, selectedID: "item-0").makeCoordinator()
      coordinator.table = table
    }

    func makeAdapter(items: [MacPrayerLibraryItem], selectedID: String?) -> MacPrayerTableMenu {
      MacPrayerTableMenu(items: items, selectedID: selectedID, makeMenu: { [weak self] item in
        let menu = NSMenu()
        MacPrayerLibraryMenu.add("Open", to: menu, enabled: true) { self?.opened.append(item.id) }
        return menu
      }, onImport: { [weak self] in self?.imports += 1 })
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rowCount }
    func prepareDelayedTable() -> (NSView, MacPrayerTableMenu.Anchor) {
      let root = NSView(frame: table.frame)
      let anchor = MacPrayerTableMenu.Anchor(frame: .zero)
      root.addSubview(anchor)
      window.contentView = root
      table.setAccessibilityIdentifier("macLibrary.listView")
      coordinator.table = nil
      return (root, anchor)
    }
    func event(row: Int, type: NSEvent.EventType = .rightMouseDown,
               modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
      try event(y: table.rect(ofRow: row).midY, type: type, modifiers: modifiers)
    }
    func event(y: CGFloat, type: NSEvent.EventType = .rightMouseDown,
               modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
      try XCTUnwrap(NSEvent.mouseEvent(with: type, location: table.convert(NSPoint(x: 25, y: y), to: nil),
        modifierFlags: modifiers, timestamp: 0, windowNumber: window.windowNumber, context: nil,
        eventNumber: 0, clickCount: 1, pressure: 1))
    }
    func close() { coordinator.stopMonitoring(); window.close() }
  }
}
#endif

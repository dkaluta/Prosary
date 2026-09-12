#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import Prosary

@MainActor
final class MacPrayerGalleryCollectionTests: XCTestCase {
  func testNativeLayoutProducesVisibleItemsAndReflowsWithViewportWidth() throws {
    let harness = Harness(count: 12, width: 380, height: 340)
    defer { harness.close() }

    let narrowFirst = try harness.frame(at: 0)
    let narrowSecond = try harness.frame(at: 1)
    XCTAssertGreaterThan(narrowFirst.width, 100)
    XCTAssertGreaterThan(narrowFirst.height, 100)
    XCTAssertGreaterThan(narrowSecond.minY, narrowFirst.minY,
      "A narrow gallery must put the next item on another row")
    XCTAssertLessThanOrEqual(narrowFirst.maxX, harness.scroll.contentSize.width)
    let cell = try XCTUnwrap(harness.collection.item(at: IndexPath(item: 0, section: 0)))
    XCTAssertGreaterThan(cell.view.bounds.width, 0)
    XCTAssertGreaterThan(cell.view.bounds.height, 0)
    XCTAssertEqual(cell.view.accessibilityIdentifier(), "macGallery.item.gallery-test-0")

    harness.resize(width: 980, height: 340)
    let wideFirst = try harness.frame(at: 0)
    let wideSecond = try harness.frame(at: 1)
    XCTAssertEqual(wideFirst.minY, wideSecond.minY, accuracy: 0.5)
    XCTAssertGreaterThan(abs(wideSecond.minX - wideFirst.minX), 100,
      "A wide gallery must lay out more than one native item per row")
    for index in harness.state.items.indices {
      let frame = try harness.frame(at: index)
      XCTAssertGreaterThan(frame.width, 0)
      XCTAssertGreaterThan(frame.height, 0)
      XCTAssertGreaterThanOrEqual(frame.minX, 0)
      XCTAssertLessThanOrEqual(frame.maxX, harness.scroll.contentSize.width + 0.5)
    }
    XCTAssertFalse(harness.window.isVisible)
  }

  func testDocumentCoversTheViewportAndCanScrollToTheFinalPrayer() throws {
    let short = Harness(count: 1, width: 720, height: 600)
    defer { short.close() }
    XCTAssertGreaterThanOrEqual(short.collection.frame.height, short.scroll.contentSize.height,
      "Blank space below a short gallery must belong to the native collection")

    let long = Harness(count: 30, width: 620, height: 300)
    defer { long.close() }
    let lastPath = IndexPath(item: long.state.items.count - 1, section: 0)
    let lastFrame = try long.frame(at: lastPath.item)
    XCTAssertGreaterThan(lastFrame.maxY, long.scroll.contentSize.height)
    XCTAssertGreaterThanOrEqual(long.collection.frame.height + 0.5, lastFrame.maxY,
      "The scroll document must include every row, not just the initial viewport")

    long.collection.scrollToItems(at: [lastPath], scrollPosition: .bottom)
    long.layout()
    XCTAssertGreaterThan(long.scroll.contentView.bounds.minY, 0)
    XCTAssertTrue(long.collection.visibleRect.intersects(lastFrame),
      "Native scrolling must make the last prayer reachable")
    XCTAssertNotNil(long.collection.item(at: lastPath))
    XCTAssertFalse(long.window.isVisible)
  }

  func testNativeSelectionActionsPublishStableIDsAndSelectedCells() throws {
    let harness = Harness(count: 4, width: 980, height: 340)
    defer { harness.close() }
    XCTAssertTrue(harness.collection.isSelectable)
    XCTAssertTrue(harness.collection.allowsMultipleSelection)
    XCTAssertTrue(harness.collection.allowsEmptySelection)

    // Unlike selectItems(at:), these are native responder actions that notify the delegate.
    harness.collection.selectAll(nil)
    XCTAssertEqual(harness.state.selection, Set(harness.state.items.map(\.id)))
    XCTAssertEqual(harness.collection.selectionIndexPaths.count, 4)
    let cell = try XCTUnwrap(harness.collection.item(at: IndexPath(item: 0, section: 0)))
    XCTAssertTrue(cell.isSelected)
    XCTAssertTrue(cell.view.isAccessibilitySelected())

    harness.collection.deselectAll(nil)
    XCTAssertTrue(harness.state.selection.isEmpty)
    XCTAssertTrue(harness.collection.selectionIndexPaths.isEmpty)
    XCTAssertFalse(cell.isSelected)
    XCTAssertFalse(cell.view.isAccessibilitySelected())
  }

  func testSelectionOnlyUpdatesKeepNativeCellsAndScrollPosition() throws {
    let harness = Harness(count: 30, width: 720, height: 340)
    defer { harness.close() }
    let lastPath = IndexPath(item: harness.state.items.count - 1, section: 0)
    harness.collection.scrollToItems(at: [lastPath], scrollPosition: .bottom)
    harness.layout()
    let cell = try XCTUnwrap(harness.collection.item(at: lastPath))
    let origin = harness.scroll.contentView.bounds.origin

    harness.collection.selectAll(nil)
    harness.update()
    let retainedCell = try XCTUnwrap(harness.collection.item(at: lastPath))
    XCTAssertTrue(cell === retainedCell,
      "Publishing native selection must not reload visible artwork hosts")
    XCTAssertEqual(harness.scroll.contentView.bounds.origin.x, origin.x, accuracy: 0.5)
    XCTAssertEqual(harness.scroll.contentView.bounds.origin.y, origin.y, accuracy: 0.5)
    XCTAssertEqual(harness.collection.selectionIndexPaths.count, 30)
  }

  func testFilteringDropsHiddenSelectionBeforeActivationAndQueuedBindingCleanup() async throws {
    let harness = Harness(count: 4, width: 720, height: 340, selectedIndexes: [1, 3])
    defer { harness.close() }
    let original = harness.state.items

    // The retained item moves from index 3 to index 1, previously occupied by a hidden item.
    harness.state.items = [original[2], original[3]]
    harness.update()
    XCTAssertEqual(harness.collection.selectionIndexPaths, [IndexPath(item: 1, section: 0)])
    harness.coordinator.activateSelection()
    XCTAssertEqual(harness.state.activations, [[original[3].id]],
      "Activation must resolve current IDs rather than reuse old indexes")

    // Filter again before the first asynchronous binding cleanup runs.
    harness.state.items = [original[2]]
    harness.update()
    XCTAssertTrue(harness.collection.selectionIndexPaths.isEmpty)
    harness.coordinator.activateSelection()
    harness.coordinator.activate(itemID: original[1].id)
    XCTAssertEqual(harness.state.activations.count, 1)

    await nextMainQueueTurn()
    XCTAssertTrue(harness.state.selection.isEmpty,
      "Queued cleanup must use the latest filter and cannot restore hidden selections")
    XCTAssertFalse(harness.window.isVisible)
  }

  func testReturnUsesVisibleOrderAndClickedActivationUsesOnlyThatPrayer() throws {
    let harness = Harness(count: 5, width: 980, height: 340, selectedIndexes: [4, 1, 3])
    defer { harness.close() }
    let items = harness.state.items
    let enter = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
      modifierFlags: [], timestamp: 0, windowNumber: harness.window.windowNumber,
      context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
      isARepeat: false, keyCode: 36))
    harness.collection.keyDown(with: enter)
    XCTAssertEqual(harness.state.activations, [[items[1].id, items[3].id, items[4].id]])

    // The pointer handler passes a hit-tested ID to this same callback after native tracking.
    let clickedFrame = try harness.frame(at: 2)
    let clickedPoint = NSPoint(x: clickedFrame.midX, y: clickedFrame.midY)
    let clickedCell = try XCTUnwrap(harness.collection.item(at: IndexPath(item: 2, section: 0)))
    let hit = harness.collection.hitTest(harness.collection.convert(clickedPoint, to: harness.collection.superview))
    XCTAssertTrue(hit === clickedCell.view,
      "A tile must retain its native hit-test identity while forwarding pointer events")
    XCTAssertEqual(harness.collection.indexPathForItem(at: clickedPoint), IndexPath(item: 2, section: 0))
    let clickedID = harness.coordinator.itemID(at: clickedPoint)
    XCTAssertEqual(clickedID, items[2].id)
    harness.coordinator.activate(itemID: clickedID)
    XCTAssertEqual(harness.state.activations.last, [items[2].id])
    XCTAssertEqual(harness.state.selection, Set([items[1].id, items[3].id, items[4].id]),
      "A clicked-item activation must not silently replace the current multi-selection")
    harness.coordinator.activate(itemID: nil)
    harness.coordinator.activate(itemID: "not-in-this-gallery")
    XCTAssertEqual(harness.state.activations.count, 2)
  }

  func testImageMenuTargetsClickedPrayerAndRejectsAnItemRemovedBeforeTrackingEnds() async throws {
    let harness = Harness(count: 4, width: 980, height: 340, selectedIndexes: [0, 1])
    defer { harness.close() }
    let clicked = harness.state.items[2]
    let menu = try XCTUnwrap(harness.coordinator.menu(for: clicked.id))
    let choose = try XCTUnwrap(menu.items.first { $0.tag == MacPrayerGalleryImageAction.chooseFile.rawValue })
    XCTAssertTrue(choose.isEnabled, "Built-in Gallery prayers must offer image customization")
    XCTAssertFalse(try XCTUnwrap(menu.items.first { $0.tag == MacPrayerGalleryImageAction.restoreDefault.rawValue }).isEnabled)
    XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(choose.action), to: choose.target, from: choose))
    await nextMainQueueTurn()
    XCTAssertEqual(harness.state.imageActions, ["0:\(clicked.id)"])
    XCTAssertEqual(harness.state.selection, ["item-0", "item-1"])
    XCTAssertTrue(harness.state.activations.isEmpty, "An image action must not add or open a prayer")

    XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(choose.action), to: choose.target, from: choose))
    harness.state.items.removeAll { $0.id == clicked.id }
    harness.update()
    await nextMainQueueTurn()
    XCTAssertEqual(harness.state.imageActions.count, 1, "A queued image action must revalidate the current Gallery")
  }

  func testImageDropUsesTheTileUnderThePointerWithoutChangingSelection() throws {
    let harness = Harness(count: 4, width: 980, height: 340, selectedIndexes: [0, 1])
    defer { harness.close() }
    let pasteboard = NSPasteboard(name: .init("Prosary-Gallery-Drop-\(UUID())"))
    defer { pasteboard.releaseGlobally() }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Prosary-Gallery-Drop-\(UUID())")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("portrait.jpg")
    let other = directory.appendingPathComponent("other.png")
    let pack = directory.appendingPathComponent("prayer.prosaryprayer")
    for url in [file, other, pack] { try Data([1]).write(to: url) }
    let target = try harness.frame(at: 2)
    let point = NSPoint(x: target.midX, y: target.midY)
    pasteboard.writeObjects([file as NSURL])
    XCTAssertTrue(harness.coordinator.acceptImageDrop(pasteboard: pasteboard, at: point))
    XCTAssertEqual(harness.state.droppedImages, ["portrait.jpg:item-2"])
    XCTAssertEqual(harness.state.selection, ["item-0", "item-1"])
    XCTAssertTrue(harness.state.activations.isEmpty)
    XCTAssertFalse(harness.coordinator.acceptImageDrop(pasteboard: pasteboard, at: NSPoint(x: 1, y: 1)))

    for files in [[file, other], [pack]] {
      pasteboard.clearContents()
      pasteboard.writeObjects(files.map { $0 as NSURL })
      XCTAssertFalse(harness.coordinator.acceptImageDrop(pasteboard: pasteboard, at: point))
    }
    XCTAssertEqual(harness.state.droppedImages.count, 1)
    pasteboard.clearContents()
    pasteboard.writeObjects([file as NSURL])
    harness.coordinator.isActive = false
    XCTAssertFalse(harness.coordinator.acceptImageDrop(pasteboard: pasteboard, at: point))
  }

  private func nextMainQueueTurn() async {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { continuation.resume() }
    }
  }

  @MainActor private final class State {
    var items: [MacPrayerLibraryItem]
    var selection: Set<String>
    var activations: [[String]] = []
    var imageActions: [String] = []
    var droppedImages: [String] = []

    init(count: Int, selectedIndexes: Set<Int>) {
      items = (0..<count).map { index in
        MacPrayerLibraryItem(id: "item-\(index)", title: "Gallery Prayer \(index)", subtitle: "",
          systemImage: "book.closed", iconGlyph: nil, color: .blue, prayer: nil,
          devotionID: "gallery-test-\(index)", tagIDs: [])
      }
      selection = Set(items.enumerated().compactMap { selectedIndexes.contains($0.offset) ? $0.element.id : nil })
    }
  }

  /// None of these windows is ordered, activated, or connected to the user's library/store.
  @MainActor private final class Harness {
    let state: State
    let coordinator: MacPrayerGalleryCollection.Coordinator
    let scroll: NSScrollView
    let collection: GalleryCollectionView
    let window: NSWindow

    init(count: Int, width: CGFloat, height: CGFloat, selectedIndexes: Set<Int> = []) {
      let state = State(count: count, selectedIndexes: selectedIndexes)
      self.state = state
      let representable = Self.view(for: state)
      let coordinator = representable.makeCoordinator()
      self.coordinator = coordinator
      let scroll = coordinator.makeScrollView()
      self.scroll = scroll
      // The coordinator creates this concrete native collection; a wrong document type is
      // a harness setup failure, not a reason to silently skip native assertions.
      collection = scroll.documentView as! GalleryCollectionView
      window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
        styleMask: .borderless, backing: .buffered, defer: true)
      window.isReleasedWhenClosed = false
      window.contentView = scroll
      scroll.setFrameSize(NSSize(width: width, height: height))
      coordinator.update(representable, scroll: scroll)
      layout()
    }

    private static func view(for state: State) -> MacPrayerGalleryCollection {
      MacPrayerGalleryCollection(items: state.items,
        selection: Binding(get: { state.selection }, set: { state.selection = $0 }),
        downloadedDevotionIDs: [], canRemoveDownload: { _ in false },
        onRemoveDownload: { _ in XCTFail("Selection must never remove a download") },
        onActivate: { state.activations.append($0.map(\.id)) },
        onImageAction: { state.imageActions.append("\($0.rawValue):\($1.id)") },
        onDropImage: { state.droppedImages.append("\($0.lastPathComponent):\($1.id)") })
    }

    func update() {
      coordinator.update(Self.view(for: state), scroll: scroll)
      layout()
    }

    func resize(width: CGFloat, height: CGFloat) {
      window.setContentSize(NSSize(width: width, height: height))
      layout()
    }

    func layout() {
      // A changed document size can retile the scroll view; settle those native passes
      // without ordering a window or driving the application event loop.
      for _ in 0..<3 {
        scroll.tile()
        scroll.layoutSubtreeIfNeeded()
        collection.layoutSubtreeIfNeeded()
      }
    }

    func frame(at index: Int) throws -> NSRect {
      try XCTUnwrap(collection.layoutAttributesForItem(at: IndexPath(item: index, section: 0))).frame
    }

    func close() {
      MacPrayerGalleryCollection.dismantleNSView(scroll, coordinator: coordinator)
      window.contentView = nil
      window.close()
    }
  }
}
#endif

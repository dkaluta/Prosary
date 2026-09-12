#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import Prosary

/// Exercise the registered AppKit delegate and destination lifecycle, not the URL helper.
/// Every window is hidden and every callback is an isolated in-memory recorder.
@MainActor
final class MacPrayerGalleryNativeDropTests: XCTestCase {
  func testRegisteredNativeDelegateConvertsWindowCoordinatesAndKeepsSelection() throws {
    let harness = Harness(count: 30)
    defer { harness.close() }
    let last = IndexPath(item: 29, section: 0)
    harness.collection.scrollToItems(at: [last], scrollPosition: .bottom)
    harness.layout()
    XCTAssertGreaterThan(harness.scroll.contentView.bounds.minY, 0)
    let drag = try harness.drag(at: last)
    var proposed = IndexPath(item: 0, section: 0) as NSIndexPath
    var operation = NSCollectionView.DropOperation.before
    let delegate = try XCTUnwrap(harness.collection.delegate)
    XCTAssertTrue(harness.collection.registeredDraggedTypes.contains(.fileURL))
    XCTAssertTrue((delegate as AnyObject) === harness.coordinator)
    XCTAssertEqual(delegate.collectionView?(harness.collection, validateDrop: drag,
      proposedIndexPath: &proposed, dropOperation: &operation), .copy)
    XCTAssertEqual(proposed as IndexPath, last)
    XCTAssertEqual(operation, .on)
    XCTAssertEqual(delegate.collectionView?(harness.collection, acceptDrop: drag,
      indexPath: proposed as IndexPath, dropOperation: operation), true)
    XCTAssertEqual(harness.state.drops, ["portrait.jpg:item-29"])
    XCTAssertEqual(harness.state.selection, ["item-0", "item-1"])
    XCTAssertTrue(harness.state.activations.isEmpty)
    XCTAssertFalse(harness.window.isVisible)
  }

  func testNativeCollectionDestinationLifecycleAcceptsExactlyOneImage() throws {
    let harness = Harness(count: 4)
    defer { harness.close() }
    let drag = try harness.drag(at: IndexPath(item: 2, section: 0))
    XCTAssertEqual(harness.collection.draggingEntered(drag), .copy)
    XCTAssertEqual(harness.collection.draggingUpdated(drag), .copy)
    XCTAssertTrue(harness.collection.prepareForDragOperation(drag))
    XCTAssertTrue(harness.collection.performDragOperation(drag))
    harness.collection.concludeDragOperation(drag)
    XCTAssertEqual(harness.state.drops, ["portrait.jpg:item-2"])
    XCTAssertEqual(harness.state.selection, ["item-0", "item-1"])
    XCTAssertTrue(harness.state.activations.isEmpty)
    XCTAssertFalse(harness.window.isVisible)
  }

  func testDelegateRejectsPackMultipleFilesBlankSpaceAndUnsupportedOperations() throws {
    let harness = Harness(count: 4)
    defer { harness.close() }
    let drag = try harness.drag(at: IndexPath(item: 2, section: 0))
    let delegate = try XCTUnwrap(harness.collection.delegate)
    var proposed = IndexPath(item: 2, section: 0) as NSIndexPath
    var operation = NSCollectionView.DropOperation.on
    for files in [[harness.pack], [harness.portrait, harness.secondImage], [harness.unsupported]] {
      drag.setFiles(files)
      XCTAssertEqual(delegate.collectionView?(harness.collection, validateDrop: drag,
        proposedIndexPath: &proposed, dropOperation: &operation), [])
      XCTAssertEqual(delegate.collectionView?(harness.collection, acceptDrop: drag,
        indexPath: proposed as IndexPath, dropOperation: .on), false)
    }
    drag.setFiles([harness.portrait])
    drag.draggingSourceOperationMask = .move
    XCTAssertEqual(delegate.collectionView?(harness.collection, validateDrop: drag,
      proposedIndexPath: &proposed, dropOperation: &operation), [])
    XCTAssertEqual(delegate.collectionView?(harness.collection, acceptDrop: drag,
      indexPath: proposed as IndexPath, dropOperation: .on), false)
    drag.draggingSourceOperationMask = .copy
    XCTAssertEqual(delegate.collectionView?(harness.collection, acceptDrop: drag,
      indexPath: proposed as IndexPath, dropOperation: .before), false)
    drag.draggingLocation = harness.collection.convert(NSPoint(x: 1, y: 1), to: nil)
    XCTAssertEqual(delegate.collectionView?(harness.collection, validateDrop: drag,
      proposedIndexPath: &proposed, dropOperation: &operation), [])
    XCTAssertEqual(delegate.collectionView?(harness.collection, acceptDrop: drag,
      indexPath: proposed as IndexPath, dropOperation: .on), false)
    XCTAssertTrue(harness.state.drops.isEmpty)
    XCTAssertEqual(harness.state.selection, ["item-0", "item-1"])
  }

  func testDropRevalidatesSourceAndDismantledCollectionAfterNativeValidation() throws {
    let harness = Harness(count: 4)
    defer { harness.close() }
    let drag = try harness.drag(at: IndexPath(item: 2, section: 0))
    let delegate = try XCTUnwrap(harness.collection.delegate)
    var proposed = IndexPath(item: 0, section: 0) as NSIndexPath
    var operation = NSCollectionView.DropOperation.before
    XCTAssertEqual(delegate.collectionView?(harness.collection, validateDrop: drag,
      proposedIndexPath: &proposed, dropOperation: &operation), .copy)
    drag.draggingSourceOperationMask = []
    XCTAssertEqual(delegate.collectionView?(harness.collection, acceptDrop: drag,
      indexPath: proposed as IndexPath, dropOperation: operation), false)
    drag.draggingSourceOperationMask = .copy
    drag.setFiles([harness.pack])
    XCTAssertEqual(delegate.collectionView?(harness.collection, acceptDrop: drag,
      indexPath: proposed as IndexPath, dropOperation: operation), false)
    drag.setFiles([harness.portrait])
    MacPrayerGalleryCollection.dismantleNSView(harness.scroll, coordinator: harness.coordinator)
    XCTAssertNil(harness.collection.delegate)
    XCTAssertEqual(delegate.collectionView?(harness.collection, acceptDrop: drag,
      indexPath: proposed as IndexPath, dropOperation: operation), false)
    XCTAssertTrue(harness.state.drops.isEmpty)
  }

  @MainActor private final class State {
    let items: [MacPrayerLibraryItem]
    var selection: Set<String> = ["item-0", "item-1"]
    var drops: [String] = []
    var activations: [[String]] = []
    init(count: Int) {
      items = (0..<count).map { index in
        MacPrayerLibraryItem(id: "item-\(index)", title: "Drop Fixture \(index)", subtitle: "",
          systemImage: "book.closed", iconGlyph: nil, color: .blue, prayer: nil,
          devotionID: "native-drop-\(index)", tagIDs: [])
      }
    }
  }

  @MainActor private final class Harness {
    let state: State
    let coordinator: MacPrayerGalleryCollection.Coordinator
    let collection: GalleryCollectionView
    let scroll: NSScrollView
    let window: NSWindow
    let directory: URL
    let portrait: URL
    let secondImage: URL
    let pack: URL
    let unsupported: URL
    var drags: [DraggingInfo] = []

    init(count: Int) {
      state = State(count: count)
      let state = state
      let view = MacPrayerGalleryCollection(items: state.items,
        selection: Binding(get: { state.selection }, set: { state.selection = $0 }),
        downloadedDevotionIDs: [], canRemoveDownload: { _ in false },
        onRemoveDownload: { _ in XCTFail("Dropping artwork must not remove a pack") },
        onActivate: { state.activations.append($0.map(\.id)) },
        onDropImage: { state.drops.append("\($0.lastPathComponent):\($1.id)") })
      coordinator = view.makeCoordinator()
      scroll = coordinator.makeScrollView()
      collection = scroll.documentView as! GalleryCollectionView
      window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 440),
        styleMask: .borderless, backing: .buffered, defer: true)
      window.isReleasedWhenClosed = false
      let container = NSView(frame: NSRect(x: 0, y: 0, width: 740, height: 440))
      window.contentView = container
      scroll.frame = NSRect(x: 34, y: 27, width: 650, height: 330)
      container.addSubview(scroll)
      coordinator.update(view, scroll: scroll)
      directory = FileManager.default.temporaryDirectory.appendingPathComponent("Native-Gallery-Drop-\(UUID())")
      portrait = directory.appendingPathComponent("portrait.jpg")
      secondImage = directory.appendingPathComponent("second.png")
      pack = directory.appendingPathComponent("prayer.prosaryprayer")
      unsupported = directory.appendingPathComponent("document.pdf")
      layout()
    }

    func layout() {
      for _ in 0..<3 {
        scroll.tile()
        scroll.layoutSubtreeIfNeeded()
        collection.layoutSubtreeIfNeeded()
      }
    }

    func drag(at path: IndexPath) throws -> DraggingInfo {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      for file in [portrait, secondImage, pack, unsupported] { try Data([1]).write(to: file) }
      let frame = try XCTUnwrap(collection.layoutAttributesForItem(at: path)).frame
      let point = collection.convert(NSPoint(x: frame.midX, y: frame.midY), to: nil)
      let drag = DraggingInfo(window: window, location: point, files: [portrait])
      drags.append(drag)
      return drag
    }

    func close() {
      MacPrayerGalleryCollection.dismantleNSView(scroll, coordinator: coordinator)
      drags.forEach { $0.draggingPasteboard.releaseGlobally() }
      window.contentView = nil
      window.close()
      try? FileManager.default.removeItem(at: directory)
    }
  }

  @MainActor private final class DraggingInfo: NSObject, NSDraggingInfo {
    let draggingDestinationWindow: NSWindow?
    var draggingSourceOperationMask: NSDragOperation = .copy
    var draggingLocation: NSPoint
    var draggedImageLocation: NSPoint { draggingLocation }
    var draggedImage: NSImage? { nil }
    let draggingPasteboard: NSPasteboard
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 1 }
    var draggingFormation: NSDraggingFormation = .none
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 1
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }

    init(window: NSWindow, location: NSPoint, files: [URL]) {
      draggingDestinationWindow = window
      draggingLocation = location
      draggingPasteboard = NSPasteboard(name: .init("Prosary-Native-Drop-\(UUID())"))
      super.init()
      setFiles(files)
    }

    func setFiles(_ files: [URL]) {
      draggingPasteboard.clearContents()
      draggingPasteboard.writeObjects(files.map { $0 as NSURL })
    }

    func slideDraggedImage(to screenPoint: NSPoint) {}
    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions,
      for view: NSView?, classes classArray: [AnyClass],
      searchOptions: [NSPasteboard.ReadingOptionKey: Any],
      using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {
      let values = draggingPasteboard.readObjects(forClasses: classArray, options: searchOptions) ?? []
      for (index, value) in values.enumerated() {
        guard let writer = value as? NSPasteboardWriting else { continue }
        let item = NSDraggingItem(pasteboardWriter: writer)
        let point = view?.convert(draggingLocation, from: nil) ?? draggingLocation
        item.setDraggingFrame(NSRect(origin: point, size: NSSize(width: 16, height: 16)),
          contents: NSImage(size: NSSize(width: 16, height: 16)))
        var stop: ObjCBool = false
        block(item, index, &stop)
        if stop.boolValue { break }
      }
    }
  }
}
#endif

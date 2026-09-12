#if os(macOS)
import AppKit
import SwiftUI

/// SwiftUI's menu builder cannot host Finder's custom tag row. Attach the same NSMenu
/// used by icon view to the native table while keeping SwiftUI's table, selection and columns.
struct MacPrayerTableMenu: NSViewRepresentable {
  let items: [MacPrayerLibraryItem]
  let selectedID: String?
  let makeMenu: (MacPrayerLibraryItem) -> NSMenu
  let onImport: () -> Void

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeNSView(context: Context) -> Anchor {
    let view = Anchor()
    view.onAttach = { [weak coordinator = context.coordinator, weak view] in
      guard let view else { return }
      coordinator?.attach(from: view)
    }
    return view
  }

  func updateNSView(_ view: Anchor, context: Context) {
    context.coordinator.parent = self
    context.coordinator.attach(from: view)
  }

  static func dismantleNSView(_ view: Anchor, coordinator: Coordinator) {
    coordinator.isActive = false
    coordinator.stopMonitoring()
    if coordinator.table?.menu === coordinator.menu { coordinator.table?.menu = nil }
    view.onAttach = nil
  }

  final class Anchor: NSView {
    var onAttach: (() -> Void)?
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); onAttach?() }
    override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); onAttach?() }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
  }

  final class Coordinator: NSObject, NSMenuDelegate {
    var parent: MacPrayerTableMenu
    weak var table: NSTableView?
    let menu = NSMenu()
    var isActive = true
    private weak var anchor: NSView?
    private var eventMonitor: Any?
    private var contextRow: Int?

    init(_ parent: MacPrayerTableMenu) {
      self.parent = parent
      super.init()
      menu.autoenablesItems = false
      menu.delegate = self
    }

    func stopMonitoring() {
      if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
      eventMonitor = nil
      anchor = nil
    }

    func attach(from anchor: NSView) {
      guard isActive else { return }
      self.anchor = anchor
      if anchor.window != nil { startMonitoring() }
      DispatchQueue.main.async { [weak self, weak anchor] in
        guard let self, self.isActive, let anchor, self.anchor === anchor,
              let window = anchor.window else { return }
        self.startMonitoring()
        _ = self.tableForContext(in: window)
      }
    }

    /// SwiftUI can create or replace its native table after the anchor's lifecycle callbacks.
    /// Resolve it when needed, without a timer or relying on another SwiftUI update.
    func tableForContext(in window: NSWindow?) -> NSTableView? {
      guard isActive, let anchor, let window, anchor.window === window,
            window.attachedSheet == nil, let root = window.contentView else { return nil }
      let current = Self.findTable(in: root)
      if table !== current {
        if table?.menu === menu { table?.menu = nil }
        table = current
      }
      if let current, current.menu !== menu { current.menu = menu }
      return current
    }

    private func startMonitoring() {
      guard eventMonitor == nil else { return }
      // SwiftUI's primary-action support supplies its own menu(for:). Install before
      // the table exists so its first contextual gesture can resolve the finished view.
      eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown, .keyDown]) { [weak self] event in
        let contextual = event.type == .rightMouseDown
          || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
          || (event.type == .keyDown && event.keyCode == 109 && event.modifierFlags.contains(.shift))
        guard contextual, let self, let table = self.tableForContext(in: event.window),
              self.handles(event, in: table) else { return event }
        self.contextRow = self.row(for: event, in: table)
        self.menuNeedsUpdate(self.menu)
        if event.type == .keyDown {
          let row = self.contextRow ?? -1
          let rect = row >= 0 ? table.rect(ofRow: row) : table.visibleRect
          self.menu.popUp(positioning: nil, at: NSPoint(x: rect.minX + 24, y: rect.midY), in: table)
        } else {
          NSMenu.popUpContextMenu(self.menu, with: event, for: table)
        }
        self.contextRow = nil
        return nil
      }
    }

    func handles(_ event: NSEvent, in table: NSTableView) -> Bool {
      guard event.window === table.window, table.window?.attachedSheet == nil else { return false }
      if event.type == .keyDown {
        // Keyboard users can open the selected prayer's menu with Shift-F10.
        guard event.keyCode == 109, event.modifierFlags.contains(.shift) else { return false }
        guard let responder = table.window?.firstResponder as? NSView else { return false }
        return responder === table || responder.isDescendant(of: table)
      }
      guard event.type == .rightMouseDown || (event.type == .leftMouseDown && event.modifierFlags.contains(.control)) else { return false }
      // SwiftUI may keep the table's drawing rect wider than its clipped column. Use
      // the actual native hit target so sidebar/toolbar menus cannot be intercepted.
      guard let content = table.window?.contentView else { return false }
      let point = content.superview?.convert(event.locationInWindow, from: nil) ?? event.locationInWindow
      guard let hit = content.hitTest(point) else { return false }
      return hit === table || hit.isDescendant(of: table)
    }

    func row(for event: NSEvent?, in table: NSTableView) -> Int {
      if let event, [.rightMouseDown, .leftMouseDown, .rightMouseUp, .leftMouseUp].contains(event.type) {
        return table.row(at: table.convert(event.locationInWindow, from: nil))
      }
      return parent.items.firstIndex { $0.id == parent.selectedID } ?? -1
    }

    private static func findTable(in view: NSView) -> NSTableView? {
      if let table = view as? NSTableView, table.accessibilityIdentifier() == "macLibrary.listView" { return table }
      return view.subviews.lazy.compactMap { findTable(in: $0) }.first
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
      menu.removeAllItems()
      guard let table else { return }
      let row = contextRow ?? self.row(for: nil, in: table)
      guard parent.items.indices.contains(row) else {
        MacPrayerLibraryMenu.add(String(localized: "macLibrary.import", defaultValue: "Import Prayer Packs…"),
          to: menu, enabled: true, action: parent.onImport)
        return
      }
      let contents = parent.makeMenu(parent.items[row])
      while let item = contents.items.first {
        contents.removeItem(item)
        menu.addItem(item)
      }
    }
  }
}
#endif

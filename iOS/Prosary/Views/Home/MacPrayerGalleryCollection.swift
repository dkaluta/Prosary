#if os(macOS)
import AppKit
import SwiftUI

/// The collection owns selection gestures and keyboard navigation; SwiftUI owns the gallery
/// filters and batch action. Artwork hosts are presentation-only so they cannot steal events.
struct MacPrayerGalleryCollection: NSViewRepresentable {
  let items: [MacPrayerLibraryItem]
  @Binding var selection: Set<String>
  let downloadedDevotionIDs: Set<String>
  let canRemoveDownload: (MacPrayerLibraryItem) -> Bool
  let onRemoveDownload: (MacPrayerLibraryItem) -> Void
  let onActivate: ([MacPrayerLibraryItem]) -> Void
  @Environment(\.layoutDirection) private var layoutDirection
  @Environment(\.isEnabled) private var isEnabled

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeNSView(context: Context) -> NSScrollView {
    context.coordinator.makeScrollView()
  }

  func updateNSView(_ scroll: NSScrollView, context: Context) {
    context.coordinator.update(self, scroll: scroll)
  }

  static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
    coordinator.isActive = false
    coordinator.collection?.galleryDelegate = nil
    coordinator.collection?.delegate = nil
    coordinator.collection?.dataSource = nil
  }

  static func selectionPaths(for ids: Set<String>, items: [MacPrayerLibraryItem]) -> Set<IndexPath> {
    Set(items.enumerated().compactMap { ids.contains($0.element.id) ? IndexPath(item: $0.offset, section: 0) : nil })
  }

  static func selectedItems(in items: [MacPrayerLibraryItem], at paths: Set<IndexPath>) -> [MacPrayerLibraryItem] {
    items.enumerated().compactMap { paths.contains(IndexPath(item: $0.offset, section: 0)) ? $0.element : nil }
  }

  final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
    var parent: MacPrayerGalleryCollection
    weak var collection: GalleryCollectionView?
    var isActive = true
    private var updating = false
    private var itemIDs: [String] = []

    init(_ parent: MacPrayerGalleryCollection) { self.parent = parent }

    func makeScrollView() -> NSScrollView {
      let scroll = GalleryScrollView()
      scroll.hasVerticalScroller = true
      scroll.hasHorizontalScroller = false
      scroll.autohidesScrollers = true
      scroll.drawsBackground = false
      let collection = GalleryCollectionView()
      collection.backgroundColors = [.textBackgroundColor]
      collection.isSelectable = true
      collection.allowsMultipleSelection = true
      collection.allowsEmptySelection = true
      collection.dataSource = self
      collection.delegate = self
      collection.galleryDelegate = self
      collection.collectionViewLayout = Self.makeLayout()
      collection.register(GalleryCollectionItem.self, forItemWithIdentifier: GalleryCollectionItem.identifier)
      collection.autoresizingMask = [.width]
      collection.setAccessibilityIdentifier("macGallery.collection")
      collection.setAccessibilityLabel(String(localized: "macLibrary.gallery", defaultValue: "Prayer Gallery"))
      scroll.documentView = collection
      self.collection = collection
      return scroll
    }

    private static func makeLayout() -> NSCollectionViewLayout {
      NSCollectionViewCompositionalLayout { _, environment in
        let width = environment.container.effectiveContentSize.width
        let columns = max(1, Int((max(0, width - 48) + 24) / 204))
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
          widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(
          widthDimension: .fractionalWidth(1), heightDimension: .absolute(216)), subitem: item, count: columns)
        group.interItemSpacing = .fixed(24)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 18
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 24, bottom: 24, trailing: 24)
        return section
      }
    }

    func update(_ parent: MacPrayerGalleryCollection, scroll: NSScrollView) {
      self.parent = parent
      guard let collection else { return }
      collection.interactionEnabled = parent.isEnabled
      let direction: NSUserInterfaceLayoutDirection = parent.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
      if collection.userInterfaceLayoutDirection != direction {
        collection.userInterfaceLayoutDirection = direction
        collection.collectionViewLayout?.invalidateLayout()
      }
      updating = true
      let ids = parent.items.map(\.id)
      if itemIDs != ids {
        itemIDs = ids
        collection.reloadData()
      }
      // Do not assign an unchanged native selection: its Shift anchor and keyboard focus
      // belong to NSCollectionView and must survive a SwiftUI footer or selection update.
      let paths = MacPrayerGalleryCollection.selectionPaths(for: parent.selection, items: parent.items)
      if collection.selectionIndexPaths != paths { collection.selectionIndexPaths = paths }
      updating = false
      refreshVisibleItems()
      let visibleSelection = Set(MacPrayerGalleryCollection.selectedItems(in: parent.items, at: paths).map(\.id))
      if visibleSelection != parent.selection {
        DispatchQueue.main.async { [weak self] in
          guard let self, self.isActive else { return }
          // Recompute against the latest binding if another filter or selection changed.
          let retained = self.parent.selection.intersection(self.parent.items.map(\.id))
          if self.parent.selection != retained { self.parent.selection = retained }
        }
      }
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
      parent.items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
      let item = collectionView.makeItem(withIdentifier: GalleryCollectionItem.identifier, for: indexPath)
      guard let item = item as? GalleryCollectionItem, parent.items.indices.contains(indexPath.item) else { return item }
      configure(item, for: parent.items[indexPath.item])
      return item
    }

    private func configure(_ cell: GalleryCollectionItem, for item: MacPrayerLibraryItem) {
      cell.configure(item, collection: collection)
      cell.tile.onSelect = { [weak self] in self?.select(itemID: item.id) }
      cell.tile.onShowMenu = { [weak self, weak cell] in
        guard let self, let tile = cell?.tile, let menu = self.menu(for: item.id) else { return false }
        return menu.popUp(positioning: nil, at: NSPoint(x: tile.bounds.midX, y: tile.bounds.midY), in: tile)
      }
    }

    private func refreshVisibleItems() {
      guard let collection else { return }
      for case let cell as GalleryCollectionItem in collection.visibleItems() {
        guard let path = collection.indexPath(for: cell), parent.items.indices.contains(path.item) else { continue }
        configure(cell, for: parent.items[path.item])
      }
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
      publishSelection()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
      publishSelection()
    }

    private func publishSelection() {
      guard !updating, isActive, let collection else { return }
      let ids = Set(MacPrayerGalleryCollection.selectedItems(in: parent.items, at: collection.selectionIndexPaths).map(\.id))
      if parent.selection != ids { parent.selection = ids }
      collection.refreshSelectionAppearance()
    }

    private func select(itemID: String) {
      guard parent.isEnabled, let collection,
            let index = parent.items.firstIndex(where: { $0.id == itemID }) else { return }
      collection.window?.makeFirstResponder(collection)
      collection.selectionIndexPaths = [IndexPath(item: index, section: 0)]
      publishSelection()
    }

    func activateSelection() {
      guard parent.isEnabled, let collection else { return }
      let selected = MacPrayerGalleryCollection.selectedItems(in: parent.items, at: collection.selectionIndexPaths)
      if !selected.isEmpty { parent.onActivate(selected) }
    }

    func activate(itemID: String?) {
      guard parent.isEnabled, let itemID, let item = parent.items.first(where: { $0.id == itemID }) else { return }
      parent.onActivate([item])
    }

    func itemID(at point: NSPoint) -> String? {
      guard let path = collection?.indexPathForItem(at: point), parent.items.indices.contains(path.item) else { return nil }
      return parent.items[path.item].id
    }

    func menu(for itemID: String) -> NSMenu? {
      guard let item = parent.items.first(where: { $0.id == itemID }),
            parent.downloadedDevotionIDs.contains(item.devotionID) else { return nil }
      let menu = NSMenu()
      menu.autoenablesItems = false
      let remove = NSMenuItem(title: String(localized: "macLibrary.removeDownload", defaultValue: "Remove Download…"),
                              action: #selector(removeDownload(_:)), keyEquivalent: "")
      remove.target = self
      remove.representedObject = item.id
      remove.isEnabled = parent.isEnabled && parent.canRemoveDownload(item)
      if !remove.isEnabled {
        remove.toolTip = String(localized: "removal.downloadInUse", defaultValue: "Delete all saved copies of this prayer before removing its download.")
      }
      menu.addItem(remove)
      return menu
    }

    @objc private func removeDownload(_ sender: NSMenuItem) {
      guard let id = sender.representedObject as? String else { return }
      // Apply after native menu tracking ends, and validate the clicked item again.
      DispatchQueue.main.async { [weak self] in
        guard let self, self.isActive, self.parent.isEnabled,
              let item = self.parent.items.first(where: { $0.id == id }),
              self.parent.downloadedDevotionIDs.contains(item.devotionID), self.parent.canRemoveDownload(item) else { return }
        self.parent.onRemoveDownload(item)
      }
    }
  }
}

private final class GalleryScrollView: NSScrollView {
  override func tile() {
    super.tile()
    guard let collection = documentView as? NSCollectionView else { return }
    let widthChanged = abs(collection.frame.width - contentSize.width) > 0.5
    let height = max(contentSize.height, collection.collectionViewLayout?.collectionViewContentSize.height ?? 0)
    if widthChanged || abs(collection.frame.height - height) > 0.5 {
      collection.setFrameSize(NSSize(width: contentSize.width, height: height))
      if widthChanged { collection.collectionViewLayout?.invalidateLayout() }
    }
  }
}

final class GalleryCollectionView: NSCollectionView {
  weak var galleryDelegate: MacPrayerGalleryCollection.Coordinator?
  var interactionEnabled = true
  private var windowObservers: [NSObjectProtocol] = []

  override func mouseDown(with event: NSEvent) {
    guard interactionEnabled else { return }
    let clickedID = galleryDelegate?.itemID(at: convert(event.locationInWindow, from: nil))
    // Native tracking supplies Command/Shift/range/marquee/blank-area behavior.
    super.mouseDown(with: event)
    if event.clickCount == 2 { galleryDelegate?.activate(itemID: clickedID) }
  }

  override func rightMouseDown(with event: NSEvent) {
    guard interactionEnabled,
          let id = galleryDelegate?.itemID(at: convert(event.locationInWindow, from: nil)),
          let menu = galleryDelegate?.menu(for: id) else { return }
    NSMenu.popUpContextMenu(menu, with: event, for: self)
  }

  override func keyDown(with event: NSEvent) {
    guard interactionEnabled else { return }
    if event.keyCode == 36 || event.keyCode == 76 { galleryDelegate?.activateSelection() }
    else { super.keyDown(with: event) }
  }

  override func becomeFirstResponder() -> Bool {
    let result = super.becomeFirstResponder()
    refreshSelectionAppearance()
    return result
  }

  override func resignFirstResponder() -> Bool {
    let result = super.resignFirstResponder()
    DispatchQueue.main.async { [weak self] in self?.refreshSelectionAppearance() }
    return result
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
    windowObservers = []
    guard let window else { return }
    for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
      windowObservers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
        Task { @MainActor in self?.refreshSelectionAppearance() }
      })
    }
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    refreshSelectionAppearance()
  }

  func refreshSelectionAppearance() {
    for case let cell as GalleryCollectionItem in visibleItems() { cell.refreshAppearance() }
  }

  deinit { windowObservers.forEach { NotificationCenter.default.removeObserver($0) } }
}

private final class GalleryCollectionItem: NSCollectionViewItem {
  static let identifier = NSUserInterfaceItemIdentifier("ProsaryPrayerGalleryItem")
  let tile = GalleryTileView()

  override func loadView() { view = tile }
  override var isSelected: Bool { didSet { refreshAppearance() } }

  func configure(_ item: MacPrayerLibraryItem, collection: NSCollectionView?) {
    _ = view
    tile.collection = collection
    if let collection { tile.userInterfaceLayoutDirection = collection.userInterfaceLayoutDirection }
    tile.configure(item)
    refreshAppearance()
  }

  func refreshAppearance() {
    tile.selected = isSelected
    tile.updateAppearance()
  }
}

private struct GalleryCover: View {
  let imageKey: String?
  let cacheKey: String?
  let glyph: String?
  let symbol: String
  let tint: Color
  @Environment(\.colorScheme) private var colorScheme

  func hasSameArtwork(as other: Self) -> Bool {
    imageKey == other.imageKey && cacheKey == other.cacheKey && glyph == other.glyph
      && symbol == other.symbol && tint == other.tint
  }

  var body: some View {
    Group {
      if let imageKey {
        PrayerArtworkView(imageKey: imageKey, placeholder: .neutral)
          .scaledToFit()
          .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
          .shadow(color: .black.opacity(colorScheme == .dark ? 0.30 : 0.16), radius: 9, x: 0, y: 5)
          .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.08), radius: 2, x: 0, y: 1)
          .padding(.horizontal, 14).padding(.vertical, 12)
      } else if let glyph {
        Text(glyph).font(.system(size: 72))
      } else {
        Image(systemName: symbol).font(.system(size: 66, weight: .regular)).foregroundStyle(tint)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

private final class GalleryTileView: NSView {
  private let title = NSTextField(wrappingLabelWithString: "")
  private var coverHost: NSHostingView<GalleryCover>?
  private var cover: GalleryCover?
  weak var collection: NSCollectionView?
  var selected = false
  var onSelect: (() -> Void)?
  var onShowMenu: (() -> Bool)?

  override var isFlipped: Bool { true }
  // Keep the item's native view in the hit-test chain: NSCollectionView uses that identity
  // for point-to-item lookup. Artwork and labels must not become the event destination.
  override func hitTest(_ point: NSPoint) -> NSView? {
    super.hitTest(point) == nil ? nil : self
  }

  override func mouseDown(with event: NSEvent) { collection?.mouseDown(with: event) }
  override func rightMouseDown(with event: NSEvent) { collection?.rightMouseDown(with: event) }

  private var emphasized: Bool {
    guard let collection, let window, window.isKeyWindow else { return false }
    if window.firstResponder === collection { return true }
    return (window.firstResponder as? NSView)?.isDescendant(of: collection) == true
  }

  override init(frame: NSRect) {
    super.init(frame: frame)
    title.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    title.alignment = .center
    title.maximumNumberOfLines = 3
    title.lineBreakMode = .byTruncatingTail
    title.isSelectable = false
    title.setAccessibilityElement(false)
    addSubview(title)
    setAccessibilityElement(true)
    setAccessibilityRole(.button)
  }

  required init?(coder: NSCoder) { nil }

  func configure(_ item: MacPrayerLibraryItem) {
    if title.stringValue != item.title {
      title.stringValue = item.title
      needsLayout = true
    }
    title.baseWritingDirection = userInterfaceLayoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
    let imageKey = MacPrayerGalleryArtwork.imageKey(for: item.devotionID)
    let next = GalleryCover(imageKey: imageKey,
      cacheKey: imageKey.flatMap { PrayerPackStore.imageResource(for: $0)?.cacheKey },
      glyph: item.iconGlyph, symbol: item.systemImage, tint: item.color)
    if cover?.hasSameArtwork(as: next) != true {
      cover = next
      if let coverHost { coverHost.rootView = next }
      else {
        let host = NSHostingView(rootView: next)
        host.sizingOptions = []
        host.setAccessibilityElement(false)
        addSubview(host, positioned: .below, relativeTo: title)
        coverHost = host
      }
      needsLayout = true
    }
    setAccessibilityLabel(item.title)
    setAccessibilityIdentifier("macGallery.item.\(item.devotionID)")
    toolTip = item.title
  }

  override func layout() {
    super.layout()
    let width = max(1, min(230, bounds.width))
    coverHost?.frame = NSRect(x: (bounds.width - width) / 2, y: 0, width: width, height: 156)
    let titleWidth = max(1, width - 12)
    if title.preferredMaxLayoutWidth != titleWidth { title.preferredMaxLayoutWidth = titleWidth }
    let size = title.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: titleWidth, height: 54)) ?? .zero
    let actualWidth = min(titleWidth, ceil(size.width))
    title.frame = NSRect(x: (bounds.width - actualWidth) / 2, y: 168,
                         width: actualWidth, height: min(48, max(17, ceil(size.height))))
  }

  func updateAppearance() {
    title.textColor = selected && emphasized ? .alternateSelectedControlTextColor : .labelColor
    setAccessibilitySelected(selected)
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    guard selected else { return }
    let pictureWidth = max(1, min(230, bounds.width))
    let pictureBacking = NSRect(x: (bounds.width - pictureWidth) / 2 + 3, y: 3,
                               width: max(1, pictureWidth - 6), height: 150)
    let contrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    NSColor.labelColor.withAlphaComponent(contrast ? 0.16 : 0.07).setFill()
    NSBezierPath(roundedRect: pictureBacking, xRadius: 7, yRadius: 7).fill()
    (emphasized ? NSColor.selectedContentBackgroundColor : .unemphasizedSelectedContentBackgroundColor).setFill()
    NSBezierPath(roundedRect: title.frame.insetBy(dx: -4, dy: -2), xRadius: 4, yRadius: 4).fill()
  }

  override func accessibilityPerformPress() -> Bool {
    guard let onSelect else { return false }
    onSelect()
    return true
  }

  override func accessibilityPerformShowMenu() -> Bool { onShowMenu?() ?? false }
}
#endif

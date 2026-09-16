#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The menu bar follows the library window's current selection, including while focus is in
/// its search field. Prayer windows publish their own session actions separately.
struct MacLibraryActions {
  let canActOnSelection: Bool
  let openSelection: () -> Void
  let duplicateSelection: () -> Void
  let editSelection: () -> Void
  let importFiles: () -> Void
  let showLibrary: () -> Void
  let showCommunity: () -> Void
  var editTags: (() -> Void)? = nil
  var removeSelection: (() -> Void)? = nil
  var removeSelectionTitle: String? = nil
}

extension Notification.Name {
  static let macShowLibrary = Notification.Name("Prosary.macShowLibrary")
  static let macShowCommunity = Notification.Name("Prosary.macShowCommunity")
  static let macShowGallery = Notification.Name("Prosary.macShowGallery")
  static let macShowToday = Notification.Name("Prosary.macShowToday")
  static let macShowBasicPrayers = Notification.Name("Prosary.macShowBasicPrayers")
}

private struct MacLibraryActionsKey: FocusedValueKey {
  typealias Value = MacLibraryActions
}

private struct MacLibraryModalKey: FocusedValueKey {
  typealias Value = Bool
}

extension FocusedValues {
  var macLibraryActions: MacLibraryActions? {
    get { self[MacLibraryActionsKey.self] }
    set { self[MacLibraryActionsKey.self] = newValue }
  }

  var macLibraryIsModal: Bool? {
    get { self[MacLibraryModalKey.self] }
    set { self[MacLibraryModalKey.self] = newValue }
  }
}

/// A native collection of prayer configurations. Selecting a prayer inspects its identity;
/// opening it creates or activates a separate session window, leaving the library in place.
struct MacPrayerLibraryView: View {
  private enum Sidebar: Hashable { case all, today, gallery, basicPrayers, community, tag(String) }
  private enum DisplayStyle: String { case icons, list }

  @State private var model: MacPrayerLibraryModel
  @State private var sidebar: Sidebar? = .all
  @State private var pendingWidgetDestination: String?
  @State private var widgetTodayGeneration = 0
  @State private var selectedID: String?
  @State private var query = ""
  @State private var isBusy = false
  @State private var showsImporter = false
  @State private var isDropTargeted = false
  @State private var hasAttachedSheet = false
  @State private var editorPrayer: Prayer?
  @State private var renameTarget: MacPrayerTag?
  @State private var tagName = ""
  @State private var tagEditorTarget: MacPrayerLibraryItem?
  @State private var removalRequest: MacPrayerRemovalRequest?
  @AppStorage("macLibraryDisplayStyle") private var displayStyle = DisplayStyle.icons.rawValue
  @ObservedObject private var prayerLanguage = PrayerLanguageMonitor.shared
  @Environment(\.openWindow) private var openWindow

  init(model: MacPrayerLibraryModel) {
    _model = State(initialValue: model)
  }

  private var filteredItems: [MacPrayerLibraryItem] {
    model.items.filter { item in
      if case .tag(let id) = sidebar, !item.tagIDs.contains(id) { return false }
      let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
      return search.isEmpty || item.title.localizedCaseInsensitiveContains(search)
        || item.subtitle.localizedCaseInsensitiveContains(search)
    }
  }

  private var selectedItem: MacPrayerLibraryItem? {
    guard isLibrarySection else { return nil }
    return filteredItems.first { $0.id == selectedID }
  }

  private var isLibrarySection: Bool {
    switch sidebar { case .all, .tag: true; default: false }
  }

  private var detailTitle: String {
    if sidebar == .community { return label("macLibrary.community", "Community Devotions") }
    if sidebar == .today { return label("home.today.today", "Today") }
    if sidebar == .gallery { return label("macLibrary.gallery", "Prayer Gallery") }
    if sidebar == .basicPrayers { return label("basicPrayers.title", "Basic Prayers") }
    if case .tag(let id) = sidebar, let tag = model.tags.first(where: { $0.id == id }) { return tag.title }
    return label("macLibrary.title", "Library")
  }

  private var libraryLayout: some View {
    NavigationSplitView {
      List(selection: $sidebar) {
        Label(label("macLibrary.allPrayers", "All Prayers"), systemImage: "square.stack")
          .tag(Sidebar.all)
          .accessibilityIdentifier("macLibrary.allPrayers")
        Label(label("home.today.today", "Today"), systemImage: "calendar")
          .tag(Sidebar.today)
          .accessibilityIdentifier("macLibrary.today")
        Label(label("macLibrary.gallery", "Prayer Gallery"), systemImage: "square.grid.2x2")
          .tag(Sidebar.gallery)
          .accessibilityIdentifier("macLibrary.gallery")
        Label(label("basicPrayers.title", "Basic Prayers"), systemImage: "text.book.closed")
          .tag(Sidebar.basicPrayers)
          .accessibilityIdentifier("macLibrary.basicPrayers")
        Label(label("macLibrary.community", "Community Devotions"), systemImage: "globe")
          .tag(Sidebar.community)
          .accessibilityIdentifier("macLibrary.community")
        Section(label("macLibrary.tags", "Tags")) {
          ForEach(model.tags) { tag in
            Label {
              Text(tag.title)
            } icon: {
              Image(systemName: tag.colorID == nil ? "circle" : "circle.fill").foregroundStyle(tag.color)
            }
            .tag(Sidebar.tag(tag.id))
            .accessibilityIdentifier("macLibrary.tag.\(tag.id)")
            .contextMenu {
              Button(label("macLibrary.renameTag", "Rename Tag…")) {
                tagName = tag.title
                renameTarget = tag
              }
              Menu(label("macLibrary.tagColor", "Tag Color")) {
                Button(label("macLibrary.noColor", "No Color")) { model.setTagColor(tag, colorID: nil) }
                ForEach(MacPrayerTag.colors, id: \.0) { id, color, name in
                  Button { model.setTagColor(tag, colorID: id) } label: {
                    Label { Text(name) } icon: { Circle().fill(color) }
                  }
                }
              }
              Divider()
              Button(label("macLibrary.deleteTag", "Delete Tag"), role: .destructive) {
                if sidebar == .tag(tag.id) { sidebar = .all }
                model.deleteTag(tag)
              }
            }
          }
        }
      }
      .listStyle(.sidebar)
      .navigationSplitViewColumnWidth(min: 170, ideal: 210, max: 300)
      .navigationTitle(label("macLibrary.title", "Library"))
    } detail: {
      Group {
        if sidebar == .community {
          NavigationStack { RepositoryBrowserView(presentedAsSheet: false) }
        } else if sidebar == .today {
          MacTodayView()
            .id(widgetTodayGeneration)
        } else if sidebar == .gallery {
          MacPrayerGalleryView(items: model.galleryItems,
            includedDevotionIDs: Set(model.items.map(\.devotionID)),
            downloadedDevotionIDs: model.downloadedDevotionIDs,
            onAdd: { model.addToLibrary($0) }, onShowLibrary: showInLibrary,
            canRemoveDownload: { model.canRemoveDownload($0) },
            onRemoveDownload: { requestRemoval($0, downloadOnly: true) })
            .disabled(isBusy)
        } else if sidebar == .basicPrayers {
          BasicPrayersView { id in
            openWindow(id: "prayer", value: PrayerWindowRequest(route: .basicPrayer(id: id)))
          }
        } else {
          libraryContent
            .searchable(text: $query, placement: .toolbar,
                        prompt: label("macLibrary.search", "Search Prayers"))
        }
      }
      .navigationTitle(detailTitle)
      .toolbar(id: "Prosary.Library.Toolbar") { libraryToolbar }
      .overlay {
        if isDropTargeted {
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
            .padding(8)
            .allowsHitTesting(false)
        }
      }
      .dropDestination(for: URL.self) { urls, _ in
        guard !isModal && !isBusy else { return false }
        let files = urls.filter { $0.isFileURL && ["prosaryprayer", "zip"].contains($0.pathExtension.lowercased()) }
        guard !files.isEmpty else { return false }
        importFiles(files)
        return true
      } isTargeted: { isDropTargeted = $0 }
    }
  }

  private var libraryPresentation: some View {
    libraryLayout
    .focusedSceneValue(\.macLibraryActions, focusedActions)
    .focusedSceneValue(\.macLibraryIsModal, isModal)
    .modifier(MacToolbarCustomization())
    .popover(item: $tagEditorTarget) { target in
      MacPrayerTagEditor(tags: model.tags,
        selectedIDs: model.items.first(where: { $0.id == target.id })?.tagIDs ?? target.tagIDs,
        onSetNames: { model.setTags(named: $0, on: target) },
        onToggle: { model.setTag($0, on: target, enabled: $1) })
    }
    .background {
      MacWindowFocusReader(onActivate: {}, onClose: {}, onSheetChange: { hasAttachedSheet = $0 })
        .frame(width: 0, height: 0)
    }
    .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.prosaryPrayer, .zip],
                  allowsMultipleSelection: true) { result in
      switch result {
      case .success(let urls): importFiles(urls)
      case .failure(let error): model.error = error.localizedDescription
      }
    }
    .sheet(item: $editorPrayer, onDismiss: { Task { await model.reload() } }) { prayer in
      NavigationStack {
        if prayer.kind == .custom {
          RemindersOnlyEditorView(prayer: prayer)
        } else {
          FavoriteEditorView(prayer: prayer, isNew: false)
        }
      }
    }
    .alert(label("macLibrary.renameTagTitle", "Rename Tag"), isPresented: .init(
      get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } }), presenting: renameTarget
    ) { tag in
      TextField(label("macLibrary.tagName", "Tag Name"), text: $tagName)
      Button(label("macLibrary.rename", "Rename")) {
        model.renameTag(tag, to: tagName.trimmingCharacters(in: .whitespacesAndNewlines))
        renameTarget = nil
      }
      .keyboardShortcut(.defaultAction)
      Button("favoriteEditor.cancel", role: .cancel) { renameTarget = nil }
    }
    .alert(label("macLibrary.failed", "Could Not Complete Action"), isPresented: .init(
      get: { model.error != nil }, set: { if !$0 { model.error = nil } })
    ) {
      Button("common.ok") { model.error = nil }.keyboardShortcut(.defaultAction)
    } message: {
      Text(model.error ?? "")
    }
    .modifier(MacPrayerRemovalConfirmation(request: $removalRequest, onRemove: { remove($0) }))
  }

  var body: some View {
    libraryPresentation
    .task(id: "\(prayerLanguage.code)|\(prayerLanguage.showsPrayerNameInPrayerLanguage)|\(prayerLanguage.fallbackOrder.joined(separator: ","))") {
      await model.reload()
    }
    .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in
      Task { await model.reload() }
    }
    .onReceive(NotificationCenter.default.publisher(for: .prayerConfigurationDidDelete)) { notification in
      guard let id = notification.object as? UUID else { return }
      if editorPrayer?.id == id { editorPrayer = nil }
      if selectedID == id.uuidString { selectedID = nil }
      if tagEditorTarget?.prayer?.id == id { tagEditorTarget = nil }
    }
    .onReceive(NotificationCenter.default.publisher(for: .macShowLibrary)) { _ in
      guard !isModal else { return }
      sidebar = .all
    }
    .onReceive(NotificationCenter.default.publisher(for: .widgetNavigateLibrary)) { notification in
      guard let destination = notification.object as? String,
            ["today", "library"].contains(destination) else { return }
      pendingWidgetDestination = destination
      consumeWidgetDestination()
    }
    .onChange(of: isModal) { _, modal in
      if !modal { consumeWidgetDestination() }
    }
    .onReceive(NotificationCenter.default.publisher(for: .macShowCommunity)) { _ in
      guard !isModal else { return }
      sidebar = .community
    }
    .onReceive(NotificationCenter.default.publisher(for: .macShowGallery)) { _ in
      guard !isModal else { return }
      sidebar = .gallery
    }
    .onReceive(NotificationCenter.default.publisher(for: .macShowToday)) { _ in
      guard !isModal else { return }
      sidebar = .today
    }
    .onReceive(NotificationCenter.default.publisher(for: .macShowBasicPrayers)) { _ in
      guard !isModal else { return }
      sidebar = .basicPrayers
    }
    .onChange(of: sidebar) { _, _ in
      if selectedItem == nil { selectedID = nil }
    }
    .onChange(of: query) { _, _ in
      if selectedItem == nil { selectedID = nil }
    }
    .accessibilityIdentifier("macPrayerLibrary")
  }

  @ViewBuilder
  private var libraryContent: some View {
    if filteredItems.isEmpty {
      ContentUnavailableView {
        Label(model.items.isEmpty ? label("macLibrary.empty", "Your Prayer Library")
          : label("macLibrary.noMatches", "No Matching Prayers"), systemImage: "square.stack")
      } description: {
        Text(model.items.isEmpty
          ? label("macLibrary.emptyGalleryDetail", "Choose prayers from the gallery or import a prayer pack to begin your library.")
          : label("macLibrary.noMatchesDetail", "Try another search or tag."))
      } actions: {
        if model.items.isEmpty {
          Button(label("macLibrary.browseGallery", "Browse Prayer Gallery")) { sidebar = .gallery }
            .buttonStyle(.borderedProminent)
          Button(label("macLibrary.import", "Import Prayer Packs…")) { showsImporter = true }
        }
      }
    } else if displayStyle == DisplayStyle.list.rawValue {
      libraryTable
    } else {
      MacPrayerCollection(items: filteredItems, tags: model.tags, selectedID: $selectedID, isBusy: isBusy,
                          onOpen: { open($0) },
                          onDuplicate: duplicate, onEdit: edit,
                          onRemove: { requestRemoval($0) },
                          onTag: { tag, item, enabled in model.setTag(tag, on: item, enabled: enabled) },
                          onClearTags: { model.setTags(named: [], on: $0) },
                          onEditTags: { tagEditorTarget = $0 },
                          onImport: { showsImporter = true })
        .accessibilityIdentifier("macLibrary.iconView")
    }
  }

  private var libraryTable: some View {
    // Keep native row order identical to the context adapter's items. Any future
    // sorting must supply the same sorted array to both the table and its menu.
    Table(filteredItems, selection: $selectedID) {
      TableColumn(label("macLibrary.name", "Name")) { item in
        Label {
          Text(item.title)
        } icon: {
          if let glyph = item.iconGlyph { Text(glyph) }
          else { Image(systemName: item.systemImage).foregroundStyle(item.color) }
        }
        .accessibilityIdentifier("macLibrary.item.\(item.id)")
      }
      TableColumn(label("macLibrary.details", "Details")) { item in
        Text(item.subtitle).foregroundStyle(.secondary)
      }
      TableColumn(label("macLibrary.tags", "Tags")) { item in
        HStack(spacing: 5) {
          ForEach(model.tags.filter { item.tagIDs.contains($0.id) }) { tag in
            Image(systemName: tag.colorID == nil ? "circle" : "circle.fill")
              .foregroundStyle(tag.color).frame(width: 9, height: 9)
              .help(tag.title).accessibilityLabel(tag.title)
          }
        }
      }
      .width(min: 60, ideal: 100, max: 150)
    }
    .contextMenu(forSelectionType: String.self) { _ in
      EmptyView()
    } primaryAction: { ids in
      if let item = filteredItems.first(where: { ids.contains($0.id) }) { open(item) }
    }
    .background(MacPrayerTableMenu(items: filteredItems, selectedID: selectedID,
      makeMenu: itemMenu, onImport: { showsImporter = true }))
    .onKeyPress(.return) {
      guard let selectedItem else { return .ignored }
      open(selectedItem)
      return .handled
    }
    .accessibilityIdentifier("macLibrary.listView")
  }

  @ToolbarContentBuilder
  private var libraryToolbar: some CustomizableToolbarContent {
    ToolbarItem(id: "view", placement: .primaryAction) {
      Picker(label("macLibrary.viewStyle", "Library View"), selection: $displayStyle) {
        Label(label("macLibrary.gridView", "Icon View"), systemImage: "square.grid.2x2").tag(DisplayStyle.icons.rawValue)
        Label(label("macLibrary.listView", "List View"), systemImage: "list.bullet").tag(DisplayStyle.list.rawValue)
      }
      .pickerStyle(.segmented)
      .disabled(!isLibrarySection)
      .help(label("macLibrary.viewStyle", "Library View"))
      .accessibilityIdentifier("macLibrary.viewStyle")
    }
    ToolbarItem(id: "open", placement: .primaryAction) {
      Button { if let selectedItem { open(selectedItem) } } label: {
        Label(label("macLibrary.open", "Open"), systemImage: "play.fill")
      }
      .disabled(selectedItem == nil || isBusy)
      .help(label("macLibrary.open", "Open"))
      .accessibilityIdentifier("macLibrary.open")
    }
    ToolbarItem(id: "settings", placement: .primaryAction) {
      Button { if let selectedItem { edit(selectedItem) } } label: {
        Label(label("macLibrary.prayerSettings", "Prayer Settings…"), systemImage: "slider.horizontal.3")
      }
      .disabled(selectedItem == nil || isBusy)
      .help(label("macLibrary.prayerSettings", "Prayer Settings…"))
      .accessibilityIdentifier("macLibrary.settings")
    }
    ToolbarItem(id: "duplicate", placement: .primaryAction) {
      Button { if let selectedItem { duplicate(selectedItem) } } label: {
        Label(label("macLibrary.duplicate", "Duplicate"), systemImage: "plus.square.on.square")
      }
      .disabled(selectedItem == nil || isBusy)
      .help(label("macLibrary.duplicate", "Duplicate"))
      .accessibilityIdentifier("macLibrary.duplicate")
    }
    ToolbarItem(id: "tags", placement: .primaryAction) {
      Button { tagEditorTarget = selectedItem } label: {
        Label(label("macLibrary.editTags", "Tags…"), systemImage: "tag")
      }
      .disabled(selectedItem == nil || isBusy)
      .help(label("macLibrary.editTags", "Tags…"))
      .accessibilityIdentifier("macLibrary.editTags")
    }
    ToolbarItem(id: "add", placement: .primaryAction) {
      Menu {
        Button(label("macLibrary.browseGallery", "Browse Prayer Gallery")) { sidebar = .gallery }
        Button(label("macLibrary.import", "Import Prayer Packs…")) { showsImporter = true }
        Button(label("macLibrary.browse", "Browse Community Devotions")) { sidebar = .community }
      } label: {
        Label(label("macLibrary.add", "Add Prayer"), systemImage: "plus")
      }
      .help(label("macLibrary.add", "Add Prayer"))
      .accessibilityIdentifier("macLibrary.add")
    }
    ToolbarItem(id: "today", placement: .primaryAction) {
      Button { sidebar = .today } label: {
        Label(label("home.today.today", "Today"), systemImage: "calendar")
      }
      .help(label("home.today.today", "Today"))
    }
    .defaultCustomization(.hidden)
    ToolbarItem(id: "gallery", placement: .primaryAction) {
      Button { sidebar = .gallery } label: {
        Label(label("macLibrary.gallery", "Prayer Gallery"), systemImage: "square.grid.2x2")
      }
      .help(label("macLibrary.gallery", "Prayer Gallery"))
    }
    .defaultCustomization(.hidden)
  }

  private func itemMenu(_ item: MacPrayerLibraryItem) -> NSMenu {
    MacPrayerLibraryMenu.make(item: item, tags: model.tags, isBusy: isBusy,
      onOpen: { open(item) }, onDuplicate: { duplicate(item) }, onEdit: { edit(item) },
      onRemove: { requestRemoval(item) },
      onTag: { model.setTag($0, on: item, enabled: $1) },
      onClearTags: { model.setTags(named: [], on: item) },
      onEditTags: { tagEditorTarget = item })
  }

  private func consumeWidgetDestination() {
    guard !isModal, let destination = pendingWidgetDestination else { return }
    pendingWidgetDestination = nil
    if destination == "today" {
      // Recreate the date browser deterministically, even when Today is already selected.
      widgetTodayGeneration += 1
      sidebar = .today
    } else {
      sidebar = .all
    }
  }

  private var isModal: Bool {
    hasAttachedSheet || editorPrayer != nil || renameTarget != nil || showsImporter || model.error != nil
      || removalRequest != nil || tagEditorTarget != nil
  }

  private var focusedActions: MacLibraryActions? {
    guard !isModal else { return nil }
    return MacLibraryActions(
      canActOnSelection: selectedItem != nil && !isBusy,
      openSelection: { if let selectedItem { open(selectedItem) } },
      duplicateSelection: { if let selectedItem { duplicate(selectedItem) } },
      editSelection: { if let selectedItem { edit(selectedItem) } },
      importFiles: { showsImporter = true },
      showLibrary: { sidebar = .all },
      showCommunity: { sidebar = .community },
      editTags: { if let selectedItem { tagEditorTarget = selectedItem } },
      removeSelection: { if let selectedItem { requestRemoval(selectedItem) } },
      removeSelectionTitle: selectedItem.map { removalMenuTitle(for: $0) })
  }

  private func removalMenuTitle(for item: MacPrayerLibraryItem) -> String {
    item.prayer == nil ? label("macLibrary.removeFromLibrary", "Remove from Library…")
      : label("macLibrary.deletePrayer", "Delete Prayer…")
  }

  private func requestRemoval(_ item: MacPrayerLibraryItem, downloadOnly: Bool = false) {
    guard !isBusy, !isModal else { return }
    isBusy = true
    Task {
      defer { isBusy = false }
      do { removalRequest = try await model.removalRequest(for: item, downloadOnly: downloadOnly) }
      catch { model.error = error.localizedDescription }
    }
  }

  private func remove(_ request: MacPrayerRemovalRequest) {
    removalRequest = nil
    isBusy = true
    Task {
      defer { isBusy = false }
      do {
        try await model.remove(request)
        if selectedID == request.item.id { selectedID = nil }
      } catch { model.error = error.localizedDescription }
    }
  }

  private func showInLibrary(_ item: MacPrayerLibraryItem) {
    sidebar = .all
    query = ""
    selectedID = model.items.first(where: { $0.devotionID == item.devotionID })?.id
  }

  private func importFiles(_ urls: [URL]) {
    guard !isBusy else { return }
    isBusy = true
    Task {
      defer { isBusy = false }
      if await model.importFiles(urls) { sidebar = .gallery }
    }
  }

  private func open(_ item: MacPrayerLibraryItem, newWindow: Bool = false) {
    guard !isBusy else { return }
    isBusy = true
    Task {
      defer { isBusy = false }
      do {
        let prayer = try await model.prayer(for: item)
        await model.reload()
        selectedID = prayer.id.uuidString
        openWindow(id: "prayer", value: PrayerWindowRequest(route: .prayer(id: prayer.id), newWindow: newWindow))
      } catch { model.error = error.localizedDescription }
    }
  }

  private func edit(_ item: MacPrayerLibraryItem) {
    guard !isBusy else { return }
    isBusy = true
    Task {
      defer { isBusy = false }
      do {
        let prayer = try await model.prayer(for: item)
        await model.reload()
        selectedID = prayer.id.uuidString
        editorPrayer = prayer
      } catch { model.error = error.localizedDescription }
    }
  }

  private func duplicate(_ item: MacPrayerLibraryItem) {
    guard !isBusy else { return }
    isBusy = true
    Task {
      defer { isBusy = false }
      do {
        let copy = try await model.duplicate(item)
        sidebar = .all
        query = ""
        selectedID = copy.id.uuidString
        editorPrayer = copy
      } catch { model.error = error.localizedDescription }
    }
  }

  private func label(_ key: StaticString, _ fallback: String) -> String {
    String(localized: key, defaultValue: String.LocalizationValue(stringLiteral: fallback))
  }
}

/// AppKit supplies native selection, arrow-key navigation, scrolling and accessibility for the
/// icon view. Context targeting stays separate from selection, including in inactive windows.
struct MacPrayerCollection: NSViewRepresentable {
  let items: [MacPrayerLibraryItem]
  let tags: [MacPrayerTag]
  @Binding var selectedID: String?
  let isBusy: Bool
  let onOpen: (MacPrayerLibraryItem) -> Void
  let onDuplicate: (MacPrayerLibraryItem) -> Void
  let onEdit: (MacPrayerLibraryItem) -> Void
  let onRemove: (MacPrayerLibraryItem) -> Void
  let onTag: (MacPrayerTag, MacPrayerLibraryItem, Bool) -> Void
  let onClearTags: (MacPrayerLibraryItem) -> Void
  let onEditTags: (MacPrayerLibraryItem) -> Void
  let onImport: () -> Void

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeNSView(context: Context) -> NSScrollView {
    context.coordinator.makeScrollView()
  }

  func updateNSView(_ scroll: NSScrollView, context: Context) {
    context.coordinator.update(self)
  }

  final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate, NSMenuDelegate {
    var parent: MacPrayerCollection
    weak var collection: PrayerCollectionView?
    var signature: [String] = []
    var updating = false
    var contextPath: IndexPath?

    init(_ parent: MacPrayerCollection) { self.parent = parent }

    func makeScrollView() -> NSScrollView {
      let scroll = PrayerLibraryScrollView()
      scroll.hasVerticalScroller = true
      scroll.autohidesScrollers = true
      scroll.drawsBackground = false
      let collection = PrayerCollectionView()
      collection.backgroundColors = [.textBackgroundColor]
      collection.isSelectable = true
      collection.allowsMultipleSelection = false
      collection.allowsEmptySelection = true
      collection.dataSource = self
      collection.delegate = self
      collection.libraryDelegate = self
      let layout = NSCollectionViewFlowLayout()
      layout.itemSize = NSSize(width: 220, height: 150)
      layout.minimumInteritemSpacing = 12
      layout.minimumLineSpacing = 12
      layout.sectionInset = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
      collection.collectionViewLayout = layout
      collection.register(PrayerCollectionItem.self, forItemWithIdentifier: PrayerCollectionItem.identifier)
      collection.autoresizingMask = [.width]
      scroll.documentView = collection
      self.collection = collection
      return scroll
    }

    func update(_ parent: MacPrayerCollection) {
      self.parent = parent
      guard let collection else { return }
      let signature = parent.items.map { "\($0.id)|\($0.title)|\($0.subtitle)|\($0.tagIDs.sorted().joined(separator: ","))" }
        + parent.tags.map { "\($0.id)|\($0.title)|\($0.colorID ?? "none")" }
      updating = true
      if signature != self.signature {
        self.signature = signature
        collection.reloadData()
      }
      let paths: Set<IndexPath> = parent.items.firstIndex(where: { $0.id == parent.selectedID })
        .map { [IndexPath(item: $0, section: 0)] } ?? []
      if collection.selectionIndexPaths != paths {
        collection.selectionIndexPaths = paths
        if !paths.isEmpty { collection.scrollToItems(at: paths, scrollPosition: .nearestVerticalEdge) }
      }
      updating = false
      collection.refreshAppearance()
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
      parent.items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
      let cell = collectionView.makeItem(withIdentifier: PrayerCollectionItem.identifier, for: indexPath)
      guard let cell = cell as? PrayerCollectionItem, parent.items.indices.contains(indexPath.item) else { return cell }
      let item = parent.items[indexPath.item]
      cell.configure(item, tags: parent.tags.filter { item.tagIDs.contains($0.id) }, collection: collectionView)
      cell.tile.isContextTarget = contextPath == indexPath
      cell.tile.onOpen = { [weak self] in self?.parent.onOpen(item) }
      cell.tile.onShowMenu = { [weak self, weak cell] in
        guard let self, let tile = cell?.tile else { return false }
        return self.menu(at: indexPath).popUp(positioning: nil,
          at: NSPoint(x: tile.bounds.midX, y: tile.bounds.midY), in: tile)
      }
      return cell
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
      selectionChanged(collectionView)
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
      selectionChanged(collectionView)
    }

    private func selectionChanged(_ collectionView: NSCollectionView) {
      guard !updating else { return }
      let index = collectionView.selectionIndexPaths.first?.item
      parent.selectedID = index.flatMap { parent.items.indices.contains($0) ? parent.items[$0].id : nil }
      collection?.refreshAppearance()
    }

    func open(at path: IndexPath?) {
      guard let path, parent.items.indices.contains(path.item), !parent.isBusy else { return }
      parent.onOpen(parent.items[path.item])
    }

    func menu(at path: IndexPath?) -> NSMenu {
      contextPath = path
      collection?.refreshAppearance()
      guard let path, parent.items.indices.contains(path.item) else {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        MacPrayerLibraryMenu.add(String(localized: "macLibrary.import", defaultValue: "Import Prayer Packs…"),
          to: menu, enabled: !parent.isBusy, action: parent.onImport)
        return menu
      }
      let item = parent.items[path.item]
      let menu = MacPrayerLibraryMenu.make(item: item, tags: parent.tags, isBusy: parent.isBusy,
        onOpen: { [weak self] in self?.parent.onOpen(item) },
        onDuplicate: { [weak self] in self?.parent.onDuplicate(item) },
        onEdit: { [weak self] in self?.parent.onEdit(item) },
        onRemove: { [weak self] in self?.parent.onRemove(item) },
        onTag: { [weak self] tag, enabled in self?.parent.onTag(tag, item, enabled) },
        onClearTags: { [weak self] in self?.parent.onClearTags(item) },
        onEditTags: { [weak self] in self?.parent.onEditTags(item) })
      menu.delegate = self
      return menu
    }

    func menuDidClose(_ menu: NSMenu) {
      contextPath = nil
      collection?.refreshAppearance()
    }
  }
}

private final class PrayerLibraryScrollView: NSScrollView {
  override func tile() {
    super.tile()
    guard let collection = documentView as? NSCollectionView,
          abs(collection.frame.width - contentSize.width) > 0.5 else { return }
    collection.setFrameSize(NSSize(width: contentSize.width, height: collection.frame.height))
    collection.collectionViewLayout?.invalidateLayout()
  }
}

final class PrayerCollectionView: NSCollectionView {
  weak var libraryDelegate: MacPrayerCollection.Coordinator?
  private var windowObservers: [NSObjectProtocol] = []

  override func mouseDown(with event: NSEvent) {
    if event.modifierFlags.contains(.control) {
      rightMouseDown(with: event)
      return
    }
    super.mouseDown(with: event)
    if event.clickCount == 2 {
      libraryDelegate?.open(at: indexPathForItem(at: convert(event.locationInWindow, from: nil)))
    }
  }

  override func rightMouseDown(with event: NSEvent) {
    guard let menu = menu(for: event) else { return }
    NSMenu.popUpContextMenu(menu, with: event, for: self)
  }

  override func menu(for event: NSEvent) -> NSMenu? {
    let path = indexPathForItem(at: convert(event.locationInWindow, from: nil))
    return libraryDelegate?.menu(at: path)
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 36 || event.keyCode == 76 {
      libraryDelegate?.open(at: selectionIndexPaths.first)
    } else {
      super.keyDown(with: event)
    }
  }

  override func becomeFirstResponder() -> Bool {
    let result = super.becomeFirstResponder()
    refreshAppearance()
    return result
  }

  override func resignFirstResponder() -> Bool {
    let result = super.resignFirstResponder()
    DispatchQueue.main.async { [weak self] in self?.refreshAppearance() }
    return result
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
    windowObservers = []
    guard let window else { return }
    for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
      windowObservers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
        Task { @MainActor [weak self] in self?.refreshAppearance() }
      })
    }
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    refreshAppearance()
  }

  func refreshAppearance() {
    for item in visibleItems() {
      guard let cell = item as? PrayerCollectionItem else { continue }
      cell.tile.isContextTarget = indexPath(for: cell) == libraryDelegate?.contextPath
      cell.refreshAppearance()
    }
  }

  deinit { windowObservers.forEach { NotificationCenter.default.removeObserver($0) } }
}

private final class PrayerCollectionItem: NSCollectionViewItem {
  static let identifier = NSUserInterfaceItemIdentifier("ProsaryPrayerLibraryItem")
  let tile = PrayerCollectionTile()

  override func loadView() { view = tile }

  override var isSelected: Bool { didSet { refreshAppearance() } }

  func configure(_ item: MacPrayerLibraryItem, tags: [MacPrayerTag], collection: NSCollectionView) {
    _ = view
    tile.collection = collection
    tile.title.stringValue = item.title
    tile.subtitle.stringValue = item.subtitle
    tile.glyph.stringValue = item.iconGlyph ?? ""
    tile.glyph.isHidden = item.iconGlyph == nil
    tile.icon.isHidden = item.iconGlyph != nil
    tile.icon.image = NSImage(systemSymbolName: item.systemImage, accessibilityDescription: nil)
    tile.accentColor = NSColor(item.color)
    tile.setAccessibilityLabel(item.title)
    tile.setAccessibilityHelp(item.subtitle)
    tile.setAccessibilityIdentifier("macLibrary.item.\(item.id)")
    tile.toolTip = item.subtitle.isEmpty ? item.title : "\(item.title)\n\(item.subtitle)"
    tile.tagStrip.arrangedSubviews.forEach { tile.tagStrip.removeArrangedSubview($0); $0.removeFromSuperview() }
    for tag in tags {
      let dot = NSImageView()
      dot.image = NSImage(systemSymbolName: tag.colorID == nil ? "circle" : "circle.fill", accessibilityDescription: tag.title)
      dot.contentTintColor = NSColor(tag.color)
      dot.toolTip = tag.title
      dot.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([dot.widthAnchor.constraint(equalToConstant: 9), dot.heightAnchor.constraint(equalToConstant: 9)])
      tile.tagStrip.addArrangedSubview(dot)
    }
    refreshAppearance()
  }

  func refreshAppearance() {
    tile.selected = isSelected
    tile.updateAppearance()
  }
}

private final class PrayerCollectionTile: NSView {
  let title = NSTextField(wrappingLabelWithString: "")
  let subtitle = NSTextField(labelWithString: "")
  let glyph = NSTextField(labelWithString: "")
  let icon = NSImageView()
  let tagStrip = NSStackView()
  weak var collection: NSCollectionView?
  var selected = false
  var isContextTarget = false
  var accentColor: NSColor = .controlAccentColor
  var onOpen: (() -> Void)?
  var onShowMenu: (() -> Bool)?

  // Titles and symbols are presentation, not independent text controls. Keep the tile in
  // AppKit's hit-test chain, then let the collection handle selection and context targeting.
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
    title.font = .systemFont(ofSize: 13, weight: .semibold)
    title.maximumNumberOfLines = 2
    title.lineBreakMode = .byTruncatingTail
    subtitle.font = .systemFont(ofSize: 11)
    subtitle.lineBreakMode = .byTruncatingTail
    glyph.font = .systemFont(ofSize: 28)
    icon.symbolConfiguration = .init(pointSize: 28, weight: .regular)
    icon.imageScaling = .scaleProportionallyDown
    let top = NSStackView(views: [icon, glyph, NSView(), tagStrip])
    top.orientation = .horizontal
    top.alignment = .centerY
    tagStrip.orientation = .horizontal
    tagStrip.spacing = 4
    let stack = NSStackView(views: [top, title, subtitle, NSView()])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 8
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
      stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
      top.widthAnchor.constraint(equalTo: stack.widthAnchor),
      top.heightAnchor.constraint(equalToConstant: 32),
      icon.widthAnchor.constraint(equalToConstant: 32),
      icon.heightAnchor.constraint(equalToConstant: 32),
      title.widthAnchor.constraint(equalTo: stack.widthAnchor),
      subtitle.widthAnchor.constraint(equalTo: stack.widthAnchor),
    ])
    setAccessibilityElement(true)
    setAccessibilityRole(.button)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func accessibilityPerformPress() -> Bool {
    guard let onOpen else { return false }
    onOpen()
    return true
  }

  override func accessibilityPerformShowMenu() -> Bool { onShowMenu?() ?? false }

  func updateAppearance() {
    title.textColor = selected && emphasized ? .alternateSelectedControlTextColor : .labelColor
    subtitle.textColor = selected && emphasized ? .alternateSelectedControlTextColor : .secondaryLabelColor
    icon.contentTintColor = selected && emphasized ? .alternateSelectedControlTextColor
      : (window?.isKeyWindow == true ? accentColor : .secondaryLabelColor)
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 9, yRadius: 9)
    let background: NSColor = selected
      ? (emphasized ? .selectedContentBackgroundColor : .unemphasizedSelectedContentBackgroundColor)
      : .controlBackgroundColor
    background.setFill()
    outline.fill()
    (isContextTarget ? NSColor.keyboardFocusIndicatorColor : .separatorColor).setStroke()
    outline.lineWidth = isContextTarget ? 2 : 0.5
    outline.stroke()
  }
}
#endif

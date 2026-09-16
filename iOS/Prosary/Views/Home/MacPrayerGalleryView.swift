#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

/// Derive every action from the visible catalogue order, never the Set's iteration order.
struct MacPrayerGallerySelection {
  let items: [MacPrayerLibraryItem]
  let additions: [MacPrayerLibraryItem]

  init(visibleItems: [MacPrayerLibraryItem], selectedIDs: Set<String>, includedDevotionIDs: Set<String>) {
    items = visibleItems.filter { selectedIDs.contains($0.id) }
    additions = items.filter { !includedDevotionIDs.contains($0.devotionID) }
  }

  var retainedIDs: Set<String> { Set(items.map(\.id)) }
  var singleItem: MacPrayerLibraryItem? { items.count == 1 ? items.first : nil }
  var showTarget: MacPrayerLibraryItem? { additions.isEmpty ? items.first : nil }
}

/// Browsing and selection do not create saved configurations or open prayer windows.
struct MacPrayerGalleryView: View {
  let items: [MacPrayerLibraryItem]
  let includedDevotionIDs: Set<String>
  let downloadedDevotionIDs: Set<String>
  let onAdd: ([MacPrayerLibraryItem]) -> Void
  let onShowLibrary: (MacPrayerLibraryItem) -> Void
  let canRemoveDownload: (MacPrayerLibraryItem) -> Bool
  let onRemoveDownload: (MacPrayerLibraryItem) -> Void
  @State private var query = ""
  @State private var category = ""
  @State private var selectedIDs: Set<String> = []
  @State private var imageStore = MacPrayerGalleryImageStore.shared
  @State private var onlineImageItem: MacPrayerLibraryItem?
  @State private var imageError: String?
  @State private var isChangingImage = false
  @State private var imageTask: Task<Void, Never>?

  private var categoriesByDevotion: [String: [String]] {
    Dictionary(uniqueKeysWithValues: DevotionDirectory.all().map { ($0.id, $0.tags) })
  }

  /// Only authored interface labels become categories. Imported, unlocalized manifest
  /// tags remain discoverable in All without leaking raw identifiers into this chooser.
  private var categories: [(id: String, title: String)] {
    let tagsByID = categoriesByDevotion
    let tags = Set(items.flatMap { tagsByID[$0.devotionID] ?? [] })
    return tags.compactMap { id in
      let title = UILanguage.text("category.\(id)", language: UILanguage.current, fallback: "")
      return title.isEmpty ? nil : (id: id, title: title)
    }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
  }

  private var matches: [MacPrayerLibraryItem] {
    let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let tagsByID = categoriesByDevotion
    return items.filter {
      (search.isEmpty || $0.title.localizedStandardContains(search))
        && (category.isEmpty || tagsByID[$0.devotionID]?.contains(category) == true)
    }
  }

  private var selection: MacPrayerGallerySelection {
    MacPrayerGallerySelection(visibleItems: matches, selectedIDs: selectedIDs, includedDevotionIDs: includedDevotionIDs)
  }

  var body: some View {
    // Own the window's proposal before laying out the chooser. The collection's document
    // size must not become the ideal height of the entire NavigationSplitView.
    GeometryReader { geometry in
      VStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 14) {
          Text(String(localized: "macLibrary.galleryDetail", defaultValue: "Choose the prayers you want in your library. Each one remembers its own settings.", bundle: UILanguage.bundle, locale: UILanguage.locale))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          if categories.count > 1 {
            Picker(String(localized: "categories.title", defaultValue: "Categories", bundle: UILanguage.bundle, locale: UILanguage.locale), selection: $category) {
              Text(String(localized: "repository.allTags", defaultValue: "All", bundle: UILanguage.bundle, locale: UILanguage.locale)).tag("")
              ForEach(categories, id: \.id) { category in
                Text(category.title).tag(category.id)
              }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .accessibilityIdentifier("macGallery.categories")
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .fixedSize(horizontal: false, vertical: true)

        MacPrayerGalleryCollection(items: matches, selection: $selectedIDs,
          downloadedDevotionIDs: downloadedDevotionIDs,
          canRemoveDownload: canRemoveDownload, onRemoveDownload: onRemoveDownload,
          onActivate: activate, onImageAction: performImageAction,
          hasCustomImage: { imageStore.record(for: $0.devotionID) != nil },
          hasImageSource: { imageSource(for: $0) != nil }, artworkRevision: imageStore.revision,
          onDropImage: importImage)
          .disabled(isChangingImage)
          .overlay {
            if matches.isEmpty { ContentUnavailableView.search(text: query) }
          }
          .frame(minHeight: 0, maxHeight: .infinity)
          .clipped()

        Divider()
        HStack(spacing: 16) {
          if let selectedItem = selection.singleItem {
            Menu(String(localized: "galleryImage.image", defaultValue: "Image", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
              ForEach(MacPrayerGalleryImageAction.allCases, id: \.rawValue) { action in
                Button(action.title) { performImageAction(action, selectedItem) }
                  .disabled((action == .restoreDefault && imageStore.record(for: selectedItem.devotionID) == nil)
                    || (action == .viewSource && imageSource(for: selectedItem) == nil))
              }
            }
            .fixedSize()
            .disabled(isChangingImage)
            .accessibilityIdentifier("macGallery.imageMenu")
          }
          if isChangingImage { ProgressView().controlSize(.small) }
          if let selectedItem = selection.singleItem, downloadedDevotionIDs.contains(selectedItem.devotionID) {
            Button(String(localized: "macLibrary.removeDownload", defaultValue: "Remove Download…", bundle: UILanguage.bundle, locale: UILanguage.locale), role: .destructive) {
              onRemoveDownload(selectedItem)
            }
            .disabled(!canRemoveDownload(selectedItem))
            .help(canRemoveDownload(selectedItem) ? "" : String(localized: "removal.downloadInUse", defaultValue: "Delete all saved copies of this prayer before removing its download.", bundle: UILanguage.bundle, locale: UILanguage.locale))
            .accessibilityIdentifier("macGallery.removeDownload.\(selectedItem.devotionID)")
          }
          Text(selectionCaption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .accessibilityIdentifier("macGallery.selectionCount")
          Spacer(minLength: 12)
          Button { activate(selection.items) } label: {
            Text(selection.showTarget != nil
              ? String(localized: "macLibrary.showInLibrary", defaultValue: "Show in Library", bundle: UILanguage.bundle, locale: UILanguage.locale)
              : String(localized: "macLibrary.addToLibrary", defaultValue: "Add to Library", bundle: UILanguage.bundle, locale: UILanguage.locale))
              .frame(minWidth: 116)
          }
          .keyboardShortcut(.defaultAction)
          .disabled(selection.items.isEmpty)
          .accessibilityIdentifier(primaryActionIdentifier)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
        .fixedSize(horizontal: false, vertical: true)
      }
      .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .textBackgroundColor))
    .searchable(text: $query, placement: .toolbar,
      prompt: String(localized: "macLibrary.search", defaultValue: "Search Prayers", bundle: UILanguage.bundle, locale: UILanguage.locale))
    .onChange(of: matches.map(\.id)) { _, _ in selectedIDs = selection.retainedIDs }
    .sheet(item: $onlineImageItem) { item in
      MacPrayerGalleryImageSearchView(item: item, store: imageStore)
    }
    .alert(String(localized: "galleryImage.couldNotChange", defaultValue: "Couldn’t Change Image", bundle: UILanguage.bundle, locale: UILanguage.locale),
      isPresented: Binding(get: { imageError != nil }, set: { if !$0 { imageError = nil } })) {
        Button(String(localized: "common.ok", defaultValue: "OK", bundle: UILanguage.bundle, locale: UILanguage.locale), role: .cancel) { imageError = nil }
      } message: { Text(imageError ?? "") }
    .onDisappear { imageTask?.cancel() }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("macPrayerGallery")
  }

  private var selectionCaption: String {
    if let selectedItem = selection.singleItem { return selectedItem.title }
    guard !selection.items.isEmpty else { return "" }
    return String(format: String(localized: "macLibrary.gallerySelectionCount", defaultValue: "%lld Selected", bundle: UILanguage.bundle, locale: UILanguage.locale),
      Int64(selection.items.count))
  }

  private var primaryActionIdentifier: String {
    guard !selection.items.isEmpty else { return "macGallery.add" }
    let action = selection.additions.isEmpty ? "show" : "add"
    if let selectedItem = selection.singleItem { return "macGallery.\(action).\(selectedItem.devotionID)" }
    return "macGallery.\(action)Selection"
  }

  private func activate(_ selectedItems: [MacPrayerLibraryItem]) {
    let action = MacPrayerGallerySelection(visibleItems: matches, selectedIDs: Set(selectedItems.map(\.id)),
      includedDevotionIDs: includedDevotionIDs)
    if !action.additions.isEmpty { onAdd(action.additions) }
    else if let target = action.showTarget { onShowLibrary(target) }
  }

  private func imageSource(for item: MacPrayerLibraryItem) -> URL? {
    if let record = imageStore.record(for: item.devotionID) { return record.attribution?.sourceURL }
    // An imported author's default does not inherit the credit for a built-in cover.
    guard PrayerPackStore.galleryImageResource(for: item.devotionID) == nil else { return nil }
    return MacPrayerGalleryCredits.entries.first { $0.id == item.devotionID }?.source
  }

  private func performImageAction(_ action: MacPrayerGalleryImageAction, _ item: MacPrayerLibraryItem) {
    guard !isChangingImage else { return }
    switch action {
    case .chooseFile: chooseImage(for: item)
    case .searchOnline: onlineImageItem = item
    case .restoreDefault:
      do { try imageStore.remove(for: item.devotionID) }
      catch { imageError = error.localizedDescription }
    case .viewSource:
      if let source = imageSource(for: item) { NSWorkspace.shared.open(source) }
    }
  }

  private func chooseImage(for item: MacPrayerLibraryItem) {
    let panel = NSOpenPanel()
    panel.title = String(localized: "galleryImage.choose", defaultValue: "Choose Image…", bundle: UILanguage.bundle, locale: UILanguage.locale)
    panel.prompt = String(localized: "galleryImage.useImage", defaultValue: "Use Image", bundle: UILanguage.bundle, locale: UILanguage.locale)
    panel.allowedContentTypes = [.jpeg, .png, .heic, .heif, .tiff, .gif, .bmp, .webP]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    isChangingImage = true
    let completion: (NSApplication.ModalResponse) -> Void = { response in
      guard response == .OK, let url = panel.url else { isChangingImage = false; return }
      isChangingImage = false
      importImage(url, item)
    }
    if let window = NSApp.keyWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
    else { panel.begin(completionHandler: completion) }
  }

  private func importImage(_ url: URL, _ item: MacPrayerLibraryItem) {
    guard !isChangingImage else { return }
    isChangingImage = true
    imageTask = Task { @MainActor in
      defer { isChangingImage = false }
      do { try await imageStore.importImage(from: url, for: item.devotionID) }
      catch is CancellationError { }
      catch { imageError = error.localizedDescription }
    }
  }
}
#endif

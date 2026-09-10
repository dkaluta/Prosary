#if os(macOS)
import SwiftUI

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
          Text(String(localized: "macLibrary.galleryDetail", defaultValue: "Choose the prayers you want in your library. Each one remembers its own settings."))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          if categories.count > 1 {
            Picker(String(localized: "categories.title", defaultValue: "Categories"), selection: $category) {
              Text(String(localized: "repository.allTags", defaultValue: "All")).tag("")
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
          onActivate: activate)
          .overlay {
            if matches.isEmpty { ContentUnavailableView.search(text: query) }
          }
          .frame(minHeight: 0, maxHeight: .infinity)
          .clipped()

        Divider()
        HStack(spacing: 16) {
          if let selectedItem = selection.singleItem, downloadedDevotionIDs.contains(selectedItem.devotionID) {
            Button(String(localized: "macLibrary.removeDownload", defaultValue: "Remove Download…"), role: .destructive) {
              onRemoveDownload(selectedItem)
            }
            .disabled(!canRemoveDownload(selectedItem))
            .help(canRemoveDownload(selectedItem) ? "" : String(localized: "removal.downloadInUse", defaultValue: "Delete all saved copies of this prayer before removing its download."))
            .accessibilityIdentifier("macGallery.removeDownload.\(selectedItem.devotionID)")
          }
          Text(selectionCaption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .accessibilityIdentifier("macGallery.selectionCount")
          Spacer(minLength: 12)
          Button { activate(selection.items) } label: {
            Text(selection.showTarget != nil
              ? String(localized: "macLibrary.showInLibrary", defaultValue: "Show in Library")
              : String(localized: "macLibrary.addToLibrary", defaultValue: "Add to Library"))
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
      prompt: String(localized: "macLibrary.search", defaultValue: "Search Prayers"))
    .onChange(of: matches.map(\.id)) { _, _ in selectedIDs = selection.retainedIDs }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("macPrayerGallery")
  }

  private var selectionCaption: String {
    if let selectedItem = selection.singleItem { return selectedItem.title }
    guard !selection.items.isEmpty else { return "" }
    return String(format: String(localized: "macLibrary.gallerySelectionCount", defaultValue: "%lld Selected"),
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
}
#endif

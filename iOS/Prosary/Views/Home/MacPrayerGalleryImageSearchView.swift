#if os(macOS)
import SwiftUI

/// A search is explicit; selecting a result never changes the prayer until Use Image.
struct MacPrayerGalleryImageSearchView: View {
  let item: MacPrayerLibraryItem
  let store: MacPrayerGalleryImageStore
  private let service = MacGalleryImageSearch()
  @Environment(\.dismiss) private var dismiss
  @State private var query: String
  @State private var submittedQuery: String
  @State private var requestID = UUID()
  @State private var results: [MacGalleryImageSearch.Result] = []
  @State private var selection: Int?
  @State private var isSearching = true
  @State private var isSaving = false
  @State private var failure: String?
  @State private var saveTask: Task<Void, Never>?

  init(item: MacPrayerLibraryItem, store: MacPrayerGalleryImageStore) {
    self.item = item
    self.store = store
    _query = State(initialValue: item.title)
    _submittedQuery = State(initialValue: item.title)
  }

  private var selectedResult: MacGalleryImageSearch.Result? {
    results.first { $0.id == selection }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text(String(localized: "galleryImage.searchTitle", defaultValue: "Find a Gallery Image"))
          .font(.headline)
        Text(item.title).foregroundStyle(.secondary)
      }
      HStack {
        TextField(String(localized: "galleryImage.searchPrompt", defaultValue: "Search Wikimedia Commons"), text: $query)
          .textFieldStyle(.roundedBorder)
          .onSubmit(submitSearch)
          .accessibilityIdentifier("macGallery.imageSearch.query")
        Button(String(localized: "search.title", defaultValue: "Search"), action: submitSearch)
          .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
          .accessibilityIdentifier("macGallery.imageSearch.search")
      }
      .disabled(isSaving)

      ZStack {
        List(results, selection: $selection) { result in
          HStack(alignment: .center, spacing: 14) {
            MacGalleryImagePreview(result: result)
            .frame(width: 112, height: 84)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
              Text(result.title).lineLimit(2)
              if !result.author.isEmpty { Text(result.author).font(.callout).foregroundStyle(.secondary).lineLimit(2) }
              if !result.license.isEmpty { Text(result.license).font(.caption).foregroundStyle(.secondary) }
            }
          }
          .padding(.vertical, 6)
          .tag(result.id)
        }
        .listStyle(.bordered)
        .disabled(isSaving)
        .accessibilityIdentifier("macGallery.imageSearch.results")
        if isSearching {
          ProgressView(String(localized: "galleryImage.searching", defaultValue: "Searching…"))
            .padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        } else if results.isEmpty {
          ContentUnavailableView(
            failure == nil
              ? String(localized: "galleryImage.noResults", defaultValue: "No Images Found")
              : String(localized: "galleryImage.searchUnavailable", defaultValue: "Search Unavailable"),
            systemImage: "photo.on.rectangle.angled",
            description: Text(failure ?? String(localized: "galleryImage.trySearch", defaultValue: "Try another name or a description of the image.")))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      HStack {
        if let result = selectedResult {
          Link(String(localized: "galleryImage.source", defaultValue: "Image Source"), destination: result.sourceURL)
          if let url = result.licenseURL, !result.license.isEmpty { Link(result.license, destination: url) }
        } else {
          Text("Wikimedia Commons").foregroundStyle(.secondary)
        }
        Spacer()
      }
      .font(.callout)
      .frame(minHeight: 18)
      if let failure, !results.isEmpty {
        Text(failure).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("macGallery.imageSearch.error")
      }
      HStack {
        if isSaving { ProgressView().controlSize(.small) }
        Spacer()
        Button(String(localized: "favoriteEditor.cancel", defaultValue: "Cancel")) {
          saveTask?.cancel()
          dismiss()
        }
        .keyboardShortcut(.cancelAction)
        .accessibilityIdentifier("macGallery.imageSearch.cancel")
        Button(String(localized: "galleryImage.useImage", defaultValue: "Use Image"), action: saveImage)
          .keyboardShortcut(.defaultAction)
          .disabled(selectedResult == nil || isSearching || isSaving)
          .accessibilityIdentifier("macGallery.imageSearch.use")
      }
    }
    .padding(20)
    .frame(width: 660, height: 560)
    .task(id: requestID) { await search() }
    .onDisappear { saveTask?.cancel() }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("macGallery.imageSearch")
  }

  private func submitSearch() {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !isSaving else { return }
    selection = nil
    isSearching = true
    submittedQuery = trimmed
    requestID = UUID()
  }

  private func search() async {
    selection = nil
    results = []
    failure = nil
    isSearching = true
    do {
      let found = try await service.search(submittedQuery)
      guard !Task.isCancelled else { return }
      results = found
      isSearching = false
    } catch {
      guard !Task.isCancelled else { return }
      failure = error.localizedDescription
      isSearching = false
    }
  }

  private func saveImage() {
    guard let result = selectedResult, !isSearching, !isSaving else { return }
    isSaving = true
    failure = nil
    saveTask = Task { @MainActor in
      defer { isSaving = false }
      do {
        let data = try await service.download(result)
        try Task.checkCancellation()
        try await store.setImage(data: data, for: item.devotionID, attribution: result.attribution)
        dismiss()
      } catch {
        if !Task.isCancelled { failure = error.localizedDescription }
      }
    }
  }
}
#endif

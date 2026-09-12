#if os(macOS)
import SwiftUI

struct MacPrayerLibraryItem: Identifiable {
  let id: String
  let title: String
  let subtitle: String
  let systemImage: String
  let iconGlyph: String?
  let color: Color
  let prayer: Prayer?
  let devotionID: String
  let tagIDs: Set<String>
}

struct MacPrayerRemovalRequest: Identifiable {
  let id = UUID()
  let item: MacPrayerLibraryItem
  let removesDownload: Bool
  var downloadOnly = false

  var title: String {
    let format = downloadOnly
      ? String(localized: "macLibrary.removeDownloadTitle", defaultValue: "Remove Download for ‘%@’?")
      : item.prayer != nil
        ? String(localized: "macLibrary.deletePrayerTitle", defaultValue: "Delete ‘%@’?")
        : String(localized: "macLibrary.removeFromLibraryTitle", defaultValue: "Remove ‘%@’ from Library?")
    return String(format: format, item.title)
  }

  var message: String {
    if downloadOnly || (item.prayer == nil && removesDownload) {
      return String(localized: "macLibrary.removeDownloadDetail", defaultValue: "This removes the downloaded prayer from this device. You can import or download it again.")
    }
    if item.prayer != nil {
      return removesDownload
        ? String(localized: "macLibrary.deleteLastPrayerDetail", defaultValue: "This deletes this saved copy, its reminders, and the downloaded prayer from this device.")
        : String(localized: "macLibrary.deletePrayerDetail", defaultValue: "This deletes this saved copy and its reminders.")
    }
    return String(localized: "macLibrary.removeFromLibraryDetail", defaultValue: "You can add this prayer again from the gallery.")
  }

  var actionTitle: String {
    item.prayer != nil && !downloadOnly
      ? String(localized: "macLibrary.delete", defaultValue: "Delete")
      : String(localized: "macLibrary.remove", defaultValue: "Remove")
  }
}

struct MacPrayerTag: Identifiable {
  let id: String
  let title: String
  let colorID: String?

  var color: Color { Self.colors.first { $0.0 == colorID }?.1 ?? .secondary }

  static let colors: [(String, Color, String)] = [
    ("red", .red, String(localized: "macLibrary.tag.red", defaultValue: "Red")),
    ("orange", .orange, String(localized: "macLibrary.tag.orange", defaultValue: "Orange")),
    ("yellow", .yellow, String(localized: "macLibrary.tag.yellow", defaultValue: "Yellow")),
    ("green", .green, String(localized: "macLibrary.tag.green", defaultValue: "Green")),
    ("blue", .blue, String(localized: "macLibrary.tag.blue", defaultValue: "Blue")),
    ("purple", .purple, String(localized: "macLibrary.tag.purple", defaultValue: "Purple")),
    ("gray", .gray, String(localized: "macLibrary.tag.gray", defaultValue: "Gray"))
  ]
}

/// Library organization belongs to this Mac. Prayer configuration continues to use the
/// existing preset store, including its iCloud behavior; tags never alter a source pack.
struct MacLibraryTagStore {
  static let defaultsKey = "macLibraryTags"
  private let defaults: UserDefaults

  private struct StoredTag: Codable {
    let id: String
    var name: String
    var colorID: String?

    var tag: MacPrayerTag { MacPrayerTag(id: id, title: name, colorID: colorID) }
  }

  private struct State: Codable {
    let version: Int
    var tags: [StoredTag]
    var assignments: [String: [String]] = [:]

    static var empty: State { State(version: 3, tags: []) }
  }

  private struct LegacyState: Decodable {
    let names: [String: String]
    let assignments: [String: [String]]
  }

  init(defaults: UserDefaults = .standard) { self.defaults = defaults }

  private var state: State {
    guard let data = defaults.data(forKey: Self.defaultsKey) else {
      let value = State.empty
      save(value)
      return value
    }
    if let value = try? JSONDecoder().decode(State.self, from: data) {
      if value.version == 3 { return value }
      if value.version == 2 {
        let used = Set(value.assignments.values.flatMap { $0 })
        let retained = value.tags.filter { tag in
          used.contains(tag.id) || !Self.isUntouchedSeed(tag)
        }
        let migrated = State(version: 3, tags: retained, assignments: value.assignments)
        save(migrated)
        return migrated
      }
    }
    if let legacy = try? JSONDecoder().decode(LegacyState.self, from: data) {
      let used = Set(legacy.assignments.values.flatMap { $0 })
      let tags = MacPrayerTag.colors.compactMap { id, _, fallback -> StoredTag? in
        guard used.contains(id) || legacy.names[id] != nil else { return nil }
        return StoredTag(id: id, name: legacy.names[id] ?? fallback, colorID: id)
      }
      let value = State(version: 3, tags: tags, assignments: legacy.assignments)
      save(value)
      return value
    }
    return State.empty
  }

  private static func isUntouchedSeed(_ tag: StoredTag) -> Bool {
    guard tag.colorID == tag.id,
          let fallback = MacPrayerTag.colors.first(where: { $0.0 == tag.id })?.2 else { return false }
    // A seed keeps its original localized name even after the app's language changes.
    let key = "macLibrary.tag.\(tag.id)"
    let names = Bundle.main.localizations.compactMap { language -> String? in
      guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
            let bundle = Bundle(path: path) else { return nil }
      return bundle.localizedString(forKey: key, value: fallback, table: nil)
    }
    return ([fallback] + names).contains(tag.name)
  }

  var tags: [MacPrayerTag] { state.tags.map(\.tag) }

  func tagIDs(for itemID: String) -> Set<String> {
    let value = state
    return Set(value.assignments[itemID] ?? []).intersection(value.tags.map(\.id))
  }

  func set(_ tagID: String, on itemID: String, enabled: Bool) {
    var value = state
    guard value.tags.contains(where: { $0.id == tagID }) else { return }
    var ids = Set(value.assignments[itemID] ?? [])
    if enabled { ids.insert(tagID) } else { ids.remove(tagID) }
    value.assignments[itemID] = ids.isEmpty ? nil : ids.sorted()
    save(value)
  }

  /// Resolving typed names and replacing membership use one read and one persisted state.
  /// Blank tokens are ignored; an empty list removes every tag from this item.
  func setTags(named names: [String], on itemID: String) {
    var value = state
    let previousIDs = Set(value.assignments[itemID] ?? [])
    var ids: Set<String> = []
    for name in names {
      let trimmed = Self.trimmed(name)
      guard !trimmed.isEmpty else { continue }
      // The old color-only editor allowed duplicate display names. A token cannot
      // distinguish those IDs, so preserve the item's existing matches rather than
      // silently transferring its assignment to the first same-named tag.
      let existing = value.tags.filter { previousIDs.contains($0.id) && Self.namesMatch($0.name, trimmed) }
      if existing.isEmpty {
        ids.insert(Self.resolve(named: trimmed, colorID: nil, in: &value).id)
      } else {
        ids.formUnion(existing.map(\.id))
      }
    }
    value.assignments[itemID] = ids.isEmpty ? nil : ids.sorted()
    save(value)
  }

  @discardableResult
  func create(named name: String, colorID: String?) -> MacPrayerTag? {
    let trimmed = Self.trimmed(name)
    guard !trimmed.isEmpty else { return nil }
    var value = state
    let tag = Self.resolve(named: trimmed, colorID: colorID, in: &value)
    save(value)
    return tag.tag
  }

  @discardableResult
  func rename(_ tagID: String, to name: String) -> Bool {
    let trimmed = Self.trimmed(name)
    guard !trimmed.isEmpty else { return false }
    var value = state
    guard let index = value.tags.firstIndex(where: { $0.id == tagID }),
          !value.tags.contains(where: { $0.id != tagID && Self.namesMatch($0.name, trimmed) }) else {
      return false
    }
    value.tags[index].name = trimmed
    save(value)
    return true
  }

  func setColor(_ tagID: String, colorID: String?) {
    var value = state
    guard let index = value.tags.firstIndex(where: { $0.id == tagID }) else { return }
    value.tags[index].colorID = Self.validColorID(colorID)
    save(value)
  }

  func delete(_ tagID: String) {
    var value = state
    guard value.tags.contains(where: { $0.id == tagID }) else { return }
    value.tags.removeAll { $0.id == tagID }
    for itemID in Array(value.assignments.keys) {
      let ids = (value.assignments[itemID] ?? []).filter { $0 != tagID }
      value.assignments[itemID] = ids.isEmpty ? nil : ids
    }
    save(value)
  }

  func copy(from sourceID: String, to destinationID: String, removingSource: Bool = false) {
    var value = state
    value.assignments[destinationID] = value.assignments[sourceID]
    if removingSource { value.assignments[sourceID] = nil }
    save(value)
  }

  func migrate(from sourceID: String, to destinationID: String) {
    var value = state
    guard let source = value.assignments[sourceID], !source.isEmpty else { return }
    value.assignments[destinationID] = Set(source + (value.assignments[destinationID] ?? [])).sorted()
    value.assignments[sourceID] = nil
    save(value)
  }

  func removeAssignments(for itemID: String) {
    var value = state
    value.assignments[itemID] = nil
    save(value)
  }

  private static func resolve(named name: String, colorID: String?, in value: inout State) -> StoredTag {
    if let existing = value.tags.first(where: { namesMatch($0.name, name) }) { return existing }
    let tag = StoredTag(id: UUID().uuidString, name: name, colorID: validColorID(colorID))
    value.tags.append(tag)
    return tag
  }

  private static func trimmed(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
  }

  private static func namesMatch(_ first: String, _ second: String) -> Bool {
    first.compare(second, options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX")) == .orderedSame
  }

  private static func validColorID(_ id: String?) -> String? {
    guard let id, MacPrayerTag.colors.contains(where: { $0.0 == id }) else { return nil }
    return id
  }

  private func save(_ value: State) {
    guard let data = try? JSONEncoder().encode(value) else { return }
    defaults.set(data, forKey: Self.defaultsKey)
  }
}

/// A bundled devotion belongs to the Gallery until explicitly added on this Mac.
/// Saved Prayer records remain visible independently; downloads begin in the Gallery.
struct MacLibraryMembershipStore {
  static let defaultsKey = "macLibraryDevotions"
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) { self.defaults = defaults }

  var devotionIDs: Set<String> { Set(defaults.stringArray(forKey: Self.defaultsKey) ?? []) }

  func add(_ devotionID: String) {
    add([devotionID])
  }

  func add(_ additions: Set<String>) {
    let current = devotionIDs
    let updated = current.union(additions.filter { !$0.isEmpty })
    guard updated != current else { return }
    defaults.set(updated.sorted(), forKey: Self.defaultsKey)
  }

  func remove(_ devotionID: String) {
    defaults.set(devotionIDs.subtracting([devotionID]).sorted(), forKey: Self.defaultsKey)
  }
}

@MainActor @Observable
final class MacPrayerLibraryModel {
  var items: [MacPrayerLibraryItem] = []
  var galleryItems: [MacPrayerLibraryItem] = []
  var tags: [MacPrayerTag] = []
  var error: String?
  private let store: PresetStore
  private let tagStore: MacLibraryTagStore
  private let membershipStore: MacLibraryMembershipStore
  private let playbackStore: MacPrayerPlaybackSettings
  private let presentationStore: MacPrayerPresentationStore
  private let installedDevotionIDs: () -> [String]
  private let removalService: PrayerRemovalService
  private var materializing: [String: Task<Prayer, Error>] = [:]

  init(store: PresetStore? = nil, defaults: UserDefaults = .standard,
       installedDevotionIDs: (() -> [String])? = nil, removalService: PrayerRemovalService? = nil) {
    let store = store ?? AppServices.shared.presetStore
    self.store = store
    self.removalService = removalService ?? PrayerRemovalService(store: store)
    tagStore = MacLibraryTagStore(defaults: defaults)
    membershipStore = MacLibraryMembershipStore(defaults: defaults)
    playbackStore = MacPrayerPlaybackSettings(defaults: defaults)
    presentationStore = MacPrayerPresentationStore(defaults: defaults)
    self.installedDevotionIDs = installedDevotionIDs ?? { PrayerPackStore.installedBundleIds() }
    tags = tagStore.tags
  }

  func reload() async {
    do {
      let prayers = try await store.all()
      let listings = DevotionDirectory.all()
      let membership = membershipStore.devotionIDs
      tags = tagStore.tags
      for listing in listings {
        let matching = prayers.filter { Self.devotionID(for: $0) == listing.id }
        if let primary = matching.first(where: \.isDefault) ?? matching.first {
          tagStore.migrate(from: "devotion:\(listing.id)", to: primary.id.uuidString)
        }
      }
      galleryItems = listings.map { item(listing: $0, prayer: nil) }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
      let savedIDs = Set(prayers.map(Self.devotionID(for:)))
      items = prayers.map { prayer in
        if let listing = listings.first(where: { $0.id == Self.devotionID(for: prayer) }) {
          return item(listing: listing, prayer: prayer)
        }
        // Removing a source pack must never conceal an existing saved configuration.
        return MacPrayerLibraryItem(id: prayer.id.uuidString, title: prayer.name,
          subtitle: prayer.languageNativeName, systemImage: prayer.kind.systemImage,
          iconGlyph: nil, color: .brandPrimary, prayer: prayer,
          devotionID: Self.devotionID(for: prayer), tagIDs: tagStore.tagIDs(for: prayer.id.uuidString))
      } + galleryItems.filter { membership.contains($0.devotionID) && !savedIDs.contains($0.devotionID) }
      items.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    } catch { self.error = error.localizedDescription }
  }

  func isInLibrary(_ item: MacPrayerLibraryItem) -> Bool {
    items.contains { $0.devotionID == item.devotionID }
  }

  var downloadedDevotionIDs: Set<String> { Set(installedDevotionIDs()) }

  func canRemoveDownload(_ item: MacPrayerLibraryItem) -> Bool {
    downloadedDevotionIDs.contains(item.devotionID)
      && !items.contains { $0.devotionID == item.devotionID && $0.prayer != nil }
  }

  func removalRequest(for item: MacPrayerLibraryItem, downloadOnly: Bool = false) async throws -> MacPrayerRemovalRequest {
    let removesDownload: Bool
    if let prayer = item.prayer, !downloadOnly {
      removesDownload = try await removalService.willRemoveDownload(afterDeleting: prayer)
    } else {
      let hasCopies = try await store.all().contains { Self.devotionID(for: $0) == item.devotionID }
      removesDownload = downloadedDevotionIDs.contains(item.devotionID) && !hasCopies
    }
    return MacPrayerRemovalRequest(item: item, removesDownload: removesDownload, downloadOnly: downloadOnly)
  }

  func remove(_ request: MacPrayerRemovalRequest) async throws {
    let item = request.item
    // Finish this model's pending first-open operation before deciding which copy exists.
    if let pending = materializing[item.devotionID] { _ = try await pending.value }
    do {
      if request.downloadOnly {
        try await removalService.removeDownload(bundleID: item.devotionID)
      } else if let prayer = item.prayer {
        try await removalService.delete(prayer)
      } else {
        let hasCopies = try await store.all().contains { Self.devotionID(for: $0) == item.devotionID }
        if downloadedDevotionIDs.contains(item.devotionID), !hasCopies {
          try await removalService.removeDownload(bundleID: item.devotionID)
        }
      }
    } catch {
      // The copy may already be deleted when only download cleanup failed. Do not
      // restore its template on reload, or discard tags if persistence itself failed.
      if let prayer = item.prayer {
        do {
          if try await store.get(id: prayer.id) == nil { clearOrganization(afterRemoving: item) }
        } catch { /* Preserve organization until persistence can confirm deletion. */ }
      }
      await reload()
      NotificationCenter.default.post(name: .prayerLibraryDidChange, object: nil)
      throw error
    }
    clearOrganization(afterRemoving: item)
    await reload()
    NotificationCenter.default.post(name: .prayerLibraryDidChange, object: nil)
  }

  private func clearOrganization(afterRemoving item: MacPrayerLibraryItem) {
    // Other saved copies remain visible independently of template membership.
    membershipStore.remove(item.devotionID)
    tagStore.removeAssignments(for: "devotion:\(item.devotionID)")
    if let prayer = item.prayer {
      tagStore.removeAssignments(for: prayer.id.uuidString)
      playbackStore.remove(for: prayer.id)
    }
  }

  /// Adding from the Gallery is local organization; opening/editing still materializes later.
  func addToLibrary(_ item: MacPrayerLibraryItem) {
    addToLibrary([item])
  }

  /// A Finder selection is one membership change, one visible update and one reload
  /// notification. Existing saved copies and already-added templates remain untouched.
  func addToLibrary(_ selectedItems: [MacPrayerLibraryItem]) {
    let requestedIDs = Set(selectedItems.map(\.devotionID))
    let existingIDs = Set(items.map(\.devotionID))
    let additions = galleryItems.filter { requestedIDs.contains($0.devotionID) && !existingIDs.contains($0.devotionID) }
    guard !additions.isEmpty else { return }
    membershipStore.add(Set(additions.map(\.devotionID)))
    items.append(contentsOf: additions)
    items.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    NotificationCenter.default.post(name: .prayerLibraryDidChange, object: nil)
  }

  /// Gallery packs create no cloud preset merely by browsing or downloading.
  /// The first open/edit gives that library object a durable identity and remembered settings.
  func prayer(for item: MacPrayerLibraryItem) async throws -> Prayer {
    if let prayer = item.prayer {
      guard let current = try await store.get(id: prayer.id) else { throw CocoaError(.fileNoSuchFile) }
      return current
    }
    if let pending = materializing[item.devotionID] { return try await pending.value }
    let task = Task<Prayer, Error> { @MainActor in
      let existing = try await store.all()
      if let prayer = existing.first(where: { Self.devotionID(for: $0) == item.devotionID }) {
        tagStore.migrate(from: item.id, to: prayer.id.uuidString)
        return prayer
      }
      guard DevotionDirectory.all().contains(where: { $0.id == item.devotionID }) else {
        throw CocoaError(.fileNoSuchFile)
      }
      var prayer = Prayer(name: item.title)
      switch item.devotionID {
      case "rosary": prayer.kind = .rosary
      case "jesusPrayer": prayer.kind = .jesusPrayer
      default:
        prayer.kind = .custom
        prayer.customDevotionId = item.devotionID
      }
      try await store.save(prayer)
      tagStore.migrate(from: item.id, to: prayer.id.uuidString)
      return prayer
    }
    materializing[item.devotionID] = task
    defer { materializing[item.devotionID] = nil }
    let prayer = try await task.value
    await reload()
    return prayer
  }

  func duplicate(_ item: MacPrayerLibraryItem) async throws -> Prayer {
    let original = try await prayer(for: item)
    let names = Set(try await store.all().map(\.name))
    var copy = Self.duplicate(original, existingNames: names)
    // A copied reminder must not silently create a second notification schedule.
    copy.reminders = original.reminders.map { reminder in
      var value = reminder
      value.id = UUID()
      value.isEnabled = false
      return value
    }
    try await store.save(copy)
    tagStore.copy(from: original.id.uuidString, to: copy.id.uuidString)
    playbackStore.copy(from: original.id, to: copy.id)
    presentationStore.copy(from: original.id, to: copy.id)
    await reload()
    NotificationCenter.default.post(name: .prayerLibraryDidChange, object: nil)
    return copy
  }

  static func duplicate(_ original: Prayer, existingNames: Set<String>) -> Prayer {
    var copy = original
    copy.id = UUID()
    copy.isDefault = false
    copy.dayIndex = nil
    let base = String(format: String(localized: "macLibrary.copyName", defaultValue: "%@ Copy"), original.name)
    var name = base
    var suffix = 2
    while existingNames.contains(name) { name = "\(base) \(suffix)"; suffix += 1 }
    copy.name = name
    return copy
  }

  @discardableResult
  func importFiles(_ urls: [URL]) async -> Bool {
    var failures: [String] = []
    var importedAny = false
    for url in urls {
      do {
        _ = try PrayerPackStore.installPack(fromUserSelected: url)
        importedAny = true
      }
      catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
    }
    await reload()
    if !failures.isEmpty { error = failures.joined(separator: "\n\n") }
    return importedAny
  }

  func setTag(_ tag: MacPrayerTag, on item: MacPrayerLibraryItem, enabled: Bool) {
    tagStore.set(tag.id, on: item.id, enabled: enabled)
    refreshTags()
  }

  func setTags(named names: [String], on item: MacPrayerLibraryItem) {
    tagStore.setTags(named: names, on: item.id)
    refreshTags()
  }

  @discardableResult
  func createTag(named name: String, colorID: String?) -> MacPrayerTag? {
    guard let tag = tagStore.create(named: name, colorID: colorID) else {
      error = String(localized: "macLibrary.tagNameRequired", defaultValue: "Enter a name for the tag.")
      return nil
    }
    refreshTags()
    return tag
  }

  @discardableResult
  func renameTag(_ tag: MacPrayerTag, to name: String) -> Bool {
    guard tagStore.rename(tag.id, to: name) else {
      error = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? String(localized: "macLibrary.tagNameRequired", defaultValue: "Enter a name for the tag.")
        : String(localized: "macLibrary.tagNameExists", defaultValue: "A tag with that name already exists.")
      return false
    }
    refreshTags()
    return true
  }

  func setTagColor(_ tag: MacPrayerTag, colorID: String?) {
    tagStore.setColor(tag.id, colorID: colorID)
    refreshTags()
  }

  func deleteTag(_ tag: MacPrayerTag) {
    tagStore.delete(tag.id)
    refreshTags()
  }

  private func refreshTags() {
    tags = tagStore.tags
    let refreshed: (MacPrayerLibraryItem) -> MacPrayerLibraryItem = { value in
      MacPrayerLibraryItem(id: value.id, title: value.title, subtitle: value.subtitle,
        systemImage: value.systemImage, iconGlyph: value.iconGlyph, color: value.color,
        prayer: value.prayer, devotionID: value.devotionID, tagIDs: self.tagStore.tagIDs(for: value.id))
    }
    items = items.map(refreshed)
    galleryItems = galleryItems.map(refreshed)
    NotificationCenter.default.post(name: .prayerLibraryDidChange, object: nil)
  }

  private func item(listing: DevotionListing, prayer: Prayer?) -> MacPrayerLibraryItem {
    let id = prayer?.id.uuidString ?? "devotion:\(listing.id)"
    return MacPrayerLibraryItem(id: id, title: prayer?.name ?? listing.title,
      subtitle: prayer?.languageNativeName ?? "",
      systemImage: listing.systemImage, iconGlyph: listing.iconGlyph, color: listing.accentColor,
      prayer: prayer, devotionID: listing.id, tagIDs: tagStore.tagIDs(for: id))
  }

  static func devotionID(for prayer: Prayer) -> String {
    switch prayer.kind {
    case .rosary: "rosary"
    case .jesusPrayer: "jesusPrayer"
    case .custom: prayer.customDevotionId ?? ""
    }
  }
}
#endif

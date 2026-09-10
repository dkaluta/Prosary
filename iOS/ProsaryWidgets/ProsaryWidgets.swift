import AppIntents
import SwiftUI
import WidgetKit

@main
struct ProsaryWidgetBundle: WidgetBundle {
  var body: some Widget {
    ProsaryTodayWidget()
    ProsarySavedPrayerWidget()
  }
}

private enum WidgetText {
  static func string(_ key: String, language: String) -> String {
    let code = language == "tl" ? "fil" : language
    let bundle = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    return bundle.localizedString(forKey: key, value: nil, table: "WidgetStrings")
  }
}

private enum WidgetDates {
  /// Future entries let WidgetKit change civil dates even when its reload budget delays us.
  static func upcoming(from date: Date) -> [Date] {
    let calendar = Calendar(identifier: .gregorian)
    return [date] + (1...7).compactMap {
      calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: date))
    }
  }
}

struct TodayWidgetEntry: TimelineEntry {
  var date: Date
  var settings: WidgetTodaySettings
  var content: WidgetTodayContent
}

struct TodayWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> TodayWidgetEntry { entry(date: .now) }
  func getSnapshot(in context: Context, completion: @escaping (TodayWidgetEntry) -> Void) {
    completion(entry(date: .now))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<TodayWidgetEntry>) -> Void) {
    let settings = ProsaryWidgetSnapshot.load().today
    let reader = WidgetTodayReader(settings: settings)
    let dates = WidgetDates.upcoming(from: .now)
    completion(Timeline(entries: dates.map {
      TodayWidgetEntry(date: $0, settings: settings, content: reader.content(on: $0))
    }, policy: .after(dates[1])))
  }
  private func entry(date: Date) -> TodayWidgetEntry {
    let settings = ProsaryWidgetSnapshot.load().today
    return TodayWidgetEntry(date: date, settings: settings,
                            content: WidgetTodayReader(settings: settings).content(on: date))
  }
}

struct ProsaryTodayWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: ProsaryWidgetSnapshot.todayKind, provider: TodayWidgetProvider()) { entry in
      TodayWidgetView(entry: entry)
        .containerBackground(.background, for: .widget)
    }
    .configurationDisplayName(Text("widget.today.name", tableName: "WidgetStrings"))
    .description(Text("widget.today.description", tableName: "WidgetStrings"))
    .supportedFamilies(widgetFamilies)
  }
}

private var widgetFamilies: [WidgetFamily] {
  #if os(iOS)
  [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular]
  #else
  [.systemSmall, .systemMedium, .systemLarge]
  #endif
}

private struct TodayWidgetView: View {
  let entry: TodayWidgetEntry
  @Environment(\.widgetFamily) private var family
  private var language: String { entry.settings.normalizedLanguageCode }
  private func text(_ key: String) -> String { WidgetText.string(key, language: language) }
  private var isAccessory: Bool {
    #if os(iOS)
    family == .accessoryRectangular
    #else
    false
    #endif
  }

  var body: some View {
    Group {
      if isAccessory { accessory }
      else if family == .systemSmall { small }
      else { expanded }
    }
    .environment(\.layoutDirection, entry.settings.isRightToLeft ? .rightToLeft : .leftToRight)
    .environment(\.locale, Locale(identifier: language))
    .widgetURL(URL(string: "prosary://today"))
  }

  private var heading: some View {
    HStack(alignment: .firstTextBaseline) {
      Label(text("widget.today.name"), systemImage: "sun.max")
        .font(.caption.weight(.semibold)).widgetAccentable()
      Spacer(minLength: 2)
      Text(entry.date, format: .dateTime.day().month(.abbreviated))
        .font(.caption).foregroundStyle(.secondary)
    }
  }

  private var small: some View {
    VStack(alignment: .leading, spacing: 7) {
      heading
      if let feast = entry.content.feast {
        Text(feast).font(.subheadline.weight(.semibold)).lineLimit(3)
      }
      if !entry.content.readings.isEmpty {
        Text(entry.content.readings.joined(separator: " · "))
          .font(.caption).foregroundStyle(.secondary).lineLimit(2)
      } else if entry.content.feast == nil, let intention = entry.content.intention {
        Text(intention).font(.subheadline).lineLimit(3)
      } else if entry.content.feast == nil {
        Text(text("widget.today.empty")).font(.caption).foregroundStyle(.secondary).lineLimit(3)
      }
      Spacer(minLength: 0)
      Label(text("widget.today.open"), systemImage: "arrow.up.forward")
        .font(.caption.weight(.medium)).widgetAccentable()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var expanded: some View {
    VStack(alignment: .leading, spacing: family == .systemLarge ? 12 : 6) {
      heading
      Link(destination: URL(string: "prosary://today")!) {
        VStack(alignment: .leading, spacing: 5) {
          if let feast = entry.content.feast {
            Text(feast).font(.headline).lineLimit(family == .systemLarge ? 3 : 2)
          }
          if !entry.content.readings.isEmpty {
            Label((family == .systemLarge ? entry.content.fullReadings : entry.content.readings)
              .joined(separator: " · "), systemImage: "book.closed")
              .font(.caption).foregroundStyle(.secondary).lineLimit(family == .systemLarge ? 5 : 2)
          }
          if family == .systemLarge {
            if let intention = entry.content.intention {
              detail(title: text("widget.today.intention"), value: intention, symbol: "heart",
                     body: entry.content.intentionText)
            }
            if let torah = entry.content.torah {
              detail(title: text("widget.today.torah"), value: torah, symbol: "book")
            }
          }
          if entry.content.feast == nil && entry.content.readings.isEmpty
            && (family != .systemLarge || (entry.content.intention == nil && entry.content.torah == nil)) {
            Text((family == .systemLarge ? nil : entry.content.intention) ?? text("widget.today.empty"))
              .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }.buttonStyle(.plain)
      Spacer(minLength: 0)
      Link(destination: URL(string: "prosary://rosary")!) {
        Label(text("widget.today.rosary"), systemImage: "cross.circle.fill")
          .font(.subheadline.weight(.semibold))
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
      }.widgetAccentable()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func detail(title: String, value: String, symbol: String, body: String? = nil) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Label(title, systemImage: symbol).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
      Text(value).font(.subheadline).lineLimit(2)
      if let body {
        Text(body).font(.caption).foregroundStyle(.secondary).lineLimit(4)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var accessory: some View {
    VStack(alignment: .leading, spacing: 3) {
      Label(text("widget.today.name"), systemImage: "sun.max").font(.caption.weight(.semibold))
      Text(entry.content.feast ?? entry.content.readings.joined(separator: " · ").nilIfEmpty
           ?? text("widget.today.open"))
        .font(.caption).lineLimit(2)
    }
  }
}

struct SavedPrayerEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = .init(name:
    LocalizedStringResource("widget.prayer.entity", defaultValue: "Saved Prayer", table: "WidgetStrings"))
  static var defaultQuery = SavedPrayerQuery()
  var id: UUID
  var name: String
  var displayRepresentation: DisplayRepresentation { .init(title: "\(name)") }
}

struct SavedPrayerQuery: EntityQuery {
  func entities(for identifiers: [UUID]) async throws -> [SavedPrayerEntity] {
    let prayers = ProsaryWidgetSnapshot.load().prayers
    return identifiers.compactMap { id in
      prayers.first { $0.id == id }.map { SavedPrayerEntity(id: $0.id, name: $0.name) }
    }
  }
  func suggestedEntities() async throws -> [SavedPrayerEntity] {
    ProsaryWidgetSnapshot.load().prayers.map { SavedPrayerEntity(id: $0.id, name: $0.name) }
  }
}

struct SavedPrayerConfiguration: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = .init("widget.prayer.choose", defaultValue: "Choose a Prayer", table: "WidgetStrings")
  static var description = IntentDescription(LocalizedStringResource(
    "widget.prayer.description", defaultValue: "Open a saved prayer and see your progress.", table: "WidgetStrings"))
  @Parameter(title: LocalizedStringResource("widget.prayer.entity", defaultValue: "Saved Prayer", table: "WidgetStrings"))
  var prayer: SavedPrayerEntity?
}

struct SavedPrayerEntry: TimelineEntry {
  var date: Date
  var settings: WidgetTodaySettings
  var prayer: WidgetSavedPrayer?
  var hasSelection: Bool
}

struct SavedPrayerProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> SavedPrayerEntry {
    .init(date: .now, settings: .init(), prayer: nil, hasSelection: false)
  }
  func snapshot(for configuration: SavedPrayerConfiguration, in context: Context) async -> SavedPrayerEntry {
    entry(configuration, date: .now)
  }
  func timeline(for configuration: SavedPrayerConfiguration, in context: Context) async -> Timeline<SavedPrayerEntry> {
    let dates = WidgetDates.upcoming(from: .now)
    return Timeline(entries: dates.map { entry(configuration, date: $0) }, policy: .after(dates[1]))
  }
  private func entry(_ configuration: SavedPrayerConfiguration, date: Date) -> SavedPrayerEntry {
    let snapshot = ProsaryWidgetSnapshot.load()
    return .init(date: date, settings: snapshot.today,
                 prayer: snapshot.prayers.first { $0.id == configuration.prayer?.id },
                 hasSelection: configuration.prayer != nil)
  }
}

struct ProsarySavedPrayerWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: ProsaryWidgetSnapshot.prayerKind,
                           intent: SavedPrayerConfiguration.self, provider: SavedPrayerProvider()) { entry in
      SavedPrayerWidgetView(entry: entry)
        .containerBackground(.background, for: .widget)
    }
    .configurationDisplayName(Text("widget.prayer.name", tableName: "WidgetStrings"))
    .description(Text("widget.prayer.description", tableName: "WidgetStrings"))
    .supportedFamilies(widgetFamilies)
  }
}

private struct SavedPrayerWidgetView: View {
  let entry: SavedPrayerEntry
  @Environment(\.widgetFamily) private var family
  private var language: String { entry.settings.normalizedLanguageCode }
  private func text(_ key: String) -> String { WidgetText.string(key, language: language) }
  private var isAccessory: Bool {
    #if os(iOS)
    family == .accessoryRectangular
    #else
    false
    #endif
  }

  var body: some View {
    VStack(alignment: .leading, spacing: isAccessory ? 3 : 9) {
      Label(text("widget.prayer.name"), systemImage: "cross.circle")
        .font(.caption.weight(.semibold)).widgetAccentable()
      if let prayer = entry.prayer {
        Text(prayer.name).font(isAccessory ? .caption.weight(.semibold) : .headline)
          .lineLimit(isAccessory ? 1 : family == .systemLarge ? 5 : 3)
          .privacySensitive()
        if prayer.hasProgress(on: entry.date), let index = prayer.stepIndex {
          if let count = prayer.stepCount, count > 0 {
            let position = min(count, index + 1)
            Text(String(format: text("widget.prayer.progress"), locale: Locale(identifier: language), position, count))
              .font(.caption).foregroundStyle(.secondary)
            if !isAccessory {
              ProgressView(value: Double(position), total: Double(count)).widgetAccentable()
                .accessibilityLabel(text("widget.prayer.name"))
                .accessibilityValue(String(format: text("widget.prayer.progress"), position, count))
            }
          } else {
            Text(String(format: text("widget.prayer.repetitions"), locale: Locale(identifier: language), index + 1))
              .font(.caption).foregroundStyle(.secondary)
          }
        }
        if !isAccessory {
          Spacer(minLength: 0)
          Label(text(prayer.hasProgress(on: entry.date) ? "widget.prayer.resume" : "widget.prayer.begin"),
                systemImage: "play.fill")
            .font(.subheadline.weight(.semibold)).widgetAccentable()
        }
      } else {
        Text(text(entry.hasSelection ? "widget.prayer.missing" : "widget.prayer.empty"))
          .font(.caption).foregroundStyle(.secondary).lineLimit(isAccessory ? 2 : 4)
        if !isAccessory {
          Spacer(minLength: 0)
          Label(text("widget.prayer.library"), systemImage: "books.vertical")
            .font(.caption.weight(.semibold)).widgetAccentable()
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .environment(\.layoutDirection, entry.settings.isRightToLeft ? .rightToLeft : .leftToRight)
    .environment(\.locale, Locale(identifier: language))
    .widgetURL(entry.prayer?.url ?? URL(string: "prosary://library"))
  }
}

private extension String {
  var nilIfEmpty: String? { isEmpty ? nil : self }
}

#if !os(macOS)
import SwiftUI
import PhotosUI
import Combine

struct HomeDashboardView: View {
  @Binding var dateSelection: MacTodayDateSelection
  let openReadings: (String) -> Void
  @Environment(\.appServices) private var services
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage(HomeWidgetOrder.key) private var storedOrder = HomeWidgetOrder.encode(HomeWidgetOrder.defaults)
  @AppStorage(HomePhotoStore.key) private var photoPath = ""
  @AppStorage(TodayInfoStore.calendarDefaultsKey) private var calendarID = ""
  @AppStorage(TodayInfoStore.paschaStyleDefaultsKey) private var paschaStyle = "julian"
  @AppStorage(ReadingDisplayOrder.defaultsKey) private var reverseReadingsOrder = false
  @AppStorage(TodayReminderScheduler.readingsEnabledKey) private var readingsReminderEnabled = false
  @AppStorage(TodayReminderScheduler.readingsTimeKey) private var readingsReminderMinutes = 540
  @AppStorage(TodayReminderScheduler.saintsEnabledKey) private var saintReminderEnabled = false
  @AppStorage(TodayReminderScheduler.saintsTimeKey) private var saintReminderMinutes = 540
  @State private var showsCustomizer = false
  @State private var showsSettings = false
  @State private var showsReminders = false
  @State private var selectedPhoto: PhotosPickerItem?
  @State private var photoImage: CGImage?
  @State private var showsPhotoError = false
  @State private var photoIsLoading = false
  @State private var prayers: [Prayer] = []

  private var language: String { UILanguage.current }
  private var widgets: [HomeWidget] { HomeWidgetOrder.decode(storedOrder) }
  private var selectedDate: Date { dateSelection.localDate() }
  private var feast: FeastDay? { TodayInfoStore.feast(on: selectedDate) }
  private var readings: [ReadingDisplayOrder.Row<ReadingCitation>] {
    ReadingDisplayOrder.indexed(TodayInfoStore.readings(on: selectedDate), reverse: reverseReadingsOrder)
  }
  private var intention: PopeIntention? { TodayInfoStore.intention(for: selectedDate) }
  private var dateBinding: Binding<Date> {
    Binding(get: { selectedDate }, set: { dateSelection.select($0) })
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        DatePicker(UILanguage.text("home.today.chooseDate", language: language, fallback: "Choose a date"),
                   selection: dateBinding, in: MacTodayDateSelection.pickerRange(), displayedComponents: .date)
          .accessibilityIdentifier("homeWidgets.date")
        if !dateSelection.isToday() {
          Button(UILanguage.text("home.today.today", language: language, fallback: "Today")) {
            dateSelection.select(Date())
          }
        }
        ForEach(widgets) { widget in card(widget) }
        if widgets.isEmpty { Text(label("empty")).foregroundStyle(.secondary) }
        Button { showsCustomizer = true } label: {
          Label(label("add"), systemImage: "plus")
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("homeWidgets.add")
      }
      .frame(maxWidth: 720)
      .frame(maxWidth: .infinity)
      .padding(20)
    }
    .navigationTitle(label("title"))
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button { showsCustomizer = true } label: { Label(label("customize"), systemImage: "slider.horizontal.3") }
          .labelStyle(.iconOnly)
          .accessibilityIdentifier("homeWidgets.customize")
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button { showsSettings = true } label: {
          Label(UILanguage.text("settings.title", language: language, fallback: "Settings"), systemImage: "gearshape")
        }.labelStyle(.iconOnly)
      }
    }
    .sheet(isPresented: $showsCustomizer) {
      HomeWidgetCustomizer(storedOrder: $storedOrder, removeWidget: removeWidget)
    }
    .sheet(isPresented: $showsSettings) {
      NavigationStack {
        SettingsView()
          .navigationTitle(UILanguage.text("settings.title", language: language, fallback: "Settings"))
          .toolbar { ToolbarItem(placement: .confirmationAction) { Button(doneLabel) { showsSettings = false } } }
      }
    }
    .sheet(isPresented: $showsReminders, onDismiss: { Task { await reloadPrayers() } }) {
      HomeReminderManager()
    }
    .alert(label("photoError"), isPresented: $showsPhotoError) { Button("common.ok", role: .cancel) {} }
    .task { refreshDate(); await reloadPrayers(); photoImage = HomePhotoStore.image(photoPath) }
    .task(id: selectedPhoto) { await loadPhoto() }
    .onChange(of: photoPath) { _, path in photoImage = HomePhotoStore.image(path) }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { refreshDate(); Task { await reloadPrayers() } }
    }
    .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in refreshDate() }
    .onReceive(NotificationCenter.default.publisher(for: .prayerConfigurationDidChange)) { _ in Task { await reloadPrayers() } }
    .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in Task { await reloadPrayers() } }
    .environment(\.layoutDirection, UILanguage.isRightToLeft(language) ? .rightToLeft : .leftToRight)
  }

  private func card(_ widget: HomeWidget) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HomeWidgetLabel(widget: widget).font(.headline).accessibilityAddTraits(.isHeader)
      cardContent(widget)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .prosaryContentCardBackground()
    .contextMenu {
      Button(label("moveUp"), systemImage: "arrow.up") { move(widget, by: -1) }
        .disabled(widgets.first == widget)
      Button(label("moveDown"), systemImage: "arrow.down") { move(widget, by: 1) }
        .disabled(widgets.last == widget)
      Button(label("remove"), systemImage: "minus.circle", role: .destructive) { removeWidget(widget) }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("homeWidgets.\(widget.rawValue)")
  }

  @ViewBuilder private func cardContent(_ widget: HomeWidget) -> some View {
    switch widget {
    case .readings:
      if readings.isEmpty { Text(label("noReadings")).foregroundStyle(.secondary) }
      ForEach(readings) { row in
        let reading = row.value
        Text(verbatim: reading.localizedFull(language))
          .frame(maxWidth: .infinity, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)
          .textSelection(.enabled)
          .accessibilityIdentifier("homeWidgets.reading.\(reading.type)")
      }
      Button(HomeWidget.readings.title) { openReadings("daily") }.buttonStyle(.bordered)
    case .popeIntention:
      if let intention {
        Text(verbatim: intention.localizedTitle(language)).font(.subheadline.weight(.semibold))
        Text(verbatim: intention.localizedText(language)).textSelection(.enabled)
      } else { Text(label("noIntention")).foregroundStyle(.secondary) }
    case .calendar:
      DatePicker("", selection: dateBinding, in: MacTodayDateSelection.pickerRange(), displayedComponents: .date)
        .datePickerStyle(.graphical).labelsHidden()
        .environment(\.calendar, Calendar(identifier: .gregorian))
      if let feast { Text(verbatim: feast.localizedTitle(language)).font(.subheadline) }
      Button(HomeWidget.calendar.title) { openReadings("calendar") }.buttonStyle(.bordered)
    case .photo:
      if let photoImage {
        Image(decorative: photoImage, scale: 1)
          .resizable().scaledToFit().frame(maxHeight: 360)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .accessibilityLabel(label("photoDescription"))
      }
      if photoIsLoading { ProgressView() }
      PhotosPicker(selection: $selectedPhoto, matching: .images) {
        Label(label("choosePhoto"), systemImage: "photo.badge.plus")
      }.buttonStyle(.bordered).disabled(photoIsLoading)
      if !photoPath.isEmpty {
        Button(label("removePhoto"), role: .destructive) { removePhoto() }
      }
    case .reminders:
      if readingsReminderEnabled { reminderLine(HomeWidget.readings.title, minutes: readingsReminderMinutes) }
      if saintReminderEnabled { reminderLine(HomeWidget.feast.title, minutes: saintReminderMinutes) }
      ForEach(prayers) { prayer in
        ForEach(prayer.reminders.filter(\.isEnabled)) { reminder in
          Text(verbatim: "\(prayer.name) · \(reminder.displayTime)")
        }
      }
      if !readingsReminderEnabled && !saintReminderEnabled && prayers.allSatisfy({ !$0.reminders.contains(where: \.isEnabled) }) {
        Text(label("noReminders")).foregroundStyle(.secondary)
      }
      Button(label("manageReminders")) { showsReminders = true }.buttonStyle(.bordered)
    case .scripture:
      Button { openReadings("bible") } label: {
        Label(HomeWidget.scripture.title, systemImage: "chevron.forward")
          .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      }.buttonStyle(.bordered)
    case .reflection:
      let reflections = feast?.reflections(language: language) ?? []
      if reflections.isEmpty { Text(label("reflectionPending")).foregroundStyle(.secondary) }
      ForEach(Array(reflections.enumerated()), id: \.offset) { index, reflection in
        VStack(alignment: .leading, spacing: 8) {
          Text(verbatim: reflection.title).font(.subheadline.weight(.semibold))
          Text(verbatim: reflection.text).textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("homeWidgets.reflection.\(index)")
          if let credit = reflection.credit {
            Text(verbatim: credit).font(.caption).foregroundStyle(.secondary)
          }
          if let source = reflection.sourceURL {
            Link(UILanguage.text("readings.source", language: language, fallback: "Text source"), destination: source)
              .font(.caption)
          }
        }
      }
    case .feast:
      if let feast {
        Text(verbatim: feast.localizedTitle(language)).font(.subheadline.weight(.semibold))
        Text(verbatim: feast.localizedRank(language)).font(.caption).foregroundStyle(.secondary)
        if feast.saintDescriptions(calendarID: TodayInfoStore.selectedCalendarId, language: language).isEmpty {
          Text(label("noFeastDescription")).foregroundStyle(.secondary)
        } else {
          SaintDescriptionsView(feast: feast, calendarID: TodayInfoStore.selectedCalendarId, language: language)
            .id("\(dateSelection.day)|\(calendarID)|\(paschaStyle)|\(language)")
        }
        Button(label("feastDetails")) { openReadings("daily") }.buttonStyle(.bordered)
      } else { Text(label("noFeast")).foregroundStyle(.secondary) }
    }
  }

  private func reminderLine(_ title: String, minutes: Int) -> some View {
    Text(verbatim: "\(title) · \(PrayerReminder(hour: minutes / 60, minute: minutes % 60).displayTime)")
  }
  private func label(_ key: String) -> String { UILanguage.text("homeWidgets.\(key)", language: language, fallback: key) }
  private var doneLabel: String { UILanguage.text("favoriteEditor.done", language: language, fallback: "Done") }
  private func refreshDate() { dateSelection.refresh() }
  private func reloadPrayers() async { prayers = (try? await services.presetStore.all()) ?? [] }

  private func move(_ widget: HomeWidget, by offset: Int) {
    var order = widgets
    guard let index = order.firstIndex(of: widget), order.indices.contains(index + offset) else { return }
    order.swapAt(index, index + offset)
    storedOrder = HomeWidgetOrder.encode(order)
  }

  private func removeWidget(_ widget: HomeWidget) {
    if widget == .photo, !removePhoto() { return }
    storedOrder = HomeWidgetOrder.encode(widgets.filter { $0 != widget })
  }

  @discardableResult private func removePhoto() -> Bool {
    do {
      try HomePhotoStore.remove(photoPath)
      photoPath = ""
      selectedPhoto = nil
      return true
    } catch { showsPhotoError = true; return false }
  }

  private func loadPhoto() async {
    guard let item = selectedPhoto else { return }
    photoIsLoading = true
    defer { photoIsLoading = false }
    do {
      guard let data = try await item.loadTransferable(type: Data.self) else { throw HomePhotoStore.PhotoError.invalidImage }
      try Task.checkCancellation()
      let newPath = try HomePhotoStore.install(data)
      do { try HomePhotoStore.remove(photoPath) }
      catch { try? HomePhotoStore.remove(newPath); throw error }
      photoPath = newPath
    } catch is CancellationError { }
    catch { showsPhotoError = true }
  }
}

private struct HomeWidgetLabel: View {
  let widget: HomeWidget
  var body: some View {
    Label { Text(widget.title) } icon: {
      if widget == .popeIntention { PapalKeysSymbol() }
      else { Image(systemName: widget.symbol) }
    }
  }
}

private struct HomeWidgetCustomizer: View {
  @Binding var storedOrder: String
  let removeWidget: (HomeWidget) -> Void
  @Environment(\.dismiss) private var dismiss
  private var widgets: [HomeWidget] { HomeWidgetOrder.decode(storedOrder) }
  private func label(_ key: String) -> String { UILanguage.text("homeWidgets.\(key)", language: UILanguage.current, fallback: key) }

  var body: some View {
    NavigationStack {
      List {
        Section(label("selected")) {
          ForEach(widgets) { widget in
            HStack {
              HomeWidgetLabel(widget: widget)
              Spacer()
              Menu {
                Button(label("moveUp"), systemImage: "arrow.up") { move(widget, by: -1) }.disabled(widgets.first == widget)
                Button(label("moveDown"), systemImage: "arrow.down") { move(widget, by: 1) }.disabled(widgets.last == widget)
                Button(label("remove"), systemImage: "minus.circle", role: .destructive) { removeWidget(widget) }
              } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }
                .accessibilityLabel(widget.title)
            }
          }
          .onMove { offsets, destination in
            var order = widgets
            order.move(fromOffsets: offsets, toOffset: destination)
            storedOrder = HomeWidgetOrder.encode(order)
          }
          .onDelete { offsets in
            let removed = offsets.map { widgets[$0] }
            removed.forEach(removeWidget)
          }
        }
        Section(label("available")) {
          ForEach(HomeWidget.allCases.filter { !widgets.contains($0) }) { widget in
            Button {
              storedOrder = HomeWidgetOrder.encode(widgets + [widget])
            } label: { Label(widget.title, systemImage: "plus.circle") }
          }
        }
      }
      .navigationTitle(label("customize"))
      .toolbar {
        ToolbarItem(placement: .topBarLeading) { EditButton() }
        ToolbarItem(placement: .confirmationAction) {
          Button(UILanguage.text("favoriteEditor.done", language: UILanguage.current, fallback: "Done")) { dismiss() }
        }
      }
    }
  }

  private func move(_ widget: HomeWidget, by offset: Int) {
    var order = widgets
    guard let index = order.firstIndex(of: widget), order.indices.contains(index + offset) else { return }
    order.swapAt(index, index + offset)
    storedOrder = HomeWidgetOrder.encode(order)
  }
}

private struct HomeReminderManager: View {
  @Environment(\.appServices) private var services
  @Environment(\.dismiss) private var dismiss
  @State private var prayers: [Prayer] = []
  @State private var editingPrayer: Prayer?

  var body: some View {
    NavigationStack {
      Form {
        TodayReminderSettings()
        Section(UILanguage.text("tabs.pray", language: UILanguage.current, fallback: "Pray")) {
          ForEach(prayers) { prayer in
            Button { editingPrayer = prayer } label: {
              VStack(alignment: .leading, spacing: 4) {
                Text(prayer.name).foregroundStyle(.primary)
                ForEach(prayer.reminders.filter(\.isEnabled)) { reminder in
                  Text(reminder.displayTime).font(.caption).foregroundStyle(.secondary)
                }
              }
            }
          }
          if prayers.isEmpty {
            Text(UILanguage.text("homeWidgets.noReminders", language: UILanguage.current, fallback: "No reminders yet."))
          }
        }
      }
      .navigationTitle(UILanguage.text("homeWidgets.manageReminders", language: UILanguage.current, fallback: "Manage Reminders"))
      .toolbar { ToolbarItem(placement: .confirmationAction) {
        Button(UILanguage.text("favoriteEditor.done", language: UILanguage.current, fallback: "Done")) { dismiss() }
      } }
      .sheet(item: $editingPrayer, onDismiss: { Task { await reload() } }) { prayer in
        NavigationStack { RemindersOnlyEditorView(prayer: prayer) }
      }
      .task { await reload() }
      .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in Task { await reload() } }
    }
  }

  private func reload() async { prayers = (try? await services.presetStore.all()) ?? [] }
}
#endif

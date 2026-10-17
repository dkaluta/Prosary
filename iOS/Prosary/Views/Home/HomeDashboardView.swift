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
  @AppStorage(HomeWidgetOrder.layoutVersionKey) private var layoutVersion = ""
  @AppStorage(HomePhotoStore.key) private var photoPath = ""
  @AppStorage(HomeWidgetDisplay.collapsedKey) private var storedCollapsed = ""
  @AppStorage(HomeWidgetDisplay.graphicsKey) private var storedGraphics = "{}"
  @AppStorage(HomeWidgetDisplay.colorsKey) private var storedColors = "{}"
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
  @State private var photoImport = HomeGraphicImportState()
  @State private var showsDatePicker = false
  @State private var prayers: [Prayer] = []
  @State private var showsGraphicPicker = false
  @State private var graphicTarget: HomeWidget = .photo
  @State private var graphicImages: [HomeWidget: CGImage] = [:]

  private var language: String { UILanguage.current }
  private var photoIsLoading: Bool { photoImport.active != nil }
  private var widgets: [HomeWidget] { HomeWidgetOrder.decode(storedOrder) }
  private var selectedDate: Date { dateSelection.localDate() }
  private var feast: FeastDay? { TodayInfoStore.feast(on: selectedDate) }
  private var sourceReadings: [ReadingCitation] { TodayInfoStore.readings(on: selectedDate) }
  private var readings: [ReadingDisplayOrder.Row<ReadingCitation>] {
    ReadingDisplayOrder.indexed(sourceReadings, reverse: reverseReadingsOrder)
  }
  private var collapsedReadingsSummary: String {
    if let gospel = sourceReadings.first(where: { $0.type == "gospel" }) {
      return gospel.localizedShort(language)
    }
    return readings.isEmpty ? label("noReadings")
      : readings.map { $0.value.localizedShort(language) }.joined(separator: " · ")
  }
  private var intention: PopeIntention? { TodayInfoStore.intention(for: selectedDate) }
  private var torah: TorahPortion? { TodayInfoStore.torahPortion(on: selectedDate) }
  private var dateBinding: Binding<Date> {
    Binding(get: { selectedDate }, set: { dateSelection.select($0) })
  }

  var body: some View {
    dashboard
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
      HomeWidgetCustomizer(storedOrder: Binding(get: { storedOrder }, set: { storedOrder = $0; publishLayout() }), removeWidget: removeWidget)
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
    .photosPicker(isPresented: $showsGraphicPicker, selection: $selectedPhoto, matching: .images)
    .task {
      if !applyCloudLayout(), layoutVersion != "1" {
        storedOrder = HomeWidgetOrder.encode(HomeWidgetOrder.addingDailyCards(to: widgets)); layoutVersion = "1"
      }
      refreshDate(); await reloadPrayers(); photoImage = HomePhotoStore.image(photoPath); reloadGraphics()
    }
    .task(id: selectedPhoto) { await loadPhoto() }
    .onChange(of: CloudPreferencesGeneration.shared.value) { _, _ in applyCloudLayout() }
    .onChange(of: photoPath) { _, path in photoImage = HomePhotoStore.image(path) }
    .onChange(of: storedGraphics) { _, _ in reloadGraphics() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { refreshDate(); Task { await reloadPrayers() } }
    }
    .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in refreshDate() }
    .onReceive(NotificationCenter.default.publisher(for: .prayerConfigurationDidChange)) { _ in Task { await reloadPrayers() } }
    .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in Task { await reloadPrayers() } }
    .environment(\.layoutDirection, UILanguage.isRightToLeft(language) ? .rightToLeft : .leftToRight)
  }

  private var dashboard: some View {
    GeometryReader { geometry in
      #if os(iOS)
      if #available(iOS 27.1, *) { reservedRegionDashboard(geometry: geometry) }
      else { dashboardPane(widgets, showsDate: true, showsAdd: true) }
      #else
      dashboardPane(widgets, showsDate: true, showsAdd: true)
      #endif
    }
  }

  #if os(iOS)
  @available(iOS 27.1, *)
  @ViewBuilder private func reservedRegionDashboard(geometry: GeometryProxy) -> some View {
    let bounds = CGRect(origin: .zero, size: geometry.size)
    let hasDivision = geometry.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed)
      .contains { $0.isActive && PrayerReservedRegionLayout.intersects($0.frame, bounds: bounds) }
    if hasDivision {
      let split = (widgets.count + 1) / 2
      ArrangementView {
        ReservedRegionAvoidingContent { _ in
          dashboardPane(Array(widgets.prefix(split)), showsDate: true, showsAdd: false)
        }
      } secondary: {
        ReservedRegionAvoidingContent { _ in
          dashboardPane(Array(widgets.dropFirst(split)), showsDate: false, showsAdd: true)
        }
      }
      .arrangementViewStyle(.split)
      .accessibilityIdentifier("homeWidgets.foldArrangement")
    } else {
      ReservedRegionAvoidingContent { _ in dashboardPane(widgets, showsDate: true, showsAdd: true) }
    }
  }
  #endif

  private func dashboardPane(_ cards: [HomeWidget], showsDate: Bool, showsAdd: Bool) -> some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if showsDate { dashboardDateControls }
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 16, alignment: .top),
            count: HomeDashboardLayout.columnCount(availableWidth: geometry.size.width)), alignment: .leading, spacing: 16) {
            ForEach(cards) { widget in card(widget) }
          }
          if widgets.isEmpty, showsDate { Text(label("empty")).foregroundStyle(.secondary) }
          if showsAdd {
            Button { showsCustomizer = true } label: {
              Label(label("add"), systemImage: "plus")
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("homeWidgets.add")
          }
        }
        .frame(maxWidth: HomeDashboardLayout.maximumContentWidth)
        .frame(maxWidth: .infinity)
        .padding(20)
      }
    }
  }

  private var dashboardDateControls: some View {
    VStack(alignment: .leading, spacing: 16) {
      Button { showsDatePicker = true } label: {
        Label(CalendarEventPresentation.dateLabel(selectedDate), systemImage: "calendar")
      }
      .buttonStyle(.bordered)
      .accessibilityIdentifier("homeWidgets.date")
      .popover(isPresented: $showsDatePicker) {
        ReadingDatePickerPopover(selection: dateBinding, range: MacTodayDateSelection.pickerRange(),
          pickerIdentifier: "homeWidgets.datePicker", todayIdentifier: "homeWidgets.dateToday", doneIdentifier: "homeWidgets.dateDone") { showsDatePicker = false }
          .presentationCompactAdaptation(.sheet)
      }
      if !dateSelection.isToday() {
        Button(UILanguage.text("home.today.today", language: language, fallback: "Today")) {
          dateSelection.select(Date())
        }
      }
    }
  }

  private func card(_ widget: HomeWidget) -> some View {
    let isCollapsed = HomeWidgetDisplay.collapsed(storedCollapsed).contains(widget)
    return VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Button { toggleSize(widget) } label: {
          HStack {
            HomeWidgetLabel(widget: widget).font(.headline).accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up").font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
          }.frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(widget.title), \(label(isCollapsed ? "expand" : "collapse"))")
        .accessibilityIdentifier("homeWidgets.size.\(widget.rawValue)")
        Menu { cardColorPicker(widget) } label: {
          Image(systemName: "paintpalette").frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("\(widget.title), \(label("color"))")
        .accessibilityValue(cardColor(widget).title)
        .accessibilityIdentifier("homeWidgets.color.\(widget.rawValue)")
      }
      if isCollapsed { compactContent(widget) }
      else {
        if let image = graphicImages[widget], widget != .photo, widget != .feast {
          Image(decorative: image, scale: 1).resizable().scaledToFit().frame(maxHeight: 280)
            .clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
        }
        cardContent(widget)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .background(cardColor(widget).tint, in: RoundedRectangle(cornerRadius: 14))
    .prosaryContentCardBackground()
    .contextMenu {
      Button(label(isCollapsed ? "expand" : "collapse"), systemImage: isCollapsed ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left") { toggleSize(widget) }
      Menu(label("color"), systemImage: "paintpalette") { cardColorPicker(widget) }
      if widget != .feast {
        Button(label(graphicPath(widget).isEmpty ? "addGraphic" : "changeGraphic"), systemImage: "photo.badge.plus") {
          chooseGraphic(widget)
        }.disabled(photoIsLoading)
        if !graphicPath(widget).isEmpty {
          Button(label("removeGraphic"), systemImage: "photo", role: .destructive) { removeGraphic(widget) }
            .disabled(photoIsLoading)
        }
      }
      Button(label("moveUp"), systemImage: "arrow.up") { move(widget, by: -1) }
        .disabled(widgets.first == widget)
      Button(label("moveDown"), systemImage: "arrow.down") { move(widget, by: 1) }
        .disabled(widgets.last == widget)
      Button(label("remove"), systemImage: "minus.circle", role: .destructive) { removeWidget(widget) }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("homeWidgets.\(widget.rawValue)")
  }

  @ViewBuilder private func compactContent(_ widget: HomeWidget) -> some View {
    switch widget {
    case .readings:
      Text(collapsedReadingsSummary).font(.subheadline)
      Button(widget.title) { openReadings("daily") }.buttonStyle(.bordered)
    case .torah:
      Text(torah?.localizedTitle(language) ?? label("noTorah")).font(.subheadline)
    case .calendar:
      Text(feast?.localizedTitle(language) ?? label("noFeast")).font(.subheadline)
      Button(widget.title) { openReadings("calendar") }.buttonStyle(.bordered)
        .accessibilityIdentifier("homeWidgets.open.calendar")
    case .scripture:
      if let reading = TodayInfoStore.scriptureOfTheDay(on: selectedDate) {
        Text(reading.localizedFull(language)).font(.subheadline)
      }
      Button(widget.title) { openReadings("bible") }.buttonStyle(.bordered)
        .accessibilityIdentifier("homeWidgets.open.scripture")
    case .popeIntention:
      Text(intention?.localizedTitle(language) ?? label("noIntention")).font(.subheadline)
    case .photo:
      Button { chooseGraphic(.photo) } label: { Label(label("choosePhoto"), systemImage: "photo.badge.plus") }
        .buttonStyle(.bordered).disabled(photoIsLoading)
    case .reminders:
      Text(prayers.first(where: { $0.reminders.contains(where: \.isEnabled) })?.name
        ?? (readingsReminderEnabled ? HomeWidget.readings.title : saintReminderEnabled ? HomeWidget.feast.title : label("noReminders")))
        .font(.subheadline)
      Button(label("manageReminders")) { showsReminders = true }.buttonStyle(.bordered)
    case .reflection:
      Text(feast?.reflections(language: language).first?.title ?? label("reflectionPending")).font(.subheadline)
    case .feast:
      Text(feast?.localizedTitle(language) ?? label("noFeast")).font(.subheadline)
      if feast != nil { Button(label("feastDetails")) { openReadings("daily") }.buttonStyle(.bordered) }
    }
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
    case .torah:
      if let torah {
        Text(verbatim: torah.localizedTitle(language)).font(.subheadline.weight(.semibold))
        ForEach(Array(torah.allReadings.enumerated()), id: \.offset) { _, reading in
          ScripturePassageView(reading: reading, isTorah: true, interfaceLanguage: language)
            .id("\(dateSelection.day)|\(reading.full)")
        }
      } else { Text(label("noTorah")).foregroundStyle(.secondary) }
    case .popeIntention:
      if let intention {
        Text(verbatim: intention.localizedTitle(language)).font(.subheadline.weight(.semibold))
        Text(verbatim: intention.localizedText(language)).textSelection(.enabled)
      } else { Text(label("noIntention")).foregroundStyle(.secondary) }
    case .calendar:
      CalendarMonthGrid(dateSelection: $dateSelection)
      CalendarDayEvents(date: selectedDate, openReadings: { openReadings("daily") })
      Button(HomeWidget.calendar.title) { openReadings("calendar") }.buttonStyle(.bordered)
        .accessibilityIdentifier("homeWidgets.open.calendar")
    case .photo:
      if let photoImage {
        Image(decorative: photoImage, scale: 1)
          .resizable().scaledToFit().frame(maxHeight: 360)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .accessibilityLabel(label("photoDescription"))
      }
      if photoIsLoading { ProgressView() }
      Button { chooseGraphic(.photo) } label: {
        Label(label("choosePhoto"), systemImage: "photo.badge.plus")
      }.buttonStyle(.bordered).disabled(photoIsLoading)
      if !photoPath.isEmpty {
        Button(label("removePhoto"), role: .destructive) { removeGraphic(.photo) }.disabled(photoIsLoading)
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
      if let reading = TodayInfoStore.scriptureOfTheDay(on: selectedDate) {
        Text(bibleLabel("scriptureOfTheDay", "Scripture of the Day")).font(.subheadline.weight(.semibold))
        ScripturePassageView(reading: reading, interfaceLanguage: language)
          .id("\(dateSelection.day)|\(calendarID)|\(paschaStyle)")
      }
      Button { openReadings("bible") } label: {
        Label(HomeWidget.scripture.title, systemImage: "chevron.forward")
          .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      }.buttonStyle(.bordered)
        .accessibilityIdentifier("homeWidgets.open.scripture")
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
    publishLayout()
  }

  private func removeWidget(_ widget: HomeWidget) {
    if !removeGraphic(widget) { return }
    if graphicTarget == widget { selectedPhoto = nil }
    storedOrder = HomeWidgetOrder.encode(widgets.filter { $0 != widget })
    publishLayout()
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
    let target = graphicTarget
    let request = photoImport.begin(target)
    defer { photoImport.finish(request) }
    do {
      guard let data = try await item.loadTransferable(type: Data.self) else { throw HomePhotoStore.PhotoError.invalidImage }
      try Task.checkCancellation()
      guard photoImport.canCommit(request, widgets: widgets) else { return }
      let newPath = try HomePhotoStore.install(data)
      let oldPath = graphicPath(target)
      do { try HomePhotoStore.remove(oldPath) }
      catch { try? HomePhotoStore.remove(newPath); throw error }
      if target == .photo { photoPath = newPath }
      else {
        var graphics = HomeWidgetDisplay.graphics(storedGraphics)
        graphics[target] = newPath
        storedGraphics = HomeWidgetDisplay.encodeGraphics(graphics)
      }
    } catch is CancellationError { }
    catch { showsPhotoError = true }
  }

  private func toggleSize(_ widget: HomeWidget) {
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
      var collapsed = HomeWidgetDisplay.collapsed(storedCollapsed)
      if collapsed.contains(widget) { collapsed.remove(widget) } else { collapsed.insert(widget) }
      storedCollapsed = HomeWidgetDisplay.encodeCollapsed(collapsed)
      publishLayout()
    }
  }

  private func cardColor(_ widget: HomeWidget) -> TodayCardColor {
    HomeWidgetDisplay.colors(storedColors)[widget] ?? .default
  }

  private func setCardColor(_ color: TodayCardColor, for widget: HomeWidget) {
    var colors = HomeWidgetDisplay.colors(storedColors)
    colors[widget] = color
    storedColors = HomeWidgetDisplay.encodeColors(colors)
    publishLayout()
  }

  private func cardColorPicker(_ widget: HomeWidget) -> some View {
    Picker(label("color"), selection: Binding(get: { cardColor(widget) }, set: { setCardColor($0, for: widget) })) {
      ForEach(TodayCardColor.allCases) { color in Text(color.title).tag(color) }
    }
    .pickerStyle(.inline)
  }

  @discardableResult private func applyCloudLayout() -> Bool {
    guard let layout = HomeLayoutCloud.read() else { return false }
    storedOrder = layout.order
    storedCollapsed = layout.collapsed
    storedColors = layout.colors
    layoutVersion = "1"
    return true
  }

  private func publishLayout() {
    HomeLayoutCloud.write(order: storedOrder, collapsed: storedCollapsed, colors: storedColors)
  }

  private func graphicPath(_ widget: HomeWidget) -> String {
    widget == .photo ? photoPath : HomeWidgetDisplay.graphics(storedGraphics)[widget] ?? ""
  }

  private func chooseGraphic(_ widget: HomeWidget) {
    guard widget != .feast else { return }
    graphicTarget = widget; selectedPhoto = nil; showsGraphicPicker = true
  }

  @discardableResult private func removeGraphic(_ widget: HomeWidget) -> Bool {
    photoImport.cancel(widget)
    if graphicTarget == widget { selectedPhoto = nil }
    if widget == .photo { return removePhoto() }
    do {
      try HomePhotoStore.remove(graphicPath(widget))
      var graphics = HomeWidgetDisplay.graphics(storedGraphics)
      graphics[widget] = nil
      storedGraphics = HomeWidgetDisplay.encodeGraphics(graphics)
      return true
    } catch { showsPhotoError = true; return false }
  }

  private func reloadGraphics() {
    graphicImages = HomeWidgetDisplay.graphics(storedGraphics).compactMapValues { HomePhotoStore.image($0) }
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

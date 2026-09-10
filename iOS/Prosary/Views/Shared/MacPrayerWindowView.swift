#if os(macOS)
import SwiftUI

/// The library owns objects; this window owns the act of praying one of them.
/// No hidden library/navigation stack remains behind a prayer when its window closes.
struct MacPrayerWindowView: View {
  let request: PrayerWindowRequest
  @Environment(\.appServices) private var services
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow
  @State private var prayer: Prayer?
  @State private var editorPrayer: Prayer?
  @State private var loading = true
  @State private var error: String?
  @State private var actionError: String?
  @State private var removalRequest: MacPrayerRemovalRequest?
  @State private var isRemoving = false
  @State private var removedDuringAction = false
  @State private var revision = 0
  @State private var legacyPath: [AppRoute] = []
  @State private var hasAttachedSheet = false
  @State private var configurationReloadPending = false
  @State private var autoAdvanceSeconds = 0
  @State private var presentation = MacPrayerPresentation()

  private var windowContent: some View {
    NavigationStack {
      Group {
        if loading { ProgressView() }
        else if let error {
          ContentUnavailableView {
            Label(String(localized: "macLibrary.prayerUnavailable", defaultValue: "Prayer Unavailable"), systemImage: "exclamationmark.triangle")
          } description: { Text(error) }
        } else {
          prayerContent
            .id(revision)
        }
      }
      .toolbar(id: "Prosary.Prayer.Toolbar") {
        ToolbarItem(id: "prayer.settings") {
          Button {
            Task { await editPrayer() }
          } label: {
            Label(String(localized: "macLibrary.prayerSettings", defaultValue: "Prayer Settings…"), systemImage: "slider.horizontal.3")
          }
          .disabled(prayer == nil || presentation.isPresenting || isModal)
          .help(String(localized: "macLibrary.prayerSettings", defaultValue: "Prayer Settings…"))
          .accessibilityIdentifier("prayerWindowSettingsButton")
        }
        ToolbarItem(id: "prayer.presenter") {
          Button(action: presentationActions.toggle) {
            Label(presentation.isPresenting
              ? String(localized: "presenter.exit", defaultValue: "Exit Presenter Mode")
              : String(localized: "presenter.enter", defaultValue: "Enter Presenter Mode"), systemImage: "play.rectangle.on.rectangle")
          }
          .disabled(loading || isModal || error != nil)
          .help(presentation.isPresenting
            ? String(localized: "presenter.exit", defaultValue: "Exit Presenter Mode")
            : String(localized: "presenter.enter", defaultValue: "Enter Presenter Mode"))
          .accessibilityIdentifier("presenterModeButton")
        }
      }
    }
  }

  private var configuredWindow: some View {
    windowContent.modifier(MacToolbarCustomization())
    .environment(\.prayerProgressNamespace, request.id.uuidString)
    .environment(\.prayerWindowIsModal, isModal)
    .environment(\.prayerWindowTitle, prayer?.name)
    .environment(\.prayerAutoAdvanceSeconds, autoAdvanceBinding)
    .environment(\.macPrayerPresentation, presentationActions)
    .environment(\.finishPrayerSession, finish)
    .environment(\.windowNavigation, navigationActions)
    .focusedSceneValue(\.windowNavigation, isModal ? nil : navigationActions)
    .focusedSceneValue(\.macLibraryActions, isModal ? nil : libraryActions)
    .focusedSceneValue(\.macLibraryIsModal, isModal)
    .focusedSceneValue(\.macPrayerPresentation, isModal || loading || error != nil ? nil : presentationActions)
  }

  private var presentedWindow: some View {
    configuredWindow.sheet(item: $editorPrayer, onDismiss: { Task { await reloadAfterEditing() } }) { prayer in
      editorContent(for: prayer)
    }
    .alert(String(localized: "macLibrary.failed", defaultValue: "Could Not Complete Action"), isPresented: .init(
      get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
      Button("common.ok") {
        actionError = nil
        if removedDuringAction { closeRemovedPrayer() }
      }.keyboardShortcut(.defaultAction)
    } message: { Text(actionError ?? "") }
    .modifier(MacPrayerRemovalConfirmation(request: $removalRequest, onRemove: { removePrayer($0) }))
  }

  @ViewBuilder private func editorContent(for prayer: Prayer) -> some View {
    NavigationStack {
      if prayer.kind == .custom { RemindersOnlyEditorView(prayer: prayer) }
      else { FavoriteEditorView(prayer: prayer, isNew: false) }
    }
  }

  var body: some View {
    presentedWindow.background {
      MacWindowFocusReader(onActivate: {}, onClose: {}, onSheetChange: { hasAttachedSheet = $0 })
        .frame(width: 0, height: 0)
      if !loading {
        MacPrayerWindowGeometry(persistenceID: prayer?.id.uuidString
          ?? RecentPrayerStore.identity(for: request.route) ?? request.id.uuidString)
          .frame(width: 0, height: 0)
      }
    }
    .modifier(MacSceneBridge())
    .onReceive(NotificationCenter.default.publisher(for: .prayerConfigurationDidChange)) { notification in
      guard let id = notification.object as? UUID, id == prayer?.id else { return }
      if hasAttachedSheet { configurationReloadPending = true }
      else { Task { await reloadAfterEditing() } }
    }
    .onReceive(NotificationCenter.default.publisher(for: .prayerConfigurationDidDelete)) { notification in
      guard let id = notification.object as? UUID else { return }
      let routeID: UUID? = if case .prayer(let id) = request.route { id } else { nil }
      guard id == prayer?.id || id == routeID else { return }
      if isRemoving {
        // Keep this window alive long enough to show a possible download-cleanup error.
        removedDuringAction = true
        return
      }
      closeRemovedPrayer()
    }
    .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in
      Task { await validateAvailability() }
    }
    .onChange(of: hasAttachedSheet) { _, presented in
      if !presented, configurationReloadPending {
        configurationReloadPending = false
        Task { await reloadAfterEditing() }
      }
    }
    .task { await load() }
    .onChange(of: presentation) { _, value in
      guard error == nil else { return }
      MacPrayerPresentationStore.shared.save(value, for: prayer?.id ?? request.id)
    }
  }

  @ViewBuilder private var prayerContent: some View {
    if let prayer {
      switch prayer.kind {
      case .rosary:
        RosaryFlowView(prayer: prayer) { language in
          openRoute(.custom(devotionId: "litanyOfLoreto", languageCode: language, variantId: "afterRosary"))
        }
      case .jesusPrayer: JesusPrayerFlowView(path: $legacyPath, prayer: prayer)
      case .custom:
        if let id = prayer.customDevotionId { CustomDevotionFlowView(devotionId: id, prayer: prayer) }
      }
    } else {
      switch request.route {
      case .custom(let id, let language, let variant):
        CustomDevotionFlowView(devotionId: id, initialLanguageCode: language, initialVariantId: variant)
      case .basicPrayer(let id): BasicPrayerFlowView(prayerId: id)
      default:
        // Older saved scenes and menu setup routes still resolve in a separate window.
        ContentView(initialRoute: request.route, startsWithSidebarHidden: true)
      }
    }
  }

  private var navigationActions: WindowNavigationActions {
    WindowNavigationActions(selectedSection: .pray, canGoBack: false,
      currentRoute: prayer.map { .prayer(id: $0.id) } ?? request.route,
      selectSection: { _ in openWindow(id: "main") }, goBack: {}, openRoute: openRoute,
      importBundle: {
        openWindow(id: "main")
        MacDevotionImporter.open { _ in }
      })
  }

  private func openRoute(_ route: AppRoute) {
    openWindow(id: "prayer", value: PrayerWindowRequest(route: route))
  }

  private func finish() { dismissWindow(id: "prayer", value: request) }

  private func load() async {
    defer { loading = false }
    do {
      switch request.route {
      case .prayer(let id):
        guard let saved = try await services.presetStore.get(id: id) else { throw CocoaError(.fileNoSuchFile) }
        if let id = saved.customDevotionId, PrayerPackStore.info(for: id) == nil { throw CocoaError(.fileNoSuchFile) }
        prayer = saved
      case .rosaryQuickPray(var value):
        if value.name.isEmpty { value.name = PrayerKind.rosary.displayName }
        try await services.presetStore.save(value)
        prayer = value
      case .jesusPrayer(let target):
        let value = Prayer(name: PrayerKind.jesusPrayer.displayName, kind: .jesusPrayer,
          jesusPrayer: JesusPrayerOptions(target: target))
        try await services.presetStore.save(value)
        prayer = value
      case .custom(let id, let language, let variant) where language == nil && variant == nil:
        let model = MacPrayerLibraryModel(store: services.presetStore)
        await model.reload()
        guard let item = (model.items + model.galleryItems).first(where: { $0.devotionID == id })
        else { throw CocoaError(.fileNoSuchFile) }
        prayer = try await model.prayer(for: item)
      default: break
      }
      await RecentPrayers.shared.record(prayer.map { .prayer(id: $0.id) } ?? request.route)
      let settingsID = prayer?.id ?? request.id
      autoAdvanceSeconds = MacPrayerPlaybackSettings.shared.autoAdvanceSeconds(for: settingsID)
      MacPrayerPlaybackSettings.shared.setAutoAdvanceSeconds(autoAdvanceSeconds, for: settingsID)
      presentation = MacPrayerPresentationStore.shared.settings(for: settingsID)
    } catch { self.error = error.localizedDescription }
  }

  private func editPrayer() async {
    guard let prayer else { return }
    do {
      guard let latest = try await services.presetStore.get(id: prayer.id) else {
        closeRemovedPrayer()
        return
      }
      editorPrayer = latest
    }
    catch { actionError = error.localizedDescription }
  }

  private var libraryActions: MacLibraryActions {
    MacLibraryActions(canActOnSelection: prayer != nil && error == nil && !isRemoving,
      openSelection: {},
      duplicateSelection: { Task { await duplicatePrayer() } },
      editSelection: { Task { await editPrayer() } },
      importFiles: { openWindow(id: "main"); MacDevotionImporter.open { _ in } },
      showLibrary: { openWindow(id: "main") },
      showCommunity: {
        openWindow(id: "main")
        NotificationCenter.default.post(name: .macShowCommunity, object: nil)
      },
      removeSelection: { Task { await requestRemoval() } },
      removeSelectionTitle: String(localized: "macLibrary.deletePrayer", defaultValue: "Delete Prayer…"))
  }

  private var autoAdvanceBinding: Binding<Int> {
    Binding(get: { autoAdvanceSeconds }, set: { value in
      autoAdvanceSeconds = value
      MacPrayerPlaybackSettings.shared.setAutoAdvanceSeconds(value, for: prayer?.id ?? request.id)
    })
  }

  private var presentationActions: MacPrayerPresentationActions {
    MacPrayerPresentationActions(isPresenting: presentation.isPresenting, textSize: $presentation.textSize,
      toggle: { presentation.isPresenting.toggle() }, exit: { presentation.isPresenting = false })
  }

  private func duplicatePrayer() async {
    guard let prayer else { return }
    let model = MacPrayerLibraryModel(store: services.presetStore)
    await model.reload()
    guard let item = model.items.first(where: { $0.prayer?.id == prayer.id }) else { return }
    do {
      let copy = try await model.duplicate(item)
      openWindow(id: "prayer", value: PrayerWindowRequest(route: .prayer(id: copy.id)))
    } catch { actionError = error.localizedDescription }
  }

  private func reloadAfterEditing() async {
    guard let prayer else { return }
    do {
      guard let latest = try await services.presetStore.get(id: prayer.id) else {
        closeRemovedPrayer()
        return
      }
      if latest != prayer {
        let configurationChanged = latest.languageCode != prayer.languageCode
          || latest.rosary != prayer.rosary || latest.jesusPrayer != prayer.jesusPrayer
          || latest.variantId != prayer.variantId || latest.customOptions != prayer.customOptions
          || latest.dayIndex != prayer.dayIndex
        self.prayer = latest
        if configurationChanged { revision += 1 }
      }
    } catch { actionError = error.localizedDescription }
  }

  private var isModal: Bool {
    hasAttachedSheet || editorPrayer != nil || removalRequest != nil || isRemoving || actionError != nil
  }

  private func requestRemoval() async {
    guard let prayer, !isModal else { return }
    isRemoving = true
    defer { isRemoving = false }
    let model = MacPrayerLibraryModel(store: services.presetStore)
    await model.reload()
    guard let item = model.items.first(where: { $0.prayer?.id == prayer.id }) else {
      closeRemovedPrayer()
      return
    }
    do { removalRequest = try await model.removalRequest(for: item) }
    catch { actionError = error.localizedDescription }
  }

  private func removePrayer(_ request: MacPrayerRemovalRequest) {
    removalRequest = nil
    isRemoving = true
    Task {
      defer { isRemoving = false }
      do {
        try await MacPrayerLibraryModel(store: services.presetStore).remove(request)
        closeRemovedPrayer()
      } catch {
        actionError = error.localizedDescription
        if removedDuringAction {
          prayer = nil
          self.error = String(localized: "macLibrary.prayerRemoved", defaultValue: "This prayer has been removed from your library.")
        }
      }
    }
  }

  private func closeRemovedPrayer() {
    editorPrayer = nil
    removalRequest = nil
    error = String(localized: "macLibrary.prayerRemoved", defaultValue: "This prayer has been removed from your library.")
    prayer = nil
    // Allow an attached editor to dismiss before closing its parent window.
    Task { @MainActor in await Task.yield(); finish() }
  }

  private func validateAvailability() async {
    guard !loading, !isRemoving, error == nil else { return }
    if prayer != nil { await reloadAfterEditing() }
    if case .custom(let id, _, _) = request.route, PrayerPackStore.info(for: id) == nil {
      closeRemovedPrayer()
    } else if let id = prayer?.customDevotionId, PrayerPackStore.info(for: id) == nil {
      closeRemovedPrayer()
    }
  }
}

/// Dock and system intents always open a prayer window, without replacing a library or an
/// ongoing prayer. Installing the closure from either scene keeps Dock actions alive after
/// the last library window has been closed.
struct MacSceneBridge: ViewModifier {
  @Environment(\.openWindow) private var openWindow
  @State private var windowID = UUID()
  private var coordinator = NavigationCoordinator.shared

  func body(content: Content) -> some View {
    content
      .background {
        MacWindowFocusReader(onActivate: activate, onClose: { coordinator.closeWindow(windowID) }, onSheetChange: { _ in })
          .frame(width: 0, height: 0)
      }
      .onChange(of: coordinator.pendingRoute) { _, _ in consumePendingRoute() }
      .task {
        let opener = openWindow
        MacPrayerWindowActions.install { route in opener(id: "prayer", value: PrayerWindowRequest(route: route)) }
        await RecentPrayers.shared.refresh()
      }
      .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in
        Task<Void, Never> { await RecentPrayers.shared.refresh() }
      }
  }

  private func activate() { coordinator.activateWindow(windowID); consumePendingRoute() }
  private func consumePendingRoute() {
    if let route = coordinator.takePendingRoute(for: windowID) {
      openWindow(id: "prayer", value: PrayerWindowRequest(route: route))
    }
  }
}
#endif

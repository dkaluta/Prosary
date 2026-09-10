// Native Mac sidebar, with independent navigation in every window; tabs on other Apple devices.
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @State private var selectedTab: AppSection = .pray
  @State private var prayPath: [AppRoute]
  @State private var browsePath: [AppRoute] = []
  @State private var readingsPath: [AppRoute] = []
  @State private var searchPath: [AppRoute] = []
  @State private var routeLandingGeneration = 0
  @State private var pendingLandingRoute: AppRoute?
  @State private var windowID = UUID()
  @SceneStorage("macWindowStateID") private var storedWindowID = UUID().uuidString
  @State private var sidebarVisibility: NavigationSplitViewVisibility
  private var coordinator = NavigationCoordinator.shared
  @Environment(\.scenePhase) private var scenePhase
  @State private var showsBundleImporter = false
  @State private var importError: String?
  @State private var isBundleDropTarget = false
  @State private var hasAttachedSheet = false
  #if os(macOS)
  @Environment(\.openWindow) private var openWindow
  #endif

  init(initialRoute: AppRoute? = nil, startsWithSidebarHidden: Bool = false) {
    _prayPath = State(initialValue: initialRoute.map { [$0] } ?? [])
    _sidebarVisibility = State(initialValue: startsWithSidebarHidden ? .detailOnly : .all)
  }

  var body: some View {
    shell
      #if os(macOS)
      .environment(\.prayerProgressNamespace, storedWindowID)
      #endif
      .environment(\.windowNavigation, navigationActions)
      .focusedSceneValue(\.windowNavigation, hasAttachedSheet ? nil : navigationActions)
      .onChange(of: coordinator.pendingRoute) { _, _ in consumePendingRoute() }
      .fileImporter(isPresented: $showsBundleImporter, allowedContentTypes: [.prosaryPrayer, .zip]) { result in
        switch result {
        case .success(let url): importBundle(url)
        case .failure(let error): importError = error.localizedDescription
        }
      }
      .onOpenURL { url in
        if let link = ProsaryWidgetLink(url: url) {
          openWidgetLink(link)
          return
        }
        guard url.isFileURL, url.pathExtension.lowercased() == "prosaryprayer" else { return }
        importBundle(url)
      }
      #if os(macOS)
      .dropDestination(for: URL.self) { urls, _ in
        let bundles = urls.filter { $0.isFileURL && $0.pathExtension.lowercased() == "prosaryprayer" }
        guard !bundles.isEmpty else { return false }
        bundles.forEach(importBundle)
        return true
      } isTargeted: { isBundleDropTarget = $0 }
      .overlay {
        if isBundleDropTarget {
          RoundedRectangle(cornerRadius: 8).stroke(.tint, lineWidth: 3)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
      }
      #endif
      .alert(
        String(localized: "favorites.importFailed", defaultValue: "Could Not Import Devotion"),
        isPresented: .init(get: { importError != nil }, set: { if !$0 { importError = nil } })
      ) {
        Button(String(localized: "common.ok", defaultValue: "OK")) {}
          .keyboardShortcut(.defaultAction)
      } message: {
        Text(importError ?? "")
      }
      #if os(macOS)
      .background {
        MacWindowFocusReader(
          onActivate: activateWindow,
          onClose: { coordinator.closeWindow(windowID) },
          onSheetChange: { hasAttachedSheet = $0 }
        )
          .frame(width: 0, height: 0)
      }
      .onChange(of: hasAttachedSheet) { _, presented in
        if !presented { consumePendingRoute() }
      }
      .task {
        let windowOpener = openWindow
        MacPrayerWindowActions.install { route in
          windowOpener(id: "prayer", value: PrayerWindowRequest(route: route))
        }
        await RecentPrayers.shared.refresh()
      }
      .task(id: activePath.wrappedValue.last) {
        if let route = activePath.wrappedValue.last { await RecentPrayers.shared.record(route) }
      }
      .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in
        Task<Void, Never> { await RecentPrayers.shared.refresh() }
      }
      #else
      .task { activateWindow() }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active { activateWindow() }
      }
      #endif
      // Menu tracking has to end and the fresh stack has to exist before populating it.
      .task(id: routeLandingGeneration) {
        await completePendingRouteLanding(generation: routeLandingGeneration)
      }
  }

  @ViewBuilder
  private var shell: some View {
    #if os(macOS)
    NavigationSplitView(columnVisibility: $sidebarVisibility) {
      List(selection: Binding<AppSection?>(get: { selectedTab }, set: { if let section = $0 { selectedTab = section } })) {
        ForEach(AppSection.allCases, id: \.self) { section in
          Label(section.title, systemImage: section.systemImage)
            .tag(section)
            .accessibilityIdentifier("sidebar.\(section.rawValue)")
        }
      }
      .listStyle(.sidebar)
      .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 260)
    } detail: {
      sectionView(selectedTab)
        .frame(minWidth: 360)
    }
    #else
    TabView(selection: $selectedTab) {
      ForEach(AppSection.allCases, id: \.self) { section in
        sectionView(section)
          .tabItem { Label(section.title, systemImage: section.systemImage) }
          .tag(section)
      }
    }
    .adaptiveTabViewStyle()
    #endif
  }

  @ViewBuilder
  private func sectionView(_ section: AppSection) -> some View {
    switch section {
    case .pray:
      NavigationStack(path: $prayPath) {
        HomeView(path: $prayPath)
          .appRouteDestinations(path: $prayPath)
      }
      // A replaced stack needs a new identity so AppKit's Back control and the path agree.
      .id(routeLandingGeneration)
    case .browse:
      NavigationStack(path: $browsePath) {
        RepositoryBrowserView(presentedAsSheet: false)
          .appRouteDestinations(path: $browsePath)
      }
    case .readings:
      NavigationStack(path: $readingsPath) {
        #if os(macOS)
        MacTodayView()
          .appRouteDestinations(path: $readingsPath)
        #else
        ReadingsView()
          .appRouteDestinations(path: $readingsPath)
        #endif
      }
    case .search:
      NavigationStack(path: $searchPath) {
        SearchTabView(path: $searchPath)
          .appRouteDestinations(path: $searchPath)
      }
    }
  }

  private var activePath: Binding<[AppRoute]> {
    switch selectedTab {
    case .pray: $prayPath
    case .browse: $browsePath
    case .readings: $readingsPath
    case .search: $searchPath
    }
  }

  private var navigationActions: WindowNavigationActions {
    WindowNavigationActions(
      selectedSection: selectedTab,
      canGoBack: !activePath.wrappedValue.isEmpty,
      currentRoute: activePath.wrappedValue.last,
      selectSection: { selectedTab = $0 },
      goBack: {
        if !activePath.wrappedValue.isEmpty { activePath.wrappedValue.removeLast() }
      },
      openRoute: land,
      importBundle: { showsBundleImporter = true }
    )
  }

  private func activateWindow() {
    coordinator.activateWindow(windowID)
    consumePendingRoute()
  }

  private func openWidgetLink(_ link: ProsaryWidgetLink) {
    switch link {
    case .today, .library:
      routeLandingGeneration += 1
      pendingLandingRoute = nil
      selectedTab = .pray
      prayPath = []
      // A fresh HomeView starts at the actual local day, even after date browsing.
    case .prayer(let id): land(.prayer(id: id))
    case .rosary:
      Task {
        let saved = try? await AppServices.shared.presetStore.defaultPreset(kind: .rosary)
        land(.rosaryQuickPray(prayer: ProsaryWidgetLink.rosaryPrayer(from: saved)))
      }
    }
  }

  private func consumePendingRoute() {
    guard !hasAttachedSheet else { return }
    if let route = coordinator.takePendingRoute(for: windowID) { land(route) }
  }

  private func importBundle(_ url: URL) {
    do {
      #if os(macOS)
      _ = try PrayerPackStore.installPack(fromUserSelected: url)
      // Legacy restored windows also send imported packs to the Mac Gallery, preserving
      // this window's current prayer and any attached editor.
      openWindow(id: "main")
      DispatchQueue.main.async {
        NotificationCenter.default.post(name: .macShowGallery, object: nil)
      }
      #else
      let devotionID = try PrayerPackStore.installPack(fromUserSelected: url)
      // Open what was imported so a successful Finder/File action has an immediate result.
      land(.custom(devotionId: devotionID))
      #endif
    } catch {
      importError = error.localizedDescription
    }
  }

  /// An external request starts one clean stack in this window, never in a sibling window.
  private func land(_ route: AppRoute) {
    routeLandingGeneration += 1
    pendingLandingRoute = route
    selectedTab = .pray
    prayPath = []
  }

  private func completePendingRouteLanding(generation: Int) async {
    guard generation == routeLandingGeneration, let route = pendingLandingRoute else { return }
    await Task.yield()
    guard !Task.isCancelled, generation == routeLandingGeneration,
          pendingLandingRoute == route else { return }
    prayPath = [route]
    pendingLandingRoute = nil
  }
}

private extension View {
  @ViewBuilder
  func adaptiveTabViewStyle() -> some View {
    if #available(iOS 18.0, macOS 15.0, visionOS 2.0, *) {
      self.tabViewStyle(.sidebarAdaptable)
    } else {
      self
    }
  }
}

#Preview { ContentView() }

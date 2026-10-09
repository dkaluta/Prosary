import SwiftUI
import Combine
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// These IDs and colors match the palette shared by the native apps.
enum AppColor: String, CaseIterable, Identifiable {
  case blue, green, red, purple, rose, white, gold

  static let defaultsKey = "appColor"
  var id: String { rawValue }
  static func resolved(_ raw: String?) -> Self { Self(rawValue: raw ?? "") ?? .blue }
  static func appearanceChoice(_ raw: String?) -> Self {
    #if os(macOS)
    .blue
    #else
    resolved(raw)
    #endif
  }
  static var current: Self { appearanceChoice(UserDefaults.standard.string(forKey: defaultsKey)) }

  var lightHex: String {
    switch self {
    case .blue: "#1768AC"
    case .green: "#287D49"
    case .red: "#B52E3E"
    case .purple: "#7545A0"
    case .rose: "#AD3F70"
    case .white: "#8B681B"
    case .gold: "#886419"
    }
  }

  var darkHex: String {
    switch self {
    case .blue: "#8DC8FF"
    case .green: "#8AD4A1"
    case .red: "#FFB1B5"
    case .purple: "#D7B4F4"
    case .rose: "#F3B0CB"
    case .white, .gold: "#F0D389"
    }
  }

  var color: Color { .adaptive(light: lightHex, dark: darkHex) }
  private var assetSuffix: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
  var alternateIconName: String? { self == .blue ? nil : "Prosary\(assetSuffix)" }
  var previewAssetName: String { "AppIcon\(assetSuffix)" }

  #if os(macOS)
  func dockIconAssetName(isDark: Bool) -> String? {
    nil
  }
  #endif

  var title: String {
    switch self {
    case .blue: String(localized: "settings.appColor.blue", defaultValue: "Blue", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .green: String(localized: "settings.appColor.green", defaultValue: "Green", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .red: String(localized: "settings.appColor.red", defaultValue: "Red", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .purple: String(localized: "settings.appColor.purple", defaultValue: "Purple", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .rose: String(localized: "settings.appColor.rose", defaultValue: "Rose", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .white: String(localized: "settings.appColor.white", defaultValue: "White", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .gold: String(localized: "settings.appColor.gold", defaultValue: "Gold", bundle: UILanguage.bundle, locale: UILanguage.locale)
    }
  }
}

extension Color {
  /// Mac uses the live system accent; other Apple ports retain the chosen window accent.
  static var appAccent: Color {
    #if os(macOS)
    Color(nsColor: .controlAccentColor)
    #else
    .accentColor
    #endif
  }
}

#if os(macOS)
private enum MacSystemAccentRevisionKey: EnvironmentKey {
  static let defaultValue = 0
}
extension EnvironmentValues {
  var macSystemAccentRevision: Int {
    get { self[MacSystemAccentRevisionKey.self] }
    set { self[MacSystemAccentRevisionKey.self] = newValue }
  }
}
#endif

@MainActor
final class AppIconController: ObservableObject {
  static let shared = AppIconController()
  @Published var errorMessage: String?
  private var isUpdating = false
  private var requestedColor: AppColor = .blue
  private init() {}

  func synchronize(_ color: AppColor) {
    // Unit/UI tests never change the person's installed application icon.
    guard !ProsaryRuntimeEnvironment.isTesting else { return }
    #if os(macOS)
    requestedColor = .blue
    // Restore the default Marian-blue Icon Composer asset, including its native dark rendition.
    NSApplication.shared.applicationIconImage = nil
    #elseif os(iOS)
    requestedColor = color
    guard !isUpdating, UIApplication.shared.applicationState == .active,
          UIApplication.shared.supportsAlternateIcons,
          UIApplication.shared.alternateIconName != color.alternateIconName else { return }
    isUpdating = true
    Task {
      do {
        try await UIApplication.shared.setAlternateIconName(color.alternateIconName)
        errorMessage = nil
      } catch {
        errorMessage = error.localizedDescription
      }
      isUpdating = false
      if requestedColor != color { synchronize(requestedColor) }
    }
    #endif
  }
}

private struct AppAppearanceModifier: ViewModifier {
  #if os(macOS)
  @State private var accentRevision = 0
  #else
  @AppStorage(AppColor.defaultsKey) private var storedColor = AppColor.blue.rawValue
  #endif
  @Environment(\.scenePhase) private var scenePhase

  func body(content: Content) -> some View {
    #if os(macOS)
    content
      .environment(\.macSystemAccentRevision, accentRevision)
      .onReceive(NotificationCenter.default.publisher(for: NSColor.systemColorsDidChangeNotification)) { _ in
        accentRevision &+= 1
      }
      .onAppear { AppIconController.shared.synchronize(.blue) }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active { AppIconController.shared.synchronize(.blue) }
      }
    #else
    let color = AppColor.appearanceChoice(storedColor)
    content
      .tint(color.color)
      .accentColor(color.color)
      .onAppear { AppIconController.shared.synchronize(color) }
      .onChange(of: storedColor) { _, _ in AppIconController.shared.synchronize(color) }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active { AppIconController.shared.synchronize(color) }
      }
    #endif
  }
}

extension View {
  func appAppearance() -> some View { modifier(AppAppearanceModifier()) }
}

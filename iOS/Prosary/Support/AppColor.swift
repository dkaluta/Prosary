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
  static var current: Self { resolved(UserDefaults.standard.string(forKey: defaultsKey)) }

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
    isDark || self == .blue ? nil : previewAssetName
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
  /// Resolve the app's chosen accent from the window environment, including presented sheets.
  static var appAccent: Color { .accentColor }
}

@MainActor
final class AppIconController: ObservableObject {
  static let shared = AppIconController()
  @Published var errorMessage: String?
  private var isUpdating = false
  private var requestedColor: AppColor = .blue
  #if os(macOS)
  private var appearanceObservation: NSKeyValueObservation?
  #endif

  private init() {
    #if os(macOS)
    // Keep the Dock in sync even after the last app window has closed.
    appearanceObservation = NSApplication.shared.observe(\.effectiveAppearance) { [weak self] _, _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.synchronize(self.requestedColor)
      }
    }
    #endif
  }

  func synchronize(_ color: AppColor) {
    // Unit/UI tests never change the person's installed application icon.
    guard !ProsaryRuntimeEnvironment.isTesting else { return }
    requestedColor = color
    #if os(macOS)
    let isDark = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    // The native Icon Composer asset retains the original dark glass and silver cross.
    NSApplication.shared.applicationIconImage = color.dockIconAssetName(isDark: isDark).flatMap { NSImage(named: $0) }
    #elseif os(iOS)
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
  @AppStorage(AppColor.defaultsKey) private var storedColor = AppColor.blue.rawValue
  @Environment(\.scenePhase) private var scenePhase

  func body(content: Content) -> some View {
    let color = AppColor.resolved(storedColor)
    content
      .tint(color.color)
      .accentColor(color.color)
      .onAppear { AppIconController.shared.synchronize(color) }
      .onChange(of: storedColor) { _, _ in AppIconController.shared.synchronize(color) }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active { AppIconController.shared.synchronize(color) }
      }
  }
}

extension View {
  func appAppearance() -> some View { modifier(AppAppearanceModifier()) }
}

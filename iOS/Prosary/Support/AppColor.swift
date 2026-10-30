import SwiftUI
import Combine
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
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

enum CustomAccentColor {
  static let defaultsKey = "customAccentColorHex"

  static func normalized(_ raw: String?) -> String? {
    guard let raw else { return nil }
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    let digits = value.hasPrefix("#") ? String(value.dropFirst()) : value
    guard digits.count == 6, digits.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) }) else { return nil }
    return "#" + digits
  }

  static func color(_ raw: String, fallback: AppColor) -> Color {
    guard let raw = normalized(raw) else { return fallback.color }
    return .adaptive(light: readableHex(raw, dark: false), dark: readableHex(raw, dark: true))
  }

  /// Keep the chosen hue while adapting text/control accents for both native appearances.
  static func readableHex(_ hex: String, dark: Bool) -> String {
    guard let normalized = normalized(hex), let value = UInt32(normalized.dropFirst(), radix: 16) else { return hex }
    let channels = [16, 8, 0].map { Double((value >> $0) & 255) / 255 }
    let background = dark ? Double(28) / 255 : 1
    func luminance(_ channels: [Double]) -> Double {
      zip(channels, [0.2126, 0.7152, 0.0722]).reduce(0) { sum, component in
        let channel = component.0
        return sum + (channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)) * component.1
      }
    }
    let backdrop = luminance([background, background, background])
    for step in 0...100 {
      let amount = Double(step) / 100
      let adjusted = channels.map { $0 * (1 - amount) + (dark ? amount : 0) }
      let light = luminance(adjusted)
      if (max(light, backdrop) + 0.05) / (min(light, backdrop) + 0.05) >= 4.55 {
        return String(format: "#%02X%02X%02X", Int((adjusted[0] * 255).rounded()), Int((adjusted[1] * 255).rounded()), Int((adjusted[2] * 255).rounded()))
      }
    }
    return dark ? "#FFFFFF" : "#000000"
  }

  #if canImport(UIKit)
  static func hex(_ color: Color) -> String? {
    let source = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    guard source.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
    return String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
  }
  #endif
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

enum AppPalette {
  static let key = "appPalette"
  static let ids = ["native", "stainedGlass", "garden"]
  static func colors(_ id: String) -> [AppColor] {
    switch id {
    case "stainedGlass": [.blue, .green, .gold, .rose]
    case "garden": [.green, .rose, .blue, .gold]
    default: []
    }
  }
  static func cardColor(_ id: String, index: Int) -> TodayCardColor {
    let colors = colors(id)
    return colors.isEmpty ? .default : TodayCardColor(rawValue: colors[index % colors.count].rawValue) ?? .default
  }
}

private struct AppAppearanceModifier: ViewModifier {
  #if os(macOS)
  @State private var accentRevision = 0
  #else
  @AppStorage(AppColor.defaultsKey, store: ProsaryRuntimeEnvironment.defaults) private var storedColor = AppColor.blue.rawValue
  @AppStorage(CustomAccentColor.defaultsKey, store: ProsaryRuntimeEnvironment.defaults) private var customAccent = ""
  @AppStorage("appThemeMode", store: ProsaryRuntimeEnvironment.defaults) private var themeMode = "system"
  @AppStorage(AppPalette.key, store: ProsaryRuntimeEnvironment.defaults) private var palette = "native"
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
    let color = AppPalette.colors(palette).first ?? AppColor.appearanceChoice(storedColor)
    let accent = CustomAccentColor.color(customAccent, fallback: color)
    content
      .preferredColorScheme(themeMode == "dark" ? .dark : themeMode == "light" ? .light : nil)
      .tint(accent)
      .accentColor(accent)
      .onAppear { AppIconController.shared.synchronize(AppColor.appearanceChoice(storedColor)) }
      .onChange(of: storedColor) { _, _ in AppIconController.shared.synchronize(AppColor.appearanceChoice(storedColor)) }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active { AppIconController.shared.synchronize(AppColor.appearanceChoice(storedColor)) }
      }
    #endif
  }
}

extension View {
  func appAppearance() -> some View { modifier(AppAppearanceModifier()) }
}

//
//  PrayerLanguageMonitor.swift
//  Prosary
//
//  Publishes the resolved default prayer language so name-bearing screens re-derive the moment
//  Settings changes it — including from the Mac's Settings window, a separate scene.
//
//  This exists because every simpler mechanism failed in practice, each diagnosed live on the
//  Mac (2026-08-08): @AppStorage declared in the view did not invalidate across scenes;
//  @AppStorage read in body did not either; onReceive(UserDefaults.didChangeNotification)
//  writing @State fired, but the notification arrives while the Settings picker's NSMenu still
//  runs its tracking run-loop and the state write is silently dropped (instrumentation showed
//  the first write lost and only a second, unrelated notification landing it);
//  DispatchQueue.main.async deferred nothing, because the main queue drains in common modes and
//  tracking is one of them. RunLoop.main as a Combine scheduler is the piece that actually
//  waits: it delivers in default mode only, which is after the menu closes — and @Published's
//  objectWillChange makes the invalidation unconditional.
//

import Combine
import Foundation

@MainActor
final class PrayerLanguageMonitor: ObservableObject {
  static let shared = PrayerLanguageMonitor(defaults: .standard,
    resolveCode: { LanguageCatalog.resolve(nil).code },
    resolveFallbackOrder: { LanguageCatalog.fallbackOrder })

  /// The resolved default prayer-language code ("he-x-gamliel", "la", …). Reading this in a
  /// view's body is what registers the dependency — see the header for why nothing less works.
  @Published private(set) var code: String
  @Published private(set) var showsPrayerNameInPrayerLanguage: Bool
  @Published private(set) var usesJaffaHailMaryWording: Bool
  /// Effective labels can change when fallback priority changes, even if the chosen language
  /// does not. Preserve the order rather than treating it as an unordered set of languages.
  @Published private(set) var fallbackOrder: [String]

  private struct NameSettings: Equatable {
    let code: String
    let showsPrayerName: Bool
    let usesJaffaWording: Bool
    let fallbackOrder: [String]
  }

  private var cancellable: AnyCancellable?

  /// Tests supply a disposable preference suite and resolvers without changing the singleton
  /// or the person's actual language/fallback settings.
  init(defaults: UserDefaults, notificationCenter: NotificationCenter = .default,
       resolveCode: @escaping () -> String, resolveFallbackOrder: @escaping () -> [String]) {
    let readSettings = {
      NameSettings(code: resolveCode(),
        showsPrayerName: defaults.bool(forKey: PrayerNamePresentation.defaultsKey),
        usesJaffaWording: defaults.bool(forKey: JaffaHailMaryWording.defaultsKey),
        fallbackOrder: resolveFallbackOrder())
    }
    let initial = readSettings()
    code = initial.code
    showsPrayerNameInPrayerLanguage = initial.showsPrayerName
    usesJaffaHailMaryWording = initial.usesJaffaWording
    fallbackOrder = initial.fallbackOrder
    cancellable = notificationCenter.publisher(for: UserDefaults.didChangeNotification)
      .receive(on: RunLoop.main)
      .map { _ in readSettings() }
      .removeDuplicates()
      .sink { [weak self] resolved in
        self?.code = resolved.code
        self?.showsPrayerNameInPrayerLanguage = resolved.showsPrayerName
        self?.usesJaffaHailMaryWording = resolved.usesJaffaWording
        self?.fallbackOrder = resolved.fallbackOrder
      }
  }
}

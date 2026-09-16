import SwiftUI

/// Never present an apparently empty library when persistent storage could not be opened.
struct PrayerStoreStartupGuard: ViewModifier {
  func body(content: Content) -> some View {
    if let error = AppServices.persistenceError {
      ContentUnavailableView {
        Label(String(localized: "prayerStore.unavailableTitle", defaultValue: "Prayer Library Could Not Be Opened", bundle: UILanguage.bundle, locale: UILanguage.locale),
              systemImage: "externaldrive.badge.exclamationmark")
      } description: {
        VStack(spacing: 12) {
          Text(error.localizedDescription)
          Text(String(localized: "prayerStore.restartDetail",
                      defaultValue: "Your library has not been reset. Reopen Prosary to try again.", bundle: UILanguage.bundle, locale: UILanguage.locale))
        }
        .textSelection(.enabled)
      } actions: {
        #if os(macOS)
        Button(String(localized: "mac.quit", defaultValue: "Quit Prosary", bundle: UILanguage.bundle, locale: UILanguage.locale)) { NSApp.terminate(nil) }
        #endif
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityIdentifier("prayerStore.unavailable")
    } else { content }
  }
}

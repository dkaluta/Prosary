#if os(macOS)
import AppKit
import SwiftUI

struct MacLibraryCommands: Commands {
  @Environment(\.openWindow) private var openWindow
  @FocusedValue(\.macLibraryActions) private var actions
  @FocusedValue(\.macLibraryIsModal) private var isModal
  @FocusedValue(\.macPrayerPresentation) private var presentation
  @State private var textIsEditing = false

  var body: some Commands {
    CommandGroup(replacing: .appInfo) {
      Button("about.navigationTitle") { openWindow(id: "about") }
    }
    CommandGroup(replacing: .newItem) {
      Button(String(localized: "macLibrary.showLibrary", defaultValue: "Show Library", bundle: UILanguage.bundle, locale: UILanguage.locale)) { showLibrary() }
        .keyboardShortcut("n", modifiers: .command)
      Menu(String(localized: "commands.recentlyPrayed", defaultValue: "Recently Prayed", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
        ForEach(RecentPrayers.shared.entries) { entry in
          Button(entry.title) {
            Task {
              if let route = await RecentPrayers.shared.routeForOpening(id: entry.id) {
                openWindow(id: "prayer", value: PrayerWindowRequest(route: route))
              }
            }
          }
        }
      }
      .disabled(RecentPrayers.shared.entries.isEmpty)
      .disabled(isModal == true)
      Divider()
      Button("favorites.importBundle") {
        if let actions { actions.importFiles() }
        else { showLibrary(); MacDevotionImporter.open { _ in } }
      }
      .keyboardShortcut("o", modifiers: .command)
      .disabled(isModal == true)
    }
    CommandMenu(String(localized: "macLibrary.prayerMenu", defaultValue: "Prayer", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
      Button(String(localized: "macLibrary.open", defaultValue: "Open", bundle: UILanguage.bundle, locale: UILanguage.locale)) { actions?.openSelection() }
        .keyboardShortcut(.downArrow, modifiers: .command)
        .disabled(actions?.canActOnSelection != true)
      Button(String(localized: "macLibrary.duplicate", defaultValue: "Duplicate", bundle: UILanguage.bundle, locale: UILanguage.locale)) { actions?.duplicateSelection() }
        .keyboardShortcut("d", modifiers: .command)
        .disabled(actions?.canActOnSelection != true)
      Button(String(localized: "macLibrary.prayerSettings", defaultValue: "Prayer Settings…", bundle: UILanguage.bundle, locale: UILanguage.locale)) { actions?.editSelection() }
        .keyboardShortcut("i", modifiers: .command)
        .disabled(actions?.canActOnSelection != true)
      Button(String(localized: "macLibrary.editTags", defaultValue: "Tags…", bundle: UILanguage.bundle, locale: UILanguage.locale)) { actions?.editTags?() }
        .disabled(actions?.canActOnSelection != true || actions?.editTags == nil)
      Divider()
      Button(actions?.removeSelectionTitle
        ?? String(localized: "macLibrary.deletePrayer", defaultValue: "Delete Prayer…", bundle: UILanguage.bundle, locale: UILanguage.locale), role: .destructive) {
        performRemoval()
      }
      .keyboardShortcut(.delete, modifiers: .command)
      .disabled(actions?.canActOnSelection != true || actions?.removeSelection == nil || textIsEditing)
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.didUpdateNotification)) { _ in
        let editing = (NSApp.keyWindow?.firstResponder as? NSTextView)?.isEditable == true
        if textIsEditing != editing { textIsEditing = editing }
      }
      .onReceive(NotificationCenter.default.publisher(for: NSControl.textDidBeginEditingNotification)) { _ in
        textIsEditing = true
      }
    }
    CommandMenu(String(localized: "commands.navigation", defaultValue: "Go", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
      Button(String(localized: "macLibrary.title", defaultValue: "Library", bundle: UILanguage.bundle, locale: UILanguage.locale)) { showLibrary() }
        .keyboardShortcut("1", modifiers: .command)
      Button(String(localized: "macLibrary.community", defaultValue: "Community Devotions", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
        openWindow(id: "main")
        NotificationCenter.default.post(name: .macShowCommunity, object: nil)
      }
      .keyboardShortcut("2", modifiers: .command)
      Button(String(localized: "macLibrary.gallery", defaultValue: "Prayer Gallery", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
        openWindow(id: "main")
        NotificationCenter.default.post(name: .macShowGallery, object: nil)
      }
      .keyboardShortcut("3", modifiers: .command)
      Button(String(localized: "home.today.today", defaultValue: "Today", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
        openWindow(id: "main")
        NotificationCenter.default.post(name: .macShowToday, object: nil)
      }
      .keyboardShortcut("4", modifiers: .command)
      Button(String(localized: "basicPrayers.title", defaultValue: "Basic Prayers", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
        openWindow(id: "main")
        NotificationCenter.default.post(name: .macShowBasicPrayers, object: nil)
      }
      .keyboardShortcut("5", modifiers: .command)
    }
    CommandGroup(after: .toolbar) {
      Menu(String(localized: "macToolbar.appearance", defaultValue: "Toolbar Appearance", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
        Button(String(localized: "macToolbar.iconAndText", defaultValue: "Icon and Text", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
          NSApp.keyWindow?.toolbar?.displayMode = .iconAndLabel
        }
        Button(String(localized: "macToolbar.iconOnly", defaultValue: "Icon Only", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
          NSApp.keyWindow?.toolbar?.displayMode = .iconOnly
        }
        Button(String(localized: "macToolbar.textOnly", defaultValue: "Text Only", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
          NSApp.keyWindow?.toolbar?.displayMode = .labelOnly
        }
      }
      .disabled(actions == nil || isModal == true)
      Button(String(localized: "macToolbar.customize", defaultValue: "Customize Toolbar…", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
        NSApp.keyWindow?.toolbar?.runCustomizationPalette(nil)
      }
      .disabled(actions == nil || isModal == true)
      Divider()
      Button(presentation?.isPresenting == true
        ? String(localized: "presenter.exit", defaultValue: "Exit Presenter Mode", bundle: UILanguage.bundle, locale: UILanguage.locale)
        : String(localized: "presenter.enter", defaultValue: "Enter Presenter Mode", bundle: UILanguage.bundle, locale: UILanguage.locale)) { presentation?.toggle() }
        .keyboardShortcut("p", modifiers: [.command, .shift])
        .disabled(presentation == nil)
      Button(String(localized: "presenter.largerText", defaultValue: "Larger Text", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
        if let presentation { presentation.textSize.wrappedValue = min(96, presentation.textSize.wrappedValue + 4) }
      }
      .keyboardShortcut("+", modifiers: .command)
      .disabled(presentation?.isPresenting != true || (presentation?.textSize.wrappedValue ?? 96) >= 96)
      Button(String(localized: "presenter.smallerText", defaultValue: "Smaller Text", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
        if let presentation { presentation.textSize.wrappedValue = max(24, presentation.textSize.wrappedValue - 4) }
      }
      .keyboardShortcut("-", modifiers: .command)
      .disabled(presentation?.isPresenting != true || (presentation?.textSize.wrappedValue ?? 24) <= 24)
    }
    CommandGroup(replacing: .help) {
      Link(String(localized: "commands.help", defaultValue: "Prosary Help", bundle: UILanguage.bundle, locale: UILanguage.locale), destination: URL(string: "https://prosary.app/")!)
    }
  }

  private func showLibrary() {
    openWindow(id: "main")
    NotificationCenter.default.post(name: .macShowLibrary, object: nil)
  }

  private func performRemoval() {
    // A field editor can become first responder immediately before SwiftUI refreshes menu
    // validation. Preserve native Command-Delete text editing even in that narrow interval.
    if let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.isEditable {
      if NSApp.currentEvent?.type == .keyDown { editor.deleteToBeginningOfLine(nil) }
      return
    }
    actions?.removeSelection?()
  }
}
#endif

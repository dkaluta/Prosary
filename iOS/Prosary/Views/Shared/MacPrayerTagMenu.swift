#if os(macOS)
import AppKit
import SwiftUI

/// Finder-style controls for the person's stored tags and Tags… in one native menu item.
/// The same view is installed in the library's icon and list menus.
final class MacPrayerTagMenuRow: NSView {
  private static let columnCount = 8
  private let choices: [MacPrayerTag]
  private let selectedIDs: Set<String>
  private let onToggle: (MacPrayerTag) -> Void
  private let onClear: () -> Void
  private let onEdit: () -> Void
  private let caption = NSTextField(labelWithString: "")
  private let edit = NSButton(title: String(localized: "macLibrary.editTags", defaultValue: "Tags…"), target: nil, action: nil)
  private let tagIcon = NSImageView()
  private var buttons: [MacPrayerTagMenuButton] = []
  private var keyboardIndex: Int?

  init(tags: [MacPrayerTag], selectedIDs: Set<String>, isEnabled: Bool = true,
       onToggle: @escaping (MacPrayerTag) -> Void, onClear: @escaping () -> Void,
       onEdit: @escaping () -> Void) {
    choices = tags
    self.selectedIDs = selectedIDs
    self.onToggle = onToggle
    self.onClear = onClear
    self.onEdit = onEdit
    let rowCount = (tags.count + Self.columnCount) / Self.columnCount
    let footerY = 32 + CGFloat(rowCount - 1) * 28
    super.init(frame: NSRect(x: 0, y: 0, width: 248, height: footerY + 25))
    autoresizingMask = [.width]
    setAccessibilityRole(.group)
    setAccessibilityLabel(String(localized: "macLibrary.tags", defaultValue: "Tags"))
    let clear = MacPrayerTagMenuButton(tag: nil, selected: false)
    clear.isEnabled = isEnabled && !selectedIDs.isEmpty
    clear.onHover = { [weak self] hovered in
      self?.showCaption(hovered ? String(localized: "macLibrary.removeAllTags", defaultValue: "Remove All Tags") : nil)
    }
    clear.onPress = { [weak self] in self?.finish { $0.onClear() } }
    buttons.append(clear)
    for tag in choices {
      let selected = selectedIDs.contains(tag.id)
      let button = MacPrayerTagMenuButton(tag: tag, selected: selected)
      button.isEnabled = isEnabled
      button.onHover = { [weak self] hovered in self?.showCaption(hovered ? Self.caption(for: tag, selected: selected) : nil) }
      button.onPress = { [weak self] in self?.finish { $0.onToggle(tag) } }
      buttons.append(button)
    }
    for (index, button) in buttons.enumerated() {
      button.frame = NSRect(x: 10 + CGFloat(index % Self.columnCount) * 28,
        y: 5 + CGFloat(index / Self.columnCount) * 28, width: 24, height: 24)
      addSubview(button)
    }

    edit.frame = NSRect(x: 13, y: footerY, width: 196, height: 20)
    edit.autoresizingMask = [.width]
    edit.isBordered = false
    edit.alignment = .left
    edit.font = .menuFont(ofSize: 13)
    edit.target = self
    edit.action = #selector(editTags)
    edit.isEnabled = isEnabled
    edit.identifier = .init("macLibrary.editTags")
    addSubview(edit)
    tagIcon.image = NSImage(systemSymbolName: "tag", accessibilityDescription: nil)
    tagIcon.contentTintColor = .secondaryLabelColor
    tagIcon.frame = NSRect(x: 220, y: footerY + 2, width: 15, height: 15)
    tagIcon.autoresizingMask = [.minXMargin]
    tagIcon.setAccessibilityElement(false)
    addSubview(tagIcon)
    caption.frame = edit.frame
    caption.autoresizingMask = [.width]
    caption.font = .menuFont(ofSize: 13)
    caption.textColor = .secondaryLabelColor
    caption.lineBreakMode = .byTruncatingTail
    caption.setAccessibilityElement(false)
    caption.isHidden = true
    addSubview(caption)
  }

  required init?(coder: NSCoder) { nil }
  override var isFlipped: Bool { true }
  override var acceptsFirstResponder: Bool { true }

  private static func caption(for tag: MacPrayerTag, selected: Bool) -> String {
    String(format: selected
      ? String(localized: "macLibrary.removeTagLabel", defaultValue: "Remove “%@”")
      : String(localized: "macLibrary.addTagLabel", defaultValue: "Add “%@”"), tag.title)
  }

  private func showCaption(_ title: String?) {
    caption.stringValue = title ?? ""
    caption.isHidden = title == nil
    edit.isHidden = title != nil
    tagIcon.isHidden = title != nil
  }

  private func finish(_ action: @escaping (MacPrayerTagMenuRow) -> Void) {
    enclosingMenuItem?.menu?.cancelTracking()
    // A tag update may rebuild the collection; wait until AppKit finishes menu tracking.
    DispatchQueue.main.async { action(self) }
  }

  @objc private func editTags() { finish { $0.onEdit() } }

  override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 123, 124:
      let movement = event.keyCode == 123 ? -1 : 1
      let start = keyboardIndex ?? (movement > 0 ? -1 : 0)
      var next = start
      for _ in buttons.indices {
        next = (next + movement + buttons.count) % buttons.count
        if buttons[next].isEnabled { break }
      }
      guard buttons[next].isEnabled else { return }
      highlightButton(at: next)
    case 125, 126:
      let movingDown = event.keyCode == 125
      let enabled = buttons.indices.filter { buttons[$0].isEnabled }
      guard let first = enabled.first, let last = enabled.last else { return }
      let next = keyboardIndex.map {
        min(last, max(first, $0 + (movingDown ? Self.columnCount : -Self.columnCount)))
      } ?? (movingDown ? first : last)
      highlightButton(at: next)
    case 36, 49, 76:
      if let keyboardIndex { buttons[keyboardIndex].performClick(nil) }
      else { edit.performClick(nil) }
    case 53: enclosingMenuItem?.menu?.cancelTracking()
    default: super.keyDown(with: event)
    }
  }

  private func highlightButton(at index: Int) {
    keyboardIndex = index
    for (offset, button) in buttons.enumerated() { button.keyboardHighlighted = offset == index }
    showCaption(index == 0
      ? String(localized: "macLibrary.removeAllTags", defaultValue: "Remove All Tags")
      : Self.caption(for: choices[index - 1], selected: selectedIDs.contains(choices[index - 1].id)))
  }
}

private final class MacPrayerTagMenuButton: NSButton {
  private let color: NSColor?
  private let isClear: Bool
  private var hovered = false
  private var tracking: NSTrackingArea?
  var onHover: ((Bool) -> Void)?
  var onPress: (() -> Void)?
  var keyboardHighlighted = false { didSet { needsDisplay = true } }

  init(tag: MacPrayerTag?, selected: Bool) {
    color = tag.flatMap { $0.colorID == nil ? nil : NSColor($0.color) }
    isClear = tag == nil
    super.init(frame: .zero)
    title = ""
    isBordered = false
    focusRingType = .exterior
    setButtonType(.momentaryChange)
    state = selected ? .on : .off
    target = self
    action = #selector(pressed)
    identifier = .init("macLibrary.tagSwatch.\(tag?.id ?? "clear")")
    setAccessibilityRole(.radioButton)
    let label = tag.map { tag in
      String(format: selected
        ? String(localized: "macLibrary.removeTagLabel", defaultValue: "Remove “%@”")
        : String(localized: "macLibrary.addTagLabel", defaultValue: "Add “%@”"), tag.title)
    } ?? String(localized: "macLibrary.removeAllTags", defaultValue: "Remove All Tags")
    setAccessibilityLabel(label)
    toolTip = label
  }

  required init?(coder: NSCoder) { nil }
  @objc private func pressed() { onPress?() }

  override func updateTrackingAreas() {
    if let tracking { removeTrackingArea(tracking) }
    let area = NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: nil)
    addTrackingArea(area)
    tracking = area
    super.updateTrackingAreas()
  }

  override func mouseEntered(with event: NSEvent) {
    guard isEnabled else { return }
    hovered = true
    onHover?(true)
    needsDisplay = true
  }

  override func mouseExited(with event: NSEvent) {
    hovered = false
    onHover?(false)
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    let center = NSPoint(x: bounds.midX, y: bounds.midY)
    if hovered || keyboardHighlighted || isHighlighted {
      NSColor.labelColor.withAlphaComponent(0.10).setFill()
      NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).fill()
    }
    let rect = NSRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12)
    let dot = NSBezierPath(ovalIn: rect)
    if let color { color.withAlphaComponent(isEnabled ? 1 : 0.4).setFill(); dot.fill() }
    (isClear ? NSColor.tertiaryLabelColor : color == nil ? .secondaryLabelColor : NSColor.black.withAlphaComponent(0.12)).setStroke()
    dot.lineWidth = 1
    dot.stroke()
    if isClear {
      let slash = NSBezierPath()
      slash.move(to: NSPoint(x: rect.minX + 2, y: rect.maxY - 2))
      slash.line(to: NSPoint(x: rect.maxX - 2, y: rect.minY + 2))
      slash.stroke()
    }
    if state == .on {
      NSColor.labelColor.setStroke()
      let ring = NSBezierPath(ovalIn: rect.insetBy(dx: -3, dy: -3))
      ring.lineWidth = 1.5
      ring.stroke()
    }
  }

  override func drawFocusRingMask() { NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).fill() }
  override var focusRingMaskBounds: NSRect { bounds.insetBy(dx: 1, dy: 1) }
}

enum MacPrayerLibraryMenu {
  static func make(item: MacPrayerLibraryItem, tags: [MacPrayerTag], isBusy: Bool,
                   onOpen: @escaping () -> Void, onDuplicate: @escaping () -> Void,
                   onEdit: @escaping () -> Void, onRemove: @escaping () -> Void,
                   onTag: @escaping (MacPrayerTag, Bool) -> Void,
                   onClearTags: @escaping () -> Void, onEditTags: @escaping () -> Void) -> NSMenu {
    let menu = NSMenu()
    menu.autoenablesItems = false
    add(String(localized: "macLibrary.open", defaultValue: "Open"), to: menu, enabled: !isBusy, action: onOpen)
    menu.addItem(.separator())
    add(String(localized: "macLibrary.duplicate", defaultValue: "Duplicate"), to: menu, enabled: !isBusy, action: onDuplicate)
    add(String(localized: "macLibrary.prayerSettings", defaultValue: "Prayer Settings…"), to: menu, enabled: !isBusy, action: onEdit)
    menu.addItem(.separator())
    let tagItem = NSMenuItem()
    tagItem.view = MacPrayerTagMenuRow(tags: tags, selectedIDs: item.tagIDs, isEnabled: !isBusy,
      onToggle: { onTag($0, !item.tagIDs.contains($0.id)) }, onClear: onClearTags, onEdit: onEditTags)
    menu.addItem(tagItem)
    menu.addItem(.separator())
    add(item.prayer == nil
      ? String(localized: "macLibrary.removeFromLibrary", defaultValue: "Remove from Library…")
      : String(localized: "macLibrary.deletePrayer", defaultValue: "Delete Prayer…"),
      to: menu, enabled: !isBusy, action: onRemove)
    return menu
  }

  static func add(_ title: String, to menu: NSMenu, enabled: Bool, action: @escaping () -> Void) {
    let target = Action(action)
    let item = NSMenuItem(title: title, action: #selector(Action.invoke), keyEquivalent: "")
    item.target = target
    item.representedObject = target
    item.isEnabled = enabled
    menu.addItem(item)
  }

  private final class Action: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func invoke() { action() }
  }
}
#endif

#if os(macOS)
import AppKit
import SwiftUI

/// Popover content: token edits and suggested-tag selections take effect immediately.
/// Return finishes token entry and dismisses; no second Apply step is needed.
struct MacPrayerTagEditor: View {
  let tags: [MacPrayerTag]
  let selectedIDs: Set<String>
  let onSetNames: ([String]) -> Void
  let onToggle: (MacPrayerTag, Bool) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var names: [String]

  init(tags: [MacPrayerTag], selectedIDs: Set<String>, onSetNames: @escaping ([String]) -> Void,
       onToggle: @escaping (MacPrayerTag, Bool) -> Void) {
    self.tags = tags
    self.selectedIDs = selectedIDs
    self.onSetNames = onSetNames
    self.onToggle = onToggle
    _names = State(initialValue: tags.filter { selectedIDs.contains($0.id) }.map(\.title))
  }

  private var selectedNames: [String] {
    tags.filter { selectedIDs.contains($0.id) }.map(\.title)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "macLibrary.tags", defaultValue: "Tags"))
        .font(.headline)
      MacPrayerTagTokenField(
        names: $names,
        suggestions: tags.map(\.title),
        onChange: onSetNames,
        onFinish: { dismiss() }
      )
      .frame(minHeight: 27, idealHeight: 48, maxHeight: 76)
      .accessibilityIdentifier("macLibrary.tagEditor.tokens")

      if !tags.isEmpty {
        Divider()
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(tags) { tag in
              Toggle(isOn: Binding(
                // Legacy named color tags can share a title. Suggestions always target
                // their stable identity; typed-token editing remains name based.
                get: { selectedIDs.contains(tag.id) },
                set: { enabled in onToggle(tag, enabled) }
              )) {
                HStack(spacing: 8) {
                  MacPrayerTagDot(tag: tag, selected: false)
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
                  Text(tag.title).lineLimit(1)
                  Spacer(minLength: 0)
                }
              }
              .toggleStyle(.checkbox)
              .padding(.vertical, 4)
              .accessibilityIdentifier("macLibrary.tagEditor.suggestion.\(tag.id)")
            }
          }
          .padding(.trailing, 4)
        }
        .frame(maxHeight: min(CGFloat(tags.count) * 29, 220))
      }
    }
    .padding(16)
    .frame(width: 310)
    .onChange(of: selectedNames) { _, updated in names = updated }
  }
}

struct MacPrayerTagTokenField: NSViewRepresentable {
  @Binding var names: [String]
  let suggestions: [String]
  let onChange: ([String]) -> Void
  let onFinish: () -> Void

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeNSView(context: Context) -> FocusedTagTokenField {
    let field = FocusedTagTokenField(frame: .zero)
    field.delegate = context.coordinator
    field.tokenStyle = .rounded
    field.tokenizingCharacterSet = CharacterSet(charactersIn: ",\n\r")
    field.completionDelay = 0.15
    field.font = .systemFont(ofSize: NSFont.systemFontSize)
    field.placeholderString = String(localized: "macLibrary.tagName", defaultValue: "Tag Name")
    field.setAccessibilityLabel(String(localized: "macLibrary.tags", defaultValue: "Tags"))
    field.identifier = .init("macLibrary.tagEditor.tokens")
    field.objectValue = names.map { TagToken($0) }
    field.target = context.coordinator
    field.action = #selector(Coordinator.finish(_:))
    field.cell?.sendsActionOnEndEditing = false
    field.setContentHuggingPriority(.defaultLow, for: .horizontal)
    context.coordinator.publishedNames = names
    return field
  }

  func updateNSView(_ field: FocusedTagTokenField, context: Context) {
    context.coordinator.parent = self
    // Do not rewrite the field editor during typing/completion. Only a genuine external
    // assignment change (such as a suggestion toggle) replaces the token array.
    if context.coordinator.publishedNames != names {
      context.coordinator.publishedNames = names
      field.objectValue = names.map { TagToken($0) }
    }
  }

  static func dismantleNSView(_ field: FocusedTagTokenField, coordinator: Coordinator) {
    coordinator.isActive = false
    field.validateEditing()
    let values = coordinator.names(in: field, committingDraft: true)
    field.delegate = nil
    field.target = nil
    guard values != coordinator.publishedNames else { return }
    let onChange = coordinator.parent.onChange
    // A popover can disappear before the normal end-editing notification. Persist the
    // final token value after SwiftUI finishes removing this child view.
    DispatchQueue.main.async { onChange(values) }
  }

  final class TagToken: NSObject {
    let title: String
    init(_ title: String) { self.title = title }

    // AppKit validates the editing string while measuring a wrapping token field.
    // Equal names must remain equal across those conversions, otherwise each sizing
    // pass appears to change objectValue and schedules another constraints pass.
    override func isEqual(_ object: Any?) -> Bool {
      guard let other = object as? TagToken else { return false }
      return title == other.title
    }

    override var hash: Int { title.hashValue }
  }

  final class FocusedTagTokenField: NSTokenField {
    private var didRequestFocus = false

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      guard let window, !didRequestFocus else { return }
      didRequestFocus = true
      DispatchQueue.main.async { [weak self, weak window] in
        guard let self, let window, self.window === window else { return }
        window.makeFirstResponder(self)
        if let editor = self.currentEditor() as? NSTextView {
          editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        }
      }
    }
  }

  final class Coordinator: NSObject, NSTokenFieldDelegate {
    var parent: MacPrayerTagTokenField
    var publishedNames: [String] = []
    var isActive = true

    init(_ parent: MacPrayerTagTokenField) { self.parent = parent }

    func names(in field: NSTokenField, committingDraft: Bool = false) -> [String] {
      // A represented object exists only after text becomes a token. Ignoring raw draft
      // text here prevents one new tag being created for every keystroke.
      normalized((field.objectValue as? [Any] ?? []).compactMap {
        ($0 as? TagToken)?.title ?? (committingDraft ? $0 as? String : nil)
      })
    }

    private func normalized(_ values: [String]) -> [String] {
      var result: [String] = []
      for value in values {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }
        let title = parent.suggestions.first { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame } ?? trimmed
        guard !result.contains(where: { $0.localizedCaseInsensitiveCompare(title) == .orderedSame }) else { continue }
        result.append(title)
      }
      return result
    }

    private func publish(_ field: NSTokenField, committingDraft: Bool = false) {
      guard isActive else { return }
      let values = names(in: field, committingDraft: committingDraft)
      guard values != publishedNames else { return }
      publishedNames = values
      parent.names = values
      parent.onChange(values)
    }

    private func publishAfterEditing(_ field: NSTokenField) {
      DispatchQueue.main.async { [weak self, weak field] in
        guard let self, let field, self.isActive else { return }
        self.publish(field)
      }
    }

    @objc func finish(_ field: NSTokenField) {
      field.validateEditing()
      publish(field, committingDraft: true)
      parent.onFinish()
    }

    func controlTextDidChange(_ notification: Notification) {
      guard let field = notification.object as? NSTokenField else { return }
      publishAfterEditing(field)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
      guard let field = notification.object as? NSTokenField else { return }
      publish(field, committingDraft: true)
    }

    func tokenField(_ tokenField: NSTokenField, representedObjectForEditing editingString: String) -> Any? {
      // AppKit also asks this while validating a still-uncommitted draft for layout.
      // Keep that draft a value-comparable string. Only shouldAdd turns it into a
      // committed TagToken, so measuring or typing cannot create saved tags.
      normalized([editingString]).first
    }

    func tokenField(_ tokenField: NSTokenField, displayStringForRepresentedObject representedObject: Any) -> String? {
      (representedObject as? TagToken)?.title ?? (representedObject as? String)
    }

    func tokenField(_ tokenField: NSTokenField, editingStringForRepresentedObject representedObject: Any) -> String? {
      (representedObject as? TagToken)?.title ?? (representedObject as? String)
    }

    func tokenField(_ tokenField: NSTokenField, shouldAdd tokens: [Any], at index: Int) -> [Any] {
      let titles = normalized(tokens.compactMap { ($0 as? TagToken)?.title ?? ($0 as? String) })
      let existing = names(in: tokenField)
      let accepted = titles.filter { title in
        !existing.contains { $0.localizedCaseInsensitiveCompare(title) == .orderedSame }
      }.map { TagToken($0) }
      publishAfterEditing(tokenField)
      return accepted
    }

    func tokenField(_ tokenField: NSTokenField, completionsForSubstring substring: String,
                    indexOfToken tokenIndex: Int, indexOfSelectedItem selectedIndex: UnsafeMutablePointer<Int>?) -> [Any]? {
      selectedIndex?.pointee = -1
      let existing = names(in: tokenField)
      return parent.suggestions.filter { title in
        title.localizedStandardContains(substring)
          && !existing.contains { $0.localizedCaseInsensitiveCompare(title) == .orderedSame }
      }
    }
  }
}

/// The compact swatch row also works in a toolbar popover or custom SwiftUI menu content.
struct MacPrayerTagSwatches: View {
  let tags: [MacPrayerTag]
  let selectedIDs: Set<String>
  let onToggle: (MacPrayerTag) -> Void

  var body: some View {
    HStack(spacing: 4) {
      ForEach(macPrayerQuickTags(tags)) { tag in
        Button { onToggle(tag) } label: {
          MacPrayerTagDot(tag: tag, selected: selectedIDs.contains(tag.id))
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tag.title)
        .accessibilityLabel(tag.title)
        .accessibilityAddTraits(selectedIDs.contains(tag.id) ? .isSelected : [])
        .accessibilityIdentifier("macLibrary.tagSwatch.\(tag.id)")
      }
    }
  }
}

private struct MacPrayerTagDot: View {
  let tag: MacPrayerTag
  let selected: Bool

  var body: some View {
    ZStack {
      Circle().fill(tag.colorID == nil ? Color.clear : tag.color)
        .overlay { Circle().strokeBorder(tag.colorID == nil ? Color.secondary : Color.black.opacity(0.1), lineWidth: 1) }
        .frame(width: 13, height: 13)
      if selected { Circle().strokeBorder(Color.primary, lineWidth: 1.5).frame(width: 20, height: 20) }
    }
  }
}

private func macPrayerQuickTags(_ tags: [MacPrayerTag]) -> [MacPrayerTag] {
  let colored = tags.filter { $0.colorID != nil }
  return Array((colored.isEmpty ? tags : colored).prefix(7))
}

/// Install directly as NSMenuItem.view. AppKit retains native menu tracking while
/// the individual buttons provide toggle accessibility and precise color-dot hit targets.
final class MacPrayerTagMenuRow: NSView {
  private let tags: [MacPrayerTag]
  private var selectedIDs: Set<String>
  private let onToggle: (MacPrayerTag) -> Void
  private let caption = NSTextField(labelWithString: String(localized: "macLibrary.tags", defaultValue: "Tags"))
  private var buttons: [MacPrayerTagMenuButton] = []
  private var keyboardIndex = 0

  init(tags: [MacPrayerTag], selectedIDs: Set<String>, onToggle: @escaping (MacPrayerTag) -> Void) {
    self.tags = macPrayerQuickTags(tags)
    self.selectedIDs = selectedIDs
    self.onToggle = onToggle
    super.init(frame: NSRect(x: 0, y: 0, width: 248, height: 59))
    autoresizingMask = [.width]
    setAccessibilityRole(.group)
    setAccessibilityLabel(String(localized: "macLibrary.tags", defaultValue: "Tags"))
    for (index, tag) in self.tags.enumerated() {
      let button = MacPrayerTagMenuButton(tag: tag, selected: selectedIDs.contains(tag.id))
      button.frame = NSRect(x: CGFloat(12 + index * 32), y: 5, width: 28, height: 28)
      button.onHover = { [weak self] hovered in
        self?.caption.stringValue = hovered ? tag.title : String(localized: "macLibrary.tags", defaultValue: "Tags")
      }
      button.onPress = { [weak self] in self?.activate(tag) }
      addSubview(button)
      buttons.append(button)
    }
    caption.frame = NSRect(x: 14, y: 35, width: 220, height: 18)
    caption.autoresizingMask = [.width]
    caption.font = .menuFont(ofSize: NSFont.smallSystemFontSize)
    caption.textColor = .secondaryLabelColor
    caption.lineBreakMode = .byTruncatingTail
    caption.setAccessibilityElement(false)
    addSubview(caption)
  }

  required init?(coder: NSCoder) { nil }
  override var isFlipped: Bool { true }
  override var acceptsFirstResponder: Bool { true }

  private func activate(_ tag: MacPrayerTag) {
    if selectedIDs.contains(tag.id) { selectedIDs.remove(tag.id) }
    else { selectedIDs.insert(tag.id) }
    if let button = buttons.first(where: { $0.tagID == tag.id }) {
      button.state = selectedIDs.contains(tag.id) ? .on : .off
      button.needsDisplay = true
    }
    let action = onToggle
    enclosingMenuItem?.menu?.cancelTracking()
    // Apply after the menu closes, so reloading the collection cannot invalidate tracking.
    DispatchQueue.main.async { action(tag) }
  }

  override func keyDown(with event: NSEvent) {
    guard !tags.isEmpty else { return super.keyDown(with: event) }
    switch event.keyCode {
    case 123, 124:
      let movement = event.keyCode == 123 ? -1 : 1
      keyboardIndex = (keyboardIndex + movement + tags.count) % tags.count
      for (index, button) in buttons.enumerated() { button.keyboardHighlighted = index == keyboardIndex }
      caption.stringValue = tags[keyboardIndex].title
    case 36, 49, 76: activate(tags[keyboardIndex])
    case 53: enclosingMenuItem?.menu?.cancelTracking()
    default: super.keyDown(with: event)
    }
  }
}

private final class MacPrayerTagMenuButton: NSButton {
  let tagID: String
  private let tagColor: NSColor?
  private var hovered = false
  private var tracking: NSTrackingArea?
  var onHover: ((Bool) -> Void)?
  var onPress: (() -> Void)?
  var keyboardHighlighted = false { didSet { needsDisplay = true } }

  init(tag: MacPrayerTag, selected: Bool) {
    tagID = tag.id
    tagColor = tag.colorID == nil ? nil : NSColor(tag.color)
    super.init(frame: .zero)
    title = ""
    isBordered = false
    focusRingType = .exterior
    setButtonType(.pushOnPushOff)
    state = selected ? .on : .off
    target = self
    action = #selector(pressed)
    toolTip = tag.title
    identifier = .init("macLibrary.tagSwatch.\(tag.id)")
    setAccessibilityRole(.checkBox)
    setAccessibilityLabel(tag.title)
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
      NSColor.labelColor.withAlphaComponent(0.08).setFill()
      NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).fill()
    }
    let dot = NSBezierPath(ovalIn: NSRect(x: center.x - 6.5, y: center.y - 6.5, width: 13, height: 13))
    if let tagColor { tagColor.setFill(); dot.fill() }
    (tagColor == nil ? NSColor.secondaryLabelColor : NSColor.black.withAlphaComponent(0.12)).setStroke()
    dot.lineWidth = 1
    dot.stroke()
    if state == .on {
      NSColor.labelColor.setStroke()
      let ring = NSBezierPath(ovalIn: NSRect(x: center.x - 10, y: center.y - 10, width: 20, height: 20))
      ring.lineWidth = 1.5
      ring.stroke()
    }
  }

  override func drawFocusRingMask() {
    NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).fill()
  }

  override var focusRingMaskBounds: NSRect { bounds.insetBy(dx: 1, dy: 1) }
}
#endif

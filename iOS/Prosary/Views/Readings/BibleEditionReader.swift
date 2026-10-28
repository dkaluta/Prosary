import SwiftUI
import WebKit
import CoreText

nonisolated struct BibleReaderSection: Sendable {
  let book: BibleBook
  let display: BibleDisplayChapter
  var id: String { "\(book.id)/\(display.chapter.chapter)" }
}

/// The complete verified edition is laid out once. Page changes only move the viewport;
/// they do not recreate the document, decode chapters or replace text with a loading state.
struct BibleEditionReader: View {
  let edition: BibleEdition
  let sections: [BibleReaderSection]
  let script: String
  let jumpGeneration: Int
  @Binding var anchor: String?
  var onPosition: (String, Int) -> Void
  var chromeHidden = false
  var onChromeChange: (Bool?) -> Void = { _ in }
  @ObservedObject private var typography = PrayerTypographyMonitor.shared
  @ScaledMetric(relativeTo: .body) private var bodyScale = 1.0
  @State private var html = ""
  @State private var page = 1
  @State private var total = 0
  @State private var leaves = 1
  @State private var command = ""
  @State private var commandID = 0
  @State private var note: ReaderNote?
  @Environment(\.openURL) private var openURL
  private struct ReaderNote: Identifiable { let id: String; let notes: [ScriptureSourceNote] }
  private var direction: LayoutDirection { edition.readingEdition.isBibleRightToLeft ? .rightToLeft : .leftToRight }
  private var countLabel: String {
    String(format: bibleLabel("pageCount", "Pages %1$d–%2$d of %3$d"), locale: UILanguage.locale,
      page, min(page + leaves - 1, total), max(1, total))
  }

  var body: some View {
    VStack(spacing: 8) {
      ZStack {
        if !html.isEmpty {
          BibleEditionWebSurface(html: html, command: command, serial: commandID, rightToLeft: direction == .rightToLeft) { message in
            receive(message)
          }
          .accessibilityIdentifier("bible.editionText")
        }
        if total == 0 { ProgressView().accessibilityIdentifier("bible.preparingEdition") }
      }
      if !chromeHidden {
      HStack {
        Button { send(["type": "turn", "delta": -1]) } label: {
          Label(bibleLabel("previousPage", "Previous Page"), systemImage: direction == .rightToLeft ? "chevron.right" : "chevron.left")
        }.disabled(page <= 1).accessibilityIdentifier("bible.previousPage")
        Spacer()
        Text(countLabel).font(.caption).monospacedDigit().accessibilityIdentifier("bible.pageCount")
        Spacer()
        Button { send(["type": "turn", "delta": 1]) } label: {
          Label(bibleLabel("nextPage", "Next Page"), systemImage: direction == .rightToLeft ? "chevron.left" : "chevron.right")
        }.disabled(total == 0 || page + leaves > total).accessibilityIdentifier("bible.nextPage")
      }.labelStyle(.iconOnly).buttonStyle(.bordered).controlSize(pageControlSize).environment(\.layoutDirection, direction)
      if total > 1 {
        Slider(value: Binding(get: { Double(page) }, set: { send(["type": "page", "page": Int($0) - 1]) }),
          in: 1...Double(total), step: 1)
          .accessibilityLabel(countLabel).accessibilityIdentifier("bible.pageSlider")
          .environment(\.layoutDirection, direction)
      }
      }
    }
    .padding(.horizontal, 20).padding(.bottom, chromeHidden ? 0 : 8)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("bible.bookReader")
    .task(id: "\(edition.revision)|\(script)|\(typography.typefaces)|\(bodyScale)") { prepare() }
    .onChange(of: jumpGeneration) { _, _ in if let anchor { send(["type": "jump", "id": anchor]) } }
    .sheet(item: $note) { selected in
      NavigationStack {
        ScrollView { ScriptureSourceNotesView(notes: selected.notes).padding() }
          .toolbar { ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "common.done", defaultValue: "Done", bundle: UILanguage.bundle)) { note = nil }
          } }
      }.frame(minWidth: 300, minHeight: 200)
    }
  }

  private var pageControlSize: ControlSize {
    #if os(macOS)
    .small
    #else
    .large
    #endif
  }
  private func send(_ value: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: value), let string = String(data: data, encoding: .utf8) else { return }
    command = string; commandID += 1
  }
  private func receive(_ string: String) {
    guard let data = string.data(using: .utf8), let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
    switch message["type"] as? String {
    case "state":
      page = message["page"] as? Int ?? 1; total = message["total"] as? Int ?? 0; leaves = message["leaves"] as? Int ?? 1
      anchor = message["anchor"] as? String
      if let book = message["book"] as? String, let chapter = message["chapter"] as? Int { onPosition(book, chapter) }
    case "chrome": onChromeChange(message["hidden"] as? Bool)
    case "note":
      if let id = message["id"] as? String {
        for section in sections {
          if let block = section.display.blocks.first(where: { section.id + "/" + $0.id == id }) {
            note = ReaderNote(id: id, notes: block.sourceNotes); break
          }
        }
      }
    case "link": if let raw = message["url"] as? String, let url = URL(string: raw), url.scheme == "https" { openURL(url) }
    default: break
    }
  }
  private func prepare() {
    guard let templateURL = Bundle.main.url(forResource: "edition-reader", withExtension: "html"),
          let template = try? String(contentsOf: templateURL, encoding: .utf8) else { return }
    var content: [[String: Any]] = []
    for section in sections {
      let display = section.display, book = section.book
      var blocks: [[String: Any]] = []
      let usesPrinted = book.chapters.first { $0.number == display.chapter.chapter }?.canonicalReference != nil
      for block in display.blocks {
        let text = block.unit?.displayedText(script: script, edition: edition.readingEdition) ?? block.text
        let label = block.unit.map { biblePrimaryLabel($0, displayChapter: display.chapter.chapter, edition: edition.readingEdition, script: script) } ?? block.printedLabel ?? ""
        let printed = block.printedLabel ?? (usesPrinted && block.kind == .verse ? label : nil)
        blocks.append(["id": section.id + "/" + block.id, "kind": block.kind.rawValue, "text": text,
          "label": usesPrinted && block.kind == .verse ? "" : label,
          "printed": printed.map { String(format: bibleLabel("printedLabel", "Printed label: %@"), locale: UILanguage.locale, $0) } ?? "",
          "notes": !block.sourceNotes.isEmpty])
      }
      content.append(["id": section.id, "book": book.id, "bookName": book.displayedName(script: script), "chapter": display.chapter.chapter,
        "label": bibleChapterLabel(display.chapter.chapter, book: book, edition: edition.readingEdition, script: script),
        "partial": book.chapters.first { $0.number == display.chapter.chapter }?.isComplete == false,
        "introduction": book.introduction(for: display.chapter.chapter) ?? "", "blocks": blocks,
        "attribution": book.attribution ?? "", "sourceURL": book.sourceURL ?? ""])
    }
    let sample = sections.first?.display.blocks.first?.unit?.displayedText(script: script, edition: edition.readingEdition) ?? ""
    let face = PrayerTypography.scriptureFace(script: PrayerTypography.resolvedScript(text: sample, languageCode: edition.languageCode), typefaces: typography.typefaces)
    let fontURL = CTFontCopyAttribute(CTFontCreateWithName(face.name as CFString, face.size, nil), kCTFontURLAttribute) as? URL
    let fontData = fontURL.flatMap { $0.path.hasPrefix(Bundle.main.bundlePath) ? try? Data(contentsOf: $0) : nil }
    let payload: [String: Any] = ["title": edition.name, "language": edition.languageCode, "rtl": direction == .rightToLeft,
      "font": fontData?.base64EncodedString() ?? "", "fontSize": face.size * bodyScale,
      "anchor": anchor ?? sections.first?.id ?? "", "nativeTurns": true, "chromeTaps": false, "interfaceRTL": UILanguage.isRightToLeft(UILanguage.current), "sections": content,
      "attribution": edition.readingEdition.attribution, "sourceURL": edition.readingEdition.sourceURL,
      "partialLabel": bibleLabel("partial", "Only part of this chapter is available"),
      "sourceLabel": String(localized: "readings.source", defaultValue: "Text source", bundle: UILanguage.bundle, locale: UILanguage.locale),
      "noteLabel": String(localized: "scripture.sourceNote", defaultValue: "Source note", bundle: UILanguage.bundle)]
    guard let data = try? JSONSerialization.data(withJSONObject: payload), let json = String(data: data, encoding: .utf8) else { return }
    total = 0
    html = template.replacingOccurrences(of: "__PROSARY_DOCUMENT__", with: json.replacingOccurrences(of: "<", with: "\\u003c"))
  }
}

#if os(macOS)
private typealias BibleWebRepresentable = NSViewRepresentable
#else
private typealias BibleWebRepresentable = UIViewRepresentable
#endif

private struct BibleEditionWebSurface: BibleWebRepresentable {
  let html: String
  let command: String
  let serial: Int
  let rightToLeft: Bool
  var receive: (String) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
  private func create(_ context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.userContentController.add(context.coordinator, name: "reader")
    let view = WKWebView(frame: .zero, configuration: configuration)
    view.navigationDelegate = context.coordinator
    #if os(iOS)
    let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.turn(_:)))
    pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue), NSNumber(value: UITouch.TouchType.pencil.rawValue)]
    pan.cancelsTouchesInView = false
    pan.delegate = context.coordinator
    view.addGestureRecognizer(pan)
    let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.toggleChrome(_:)))
    tap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
    tap.cancelsTouchesInView = false
    tap.delegate = context.coordinator
    tap.require(toFail: pan)
    view.addGestureRecognizer(tap)
    context.coordinator.pan = pan
    #endif
    context.coordinator.web = view
    update(view, context)
    return view
  }
  private func update(_ view: WKWebView, _ context: Context) {
    let coordinator = context.coordinator; coordinator.parent = self
    if coordinator.html != html { coordinator.html = html; view.loadHTMLString(html, baseURL: nil) }
    if coordinator.serial != serial, !command.isEmpty { coordinator.serial = serial; view.evaluateJavaScript("window.ProsaryReader?.command(\(command))", completionHandler: nil) }
    #if os(iOS)
    if #available(iOS 26.0, *), let pan = coordinator.pan {
      // The containing navigation controller owns Back, but full-content Back must
      // yield to Scripture's own horizontal page gestures. Edge Back is unchanged.
      var ancestor: UIViewController? = view.next as? UIViewController
      var responder: UIResponder? = view
      while ancestor == nil, let next = responder?.next { ancestor = next as? UIViewController; responder = next }
      ancestor?.navigationController?.interactiveContentPopGestureRecognizer?.require(toFail: pan)
    }
    #endif
  }
  #if os(macOS)
  func makeNSView(context: Context) -> WKWebView { create(context) }
  func updateNSView(_ view: WKWebView, context: Context) { update(view, context) }
  #else
  func makeUIView(context: Context) -> WKWebView { create(context) }
  func updateUIView(_ view: WKWebView, context: Context) { update(view, context) }
  #endif
  final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    var parent: BibleEditionWebSurface
    weak var web: WKWebView?
    var html = ""; var serial = -1
    #if os(iOS)
    var pan: UIPanGestureRecognizer?
    @objc func toggleChrome(_ gesture: UITapGestureRecognizer) {
      guard gesture.state == .ended, let web else { return }
      let point = gesture.location(in: web)
      let query = "window.getSelection().isCollapsed && !document.elementFromPoint(\(point.x),\(point.y))?.closest('a,[data-note]')"
      web.evaluateJavaScript(query) { [weak self] value, _ in
        if value as? Bool == true { self?.parent.receive("{\"type\":\"chrome\"}") }
      }
    }
    @objc func turn(_ gesture: UIPanGestureRecognizer) {
      guard gesture.state == .ended else { return }
      let delta = gesture.translation(in: gesture.view)
      guard abs(delta.x) > 64, abs(delta.x) > abs(delta.y) * 1.5 else { return }
      let forward = (delta.x > 0) == parent.rightToLeft
      web?.evaluateJavaScript("window.ProsaryReader?.command({type:'turn',delta:\(forward ? 1 : -1)})", completionHandler: nil)
    }
    #endif
    init(parent: BibleEditionWebSurface) { self.parent = parent }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
      if message.name == "reader", let string = message.body as? String { parent.receive(string) }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
      decisionHandler(navigationAction.navigationType == .linkActivated ? .cancel : .allow)
    }
  }
}
#if os(iOS)
extension BibleEditionWebSurface.Coordinator: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
}
#endif

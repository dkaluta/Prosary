import SwiftUI
import WebKit
import CoreText

nonisolated struct BibleReaderSection: Sendable {
  let book: BibleBook
  let display: BibleDisplayChapter
  var id: String { "\(book.id)/\(display.chapter.chapter)" }
}

/// One verified book is laid out at a time. Page changes inside it only move the viewport;
/// turning past its first or last page asks the host for the neighbouring book.
struct BibleEditionReader: View {
  let edition: BibleEdition
  let sections: [BibleReaderSection]
  let script: String
  let jumpGeneration: Int
  @Binding var anchor: String?
  var onPosition: (String, Int) -> Void
  var chromeHidden = false
  var onChromeChange: (Bool?) -> Void = { _ in }
  var hasPrevious = false
  var hasNext = false
  var onBoundary: (Int) -> Void = { _ in }
  /// The page count opens the book's chapters, the same choices as the toolbar's chapter menu.
  var chapterChoices: [(number: Int, label: String)] = []
  var onChapter: (Int) -> Void = { _ in }
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
        }.disabled(total == 0 || page <= 1 && !hasPrevious).accessibilityIdentifier("bible.previousPage")
        Spacer()
        Menu {
          ForEach(chapterChoices, id: \.number) { choice in
            Button(choice.label) { onChapter(choice.number) }
          }
        } label: {
          Text(countLabel).font(.caption).monospacedDigit()
        }
        .menuStyle(.button).buttonStyle(.borderless)
        .disabled(chapterChoices.isEmpty)
        .accessibilityHint(bibleLabel("chooseChapter", "Choose a chapter"))
        .accessibilityIdentifier("bible.pageCount")
        Spacer()
        Button { send(["type": "turn", "delta": 1]) } label: {
          Label(bibleLabel("nextPage", "Next Page"), systemImage: direction == .rightToLeft ? "chevron.left" : "chevron.right")
        }.disabled(total == 0 || page + leaves > total && !hasNext).accessibilityIdentifier("bible.nextPage")
      }.labelStyle(.iconOnly).buttonStyle(.bordered).controlSize(pageControlSize).environment(\.layoutDirection, direction)
      }
    }
    .padding(.horizontal, 20).padding(.bottom, chromeHidden ? 0 : 8)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("bible.bookReader")
    .task(id: "\(edition.revision)|\(sections.first?.book.id ?? "")|\(script)|\(typography.typefaces)|\(bodyScale)") { prepare() }
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
    case "boundary": if let delta = message["delta"] as? Int { onBoundary(delta) }
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
      "anchor": anchor ?? sections.first?.id ?? "", "hasPrevious": hasPrevious, "hasNext": hasNext, "nativeTurns": true, "chromeTaps": false, "interfaceRTL": UILanguage.isRightToLeft(UILanguage.current), "sections": content,
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
private typealias BibleWebRepresentable = UIViewControllerRepresentable
#endif

private struct BibleEditionWebSurface: BibleWebRepresentable {
  let html: String
  let command: String
  let serial: Int
  let rightToLeft: Bool
  var receive: (String) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
  private func configuration(_ context: Context) -> WKWebViewConfiguration {
    let configuration = WKWebViewConfiguration()
    configuration.userContentController.add(context.coordinator, name: "reader")
    return configuration
  }
  private func update(_ context: Context) {
    let coordinator = context.coordinator; coordinator.parent = self
    #if os(iOS)
    coordinator.curl?.rightToLeft = rightToLeft
    coordinator.curl?.curlEnabled = !context.environment.accessibilityReduceMotion
    #endif
    if coordinator.html != html { coordinator.html = html; coordinator.loaded = false; coordinator.load(html) }
    if coordinator.serial != serial, !command.isEmpty { coordinator.serial = serial; coordinator.run(command) }
  }
  #if os(macOS)
  func makeNSView(context: Context) -> WKWebView {
    let view = WKWebView(frame: .zero, configuration: configuration(context))
    view.navigationDelegate = context.coordinator
    context.coordinator.web = view
    update(context)
    return view
  }
  func updateNSView(_ view: WKWebView, context: Context) { update(context) }
  #else
  func makeUIViewController(context: Context) -> BibleEditionCurlController {
    let controller = BibleEditionCurlController(configuration: configuration(context))
    let coordinator = context.coordinator
    controller.web.navigationDelegate = coordinator
    controller.documentTurn = { [weak coordinator] delta in coordinator?.evaluate("{type:'turn',delta:\(delta)}") }
    controller.chromeTap = { [weak coordinator] in coordinator?.parent.receive("{\"type\":\"chrome\"}") }
    coordinator.web = controller.web
    coordinator.curl = controller
    controller.loadViewIfNeeded()
    update(context)
    return controller
  }
  func updateUIViewController(_ controller: BibleEditionCurlController, context: Context) { update(context) }
  #endif
  final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    var parent: BibleEditionWebSurface
    weak var web: WKWebView?
    #if os(iOS)
    weak var curl: BibleEditionCurlController?
    #endif
    var html = ""; var serial = -1
    /// A command sent while a new document is still loading would reach the old page or none.
    /// Keep the latest one (a book or verse jump) for the reader's own first layout instead.
    var loaded = false; var pending: String?; var navigation: WKNavigation?
    func load(_ html: String) {
      #if os(iOS)
      navigation = curl?.load(html)
      #else
      navigation = web?.loadHTMLString(html, baseURL: nil)
      #endif
    }
    func run(_ command: String) {
      guard loaded else { pending = command; return }
      #if os(iOS)
      // Page buttons curl the leaf when the neighbouring spread is ready.
      if let curl, let data = command.data(using: .utf8),
         let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         value["type"] as? String == "turn", let delta = value["delta"] as? Int {
        curl.turn(delta); return
      }
      #endif
      evaluate(command)
    }
    func evaluate(_ command: String) {
      web?.evaluateJavaScript("window.ProsaryReader?.command(\(command))", completionHandler: nil)
    }
    init(parent: BibleEditionWebSurface) { self.parent = parent }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
      guard message.name == "reader", let string = message.body as? String else { return }
      #if os(iOS)
      if let curl, let data = string.data(using: .utf8),
         let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any], value["type"] as? String == "state" {
        curl.didReceiveState(page: value["page"] as? Int ?? 1, total: value["total"] as? Int ?? 0, leaves: value["leaves"] as? Int ?? 1)
      }
      #endif
      parent.receive(string)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      guard navigation == nil || navigation === self.navigation else { return }
      loaded = true
      if let command = pending { pending = nil; run(command) }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
      decisionHandler(navigationAction.navigationType == .linkActivated ? .cancel : .allow)
    }
  }
}

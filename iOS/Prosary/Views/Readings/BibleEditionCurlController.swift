#if os(iOS)
import UIKit
import WebKit

/// UIKit's native page curl over the shared book document.
///
/// The live web view stays on top while the reader is still, so selection, notes and links
/// keep working. Underneath, a `UIPageViewController` holds pictures of the current spread
/// and its neighbours; a second, hidden copy of the same document renders those neighbours.
/// While a leaf curls the live view steps aside, then moves to the page the curl revealed.
@MainActor
final class BibleEditionCurlController: UIViewController, UIPageViewControllerDataSource,
  UIPageViewControllerDelegate, UIGestureRecognizerDelegate {
  let web: WKWebView
  private let shadow: WKWebView
  private var pages: UIPageViewController?
  private var pagePans: [UIGestureRecognizer] = []
  /// Scripture direction: a right-to-left book turns forward from its left edge.
  var rightToLeft = false
  /// Reduce Motion keeps plain page turns.
  var curlEnabled = true { didSet { if curlEnabled != oldValue { applyCurlAvailability() } } }
  /// A turn the curl cannot show (no neighbour picture yet, or a book boundary) runs in the document.
  var documentTurn: (Int) -> Void = { _ in }
  var chromeTap: () -> Void = {}

  private var page = 1, total = 0, leaves = 1
  private var images: [Int: UIImage] = [:]
  private var generation = 0
  private var curling = false
  private var curledDuringGesture = false
  private var refreshPending = false
  private var turnPan: UIPanGestureRecognizer?

  init(configuration: WKWebViewConfiguration) {
    web = WKWebView(frame: .zero, configuration: configuration)
    // The neighbour renderer posts nothing to the host: it has no message handler.
    shadow = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("Use init(configuration:)") }

  override func viewDidLoad() {
    super.viewDidLoad()
    for view in [shadow, web] {
      view.isOpaque = false
      view.backgroundColor = .clear
      view.scrollView.backgroundColor = .clear
      view.scrollView.isScrollEnabled = false
    }
    shadow.isUserInteractionEnabled = false
    shadow.accessibilityElementsHidden = true
    view.addSubview(shadow)
    installPages(leaves: 1)
    view.addSubview(web)

    let pan = UIPanGestureRecognizer(target: self, action: #selector(turnGesture(_:)))
    pan.allowedTouchTypes = [UITouch.TouchType.direct, .pencil].map { NSNumber(value: $0.rawValue) }
    pan.cancelsTouchesInView = false
    pan.delegate = self
    view.addGestureRecognizer(pan)
    turnPan = pan
    let tap = UITapGestureRecognizer(target: self, action: #selector(tapGesture(_:)))
    tap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
    tap.cancelsTouchesInView = false
    tap.delegate = self
    tap.require(toFail: pan)
    web.addGestureRecognizer(tap)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    shadow.frame = view.bounds
    web.frame = view.bounds
    pages?.view.frame = view.bounds
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // The containing navigation controller owns Back, but full-content Back must yield
    // to Scripture's own horizontal page gestures. Edge Back is unchanged.
    if #available(iOS 26.0, *), let pop = navigationController?.interactiveContentPopGestureRecognizer {
      if let turnPan { pop.require(toFail: turnPan) }
      for pan in pagePans { pop.require(toFail: pan) }
    }
  }

  // MARK: Document

  @discardableResult func load(_ html: String) -> WKNavigation? {
    generation += 1
    images = [:]; total = 0
    web.alpha = 1
    let navigation = web.loadHTMLString(html, baseURL: nil)
    shadow.loadHTMLString(html, baseURL: nil)
    return navigation
  }

  /// Every layout, jump and turn in the live document reports its position here.
  func didReceiveState(page: Int, total: Int, leaves: Int) {
    let layoutChanged = total != self.total || leaves != self.leaves
    self.page = page; self.total = total
    if leaves != self.leaves { self.leaves = leaves; installPages(leaves: leaves) }
    if layoutChanged { generation += 1; images = [:] }
    scheduleRefresh()
  }

  private var spread: Int { max(0, page - 1) / max(1, leaves) }
  private var spreadCount: Int { total == 0 ? 0 : (total + leaves - 1) / leaves }

  // MARK: Pictures

  private func scheduleRefresh() {
    guard !refreshPending else { return }
    refreshPending = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
      guard let self else { return }
      self.refreshPending = false
      guard !self.curling else { return }
      Task { await self.refresh() }
    }
  }

  private func refresh() async {
    let token = generation, current = spread
    guard total > 0, let picture = await snapshot(web), token == generation, current == spread, !curling else { return }
    images = images.filter { abs($0.key - current) <= 1 }
    images[current] = picture
    showCurrent(animated: false)
    guard curlEnabled else { return }
    for neighbour in [current + 1, current - 1] where (0..<spreadCount).contains(neighbour) && images[neighbour] == nil {
      guard let picture = await render(spread: neighbour, token: token), token == generation else { return }
      images[neighbour] = picture
    }
  }

  /// Render a neighbouring spread in the hidden copy, only when its pagination matches.
  private func render(spread target: Int, token: Int) async -> UIImage? {
    for _ in 0..<20 {
      guard token == generation else { return nil }
      let script = "(() => { const r = window.ProsaryReader; if (!r) return null; const p = r.position(); "
        + "if (!p.total) return null; r.command({type:'page', page:\(target * leaves)}); return JSON.stringify(r.position()); })()"
      if let raw = try? await shadow.evaluateJavaScript(script) as? String,
         let data = raw.data(using: .utf8),
         let position = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        guard position["total"] as? Int == total, position["leaves"] as? Int == leaves,
              position["page"] as? Int == target * leaves + 1 else { return nil }
        return await snapshot(shadow)
      }
      try? await Task.sleep(for: .milliseconds(100))
    }
    return nil
  }

  private func snapshot(_ source: WKWebView) async -> UIImage? {
    guard source.bounds.width > 0, source.bounds.height > 0 else { return nil }
    let configuration = WKSnapshotConfiguration()
    configuration.afterScreenUpdates = true
    return try? await source.takeSnapshot(configuration: configuration)
  }

  // MARK: Leaves

  private func installPages(leaves: Int) {
    if let old = pages {
      old.willMove(toParent: nil); old.view.removeFromSuperview(); old.removeFromParent()
      for pan in pagePans { pan.view?.removeGestureRecognizer(pan) }
      pagePans = []
    }
    let controller = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal,
      options: [.spineLocation: (leaves == 2 ? UIPageViewController.SpineLocation.mid : .min).rawValue])
    controller.isDoubleSided = leaves == 2
    controller.dataSource = self
    controller.delegate = self
    // UIKit's before/after describe physical left/right; source order is mapped explicitly.
    controller.view.semanticContentAttribute = .forceLeftToRight
    controller.view.backgroundColor = .clear
    controller.view.isAccessibilityElement = false
    controller.view.accessibilityElementsHidden = true
    addChild(controller)
    view.insertSubview(controller.view, aboveSubview: shadow)
    controller.view.frame = view.bounds
    controller.didMove(toParent: self)
    // The live document sits on top, so the curl's drags are taken from the whole reader.
    // Ordinary taps belong to Scripture and the reader chrome.
    for gesture in controller.gestureRecognizers {
      if gesture is UITapGestureRecognizer { gesture.isEnabled = false; continue }
      // UIKit stays the delegate of its own curl recognizers; it decides where a curl may start.
      gesture.allowedTouchTypes = [UITouch.TouchType.direct, .pencil].map { NSNumber(value: $0.rawValue) }
      view.addGestureRecognizer(gesture)
      pagePans.append(gesture)
    }
    pages = controller
    applyCurlAvailability()
  }

  /// A curl can only start from a pictured spread; UIKit raises if it has no leaves to turn.
  private func applyCurlAvailability() {
    let ready = curlEnabled && !(pages?.viewControllers ?? []).isEmpty
    for pan in pagePans { pan.isEnabled = ready }
    if !curlEnabled { web.alpha = 1 }
  }

  private func leaves(for target: Int) -> [UIViewController]? {
    guard let image = images[target] else { return nil }
    if leaves == 1 { return [Leaf(spread: target, side: 0, image: image, halves: 1)] }
    return [Leaf(spread: target, side: 0, image: image, halves: 2), Leaf(spread: target, side: 1, image: image, halves: 2)]
  }

  private func showCurrent(animated: Bool) {
    guard let controllers = leaves(for: spread) else { return }
    pages?.setViewControllers(controllers, direction: .forward, animated: animated)
    applyCurlAvailability()
  }

  /// The physically next spread to the right of `target`.
  private func physicalNext(_ target: Int) -> Int { rightToLeft ? target - 1 : target + 1 }

  func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
    guard curlEnabled, let leaf = viewController as? Leaf else { return nil }
    if leaves == 2, leaf.side == 1 { return leaves(for: leaf.spread)?.first }
    let target = rightToLeft ? leaf.spread + 1 : leaf.spread - 1
    return leaves(for: target)?.last
  }

  func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
    guard curlEnabled, let leaf = viewController as? Leaf else { return nil }
    if leaves == 2, leaf.side == 0 { return leaves(for: leaf.spread)?.last }
    return leaves(for: physicalNext(leaf.spread))?.first
  }

  func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
    curling = true
    curledDuringGesture = true
    web.alpha = 0
  }

  func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                          previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
    let shown = pageViewController.viewControllers?.compactMap { ($0 as? Leaf)?.spread }.first
    settle(on: completed ? shown : nil)
  }

  /// After a curl, move the live document to the revealed spread and show it once painted.
  private func settle(on target: Int?) {
    guard let target, target != spread else { reveal(); return }
    web.evaluateJavaScript("window.ProsaryReader?.command({type:'page',page:\(target * leaves)})") { [weak self] _, _ in
      Task { @MainActor in
        guard let self else { return }
        // Wait for the moved document to paint before it covers the curl's picture.
        _ = await self.snapshot(self.web)
        self.reveal()
      }
    }
  }

  private func reveal() {
    curling = false
    web.alpha = 1
    scheduleRefresh()
  }

  // MARK: Turns

  /// Previous Page and Next Page. A curl is shown when the neighbour is already pictured;
  /// otherwise the document turns, which also carries a turn across a book boundary.
  func turn(_ delta: Int) {
    let target = spread + (delta > 0 ? 1 : -1)
    guard curlEnabled, !curling, let pages, images[spread] != nil, let controllers = leaves(for: target) else {
      documentTurn(delta); return
    }
    curling = true
    web.alpha = 0
    let forward = (target > spread) != rightToLeft
    pages.setViewControllers(controllers, direction: forward ? .forward : .reverse, animated: true) { [weak self] finished in
      self?.settle(on: finished ? target : nil)
    }
  }

  @objc private func turnGesture(_ gesture: UIPanGestureRecognizer) {
    if gesture.state == .began { curledDuringGesture = false }
    guard gesture.state == .ended, !curledDuringGesture, !curling else { return }
    let delta = gesture.translation(in: gesture.view)
    guard abs(delta.x) > 64, abs(delta.x) > abs(delta.y) * 1.5 else { return }
    // No curl began (no neighbour picture, Reduce Motion, or a book's first or last page).
    documentTurn((delta.x > 0) == rightToLeft ? 1 : -1)
  }

  @objc private func tapGesture(_ gesture: UITapGestureRecognizer) {
    guard gesture.state == .ended, !curling else { return }
    let point = gesture.location(in: web)
    let query = "window.getSelection().isCollapsed && !document.elementFromPoint(\(point.x),\(point.y))?.closest('a,[data-note]')"
    web.evaluateJavaScript(query) { [weak self] value, _ in
      if value as? Bool == true { self?.chromeTap() }
    }
  }

  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                         shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }

  /// One picture of a spread, or one half of it on a two-page spread.
  private final class Leaf: UIViewController {
    let spread: Int
    let side: Int
    private let image: UIImage
    private let halves: Int

    init(spread: Int, side: Int, image: UIImage, halves: Int) {
      self.spread = spread; self.side = side; self.image = image; self.halves = halves
      super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(spread:side:image:halves:)") }

    override func viewDidLoad() {
      super.viewDidLoad()
      view.backgroundColor = .systemBackground
      view.clipsToBounds = true
      let picture = UIImageView(image: image)
      picture.contentMode = .scaleToFill
      view.addSubview(picture)
      picture.tag = 1
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      guard let picture = view.viewWithTag(1) else { return }
      // Each half shows its own side of the spread picture.
      let width = view.bounds.width * CGFloat(halves)
      picture.frame = CGRect(x: -CGFloat(side) * view.bounds.width, y: 0, width: width, height: view.bounds.height)
    }
  }
}
#endif

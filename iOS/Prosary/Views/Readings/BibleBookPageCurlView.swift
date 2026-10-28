#if os(iOS)
import SwiftUI
import UIKit

/// UIKit supplies the curl, paper backs and interactive completion/cancellation. Selection
/// names a spread in source order; the physical order is reversed for RTL scripture.
struct BibleBookPageCurlView<Leaf: View>: UIViewControllerRepresentable {
  let pageCount: Int
  @Binding var selection: Int
  let isRightToLeft: Bool
  let revision: AnyHashable
  let leaves: Int
  let previousSection: (() -> Void)?
  let nextSection: (() -> Void)?
  let leaf: (Int, Int, Bool) -> Leaf

  init(pageCount: Int, selection: Binding<Int>, isRightToLeft: Bool, revision: AnyHashable, leaves: Int = 2,
       previousSection: (() -> Void)? = nil, nextSection: (() -> Void)? = nil,
       @ViewBuilder leaf: @escaping (Int, Int, Bool) -> Leaf) {
    self.pageCount = pageCount
    _selection = selection
    self.isRightToLeft = isRightToLeft
    self.revision = revision
    self.leaves = leaves
    self.previousSection = previousSection
    self.nextSection = nextSection
    self.leaf = leaf
  }

  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

  func makeUIViewController(context: Context) -> UIPageViewController {
    let controller = BibleBookPageController(transitionStyle: .pageCurl,
      navigationOrientation: .horizontal,
      options: [.spineLocation: (leaves == 2 ? UIPageViewController.SpineLocation.mid : .min).rawValue])
    controller.isDoubleSided = leaves == 2
    controller.dataSource = context.coordinator
    controller.delegate = context.coordinator
    controller.view.backgroundColor = .systemBackground
    // UIKit's before/after callbacks describe physical left/right. Keep that coordinate
    // system fixed and reverse the source indices explicitly, without mirroring twice.
    controller.view.semanticContentAttribute = .forceLeftToRight
    context.coordinator.environment = context.environment
    context.coordinator.synchronize(controller, animated: false)
    // Ordinary taps and long presses belong to selectable scripture. Dragging a leaf still
    // uses UIKit's native curl recognizers; the explicit page buttons also remain available.
    for gesture in controller.gestureRecognizers where gesture is UITapGestureRecognizer {
      gesture.isEnabled = false
    }
    for gesture in controller.gestureRecognizers where gesture is UIPanGestureRecognizer {
      // A mouse drag selects Scripture; touch and Pencil retain native page curls.
      gesture.allowedTouchTypes = [UITouch.TouchType.direct, .pencil].map { NSNumber(value: $0.rawValue) }
    }
    let boundary = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.boundaryTurn(_:)))
    boundary.allowedTouchTypes = [UITouch.TouchType.direct, .pencil].map { NSNumber(value: $0.rawValue) }
    boundary.cancelsTouchesInView = false
    boundary.delegate = context.coordinator
    controller.view.addGestureRecognizer(boundary)
    controller.pagePan = boundary
    return controller
  }

  func updateUIViewController(_ controller: UIPageViewController, context: Context) {
    context.coordinator.parent = self
    context.coordinator.environment = context.environment
    context.coordinator.synchronize(controller,
      animated: !context.environment.accessibilityReduceMotion && !context.transaction.disablesAnimations)
  }

  static func dismantleUIViewController(_ controller: UIPageViewController, coordinator: Coordinator) {
    coordinator.isDetached = true
    controller.delegate = nil
    controller.dataSource = nil
  }

  @MainActor
  final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate {
    var parent: BibleBookPageCurlView
    var environment = EnvironmentValues()
    var isDetached = false
    private var controllers: [Int: BibleBookCurlLeafController] = [:]
    private var isTransitioning = false
    private var renderedRevision: AnyHashable?
    private var renderedRightToLeft: Bool?
    private var gestureRevision: AnyHashable?
    private var boundaryStart = 0

    init(parent: BibleBookPageCurlView) { self.parent = parent }

    private var paddedPageCount: Int { parent.leaves == 2 ? max(2, ((max(0, parent.pageCount) + 1) / 2) * 2) : max(1, parent.pageCount) }
    private var desiredSpread: Int { min(max(0, parent.selection), paddedPageCount / parent.leaves - 1) }

    private func rootView(number: Int, activeSpread: Int) -> AnyView {
      AnyView(parent.leaf(number, number % parent.leaves, number / parent.leaves == activeSpread)
        .environment(\.self, environment)
        .environment(\.layoutDirection, parent.isRightToLeft ? .rightToLeft : .leftToRight))
    }

    private func controller(number: Int, activeSpread: Int) -> BibleBookCurlLeafController? {
      guard (0..<paddedPageCount).contains(number) else { return nil }
      if let existing = controllers[number] { return existing }
      let controller = BibleBookCurlLeafController(pageNumber: number,
        rootView: rootView(number: number, activeSpread: activeSpread))
      controllers[number] = controller
      return controller
    }

    private func refreshContent(activeSpread: Int) {
      for (number, controller) in controllers {
        controller.rootView = rootView(number: number, activeSpread: activeSpread)
      }
    }

    private func visibleSpread(in controller: UIPageViewController) -> Int? {
      let numbers = controller.viewControllers?.compactMap { ($0 as? BibleBookCurlLeafController)?.pageNumber }
      return numbers?.min().map { $0 / parent.leaves }
    }

    func synchronize(_ controller: UIPageViewController, animated: Bool) {
      guard !isDetached, !isTransitioning else { return }
      let spread = desiredSpread
      let oldSpread = visibleSpread(in: controller)
      let changed = renderedRevision != parent.revision || renderedRightToLeft != parent.isRightToLeft
      refreshContent(activeSpread: spread)
      let orderedNumbers = parent.leaves == 1 ? [spread] : parent.isRightToLeft ? [spread * 2 + 1, spread * 2] : [spread * 2, spread * 2 + 1]
      let currentNumbers = controller.viewControllers?.compactMap { ($0 as? BibleBookCurlLeafController)?.pageNumber }
      guard changed || currentNumbers != orderedNumbers else { return }
      let leaves = orderedNumbers.compactMap { self.controller(number: $0, activeSpread: spread) }
      // A center spine always requires two controllers, including a blank final leaf when
      // the chapter has an odd page count.
      guard leaves.count == parent.leaves else { return }
      let advancing = spread > (oldSpread ?? spread)
      let direction: UIPageViewController.NavigationDirection = advancing != parent.isRightToLeft ? .forward : .reverse
      let shouldAnimate = animated && !changed && oldSpread != nil && oldSpread != spread
      renderedRevision = parent.revision
      renderedRightToLeft = parent.isRightToLeft
      isTransitioning = shouldAnimate
      controller.setViewControllers(leaves, direction: direction, animated: shouldAnimate) { [weak self, weak controller] _ in
        guard let self, let controller, !self.isDetached else { return }
        self.isTransitioning = false
        // SwiftUI can deliver another page, typography or size update during the curl.
        // Apply the latest request after UIKit has finished its current transition.
        self.synchronize(controller, animated: false)
      }
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
      guard let number = (viewController as? BibleBookCurlLeafController)?.pageNumber else { return nil }
      return controller(number: number + (parent.isRightToLeft ? 1 : -1), activeSpread: desiredSpread)
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
      guard let number = (viewController as? BibleBookCurlLeafController)?.pageNumber else { return nil }
      return controller(number: number + (parent.isRightToLeft ? -1 : 1), activeSpread: desiredSpread)
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            willTransitionTo pendingViewControllers: [UIViewController]) {
      isTransitioning = true
      gestureRevision = renderedRevision
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
      isTransitioning = false
      // A size/style reflow during a gesture invalidates those old leaf indices. Keep the
      // source anchor and render its new containing spread rather than publishing stale pages.
      guard completed, gestureRevision == parent.revision,
            renderedRightToLeft == parent.isRightToLeft,
            let spread = visibleSpread(in: pageViewController) else {
        synchronize(pageViewController, animated: false)
        return
      }
      parent.selection = spread
      refreshContent(activeSpread: spread)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }

    @objc func boundaryTurn(_ gesture: UIPanGestureRecognizer) {
      if gesture.state == .began { boundaryStart = desiredSpread }
      guard gesture.state == .ended, !isDetached else { return }
      let translation = gesture.translation(in: gesture.view)
      guard abs(translation.x) > 70, abs(translation.x) > abs(translation.y) * 1.5 else { return }
      let forward = parent.isRightToLeft ? translation.x > 0 : translation.x < 0
      if forward, boundaryStart == paddedPageCount / parent.leaves - 1 { parent.nextSection?() }
      else if !forward, boundaryStart == 0 { parent.previousSection?() }
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            spineLocationFor orientation: UIInterfaceOrientation) -> UIPageViewController.SpineLocation {
      pageViewController.isDoubleSided = parent.leaves == 2
      return parent.leaves == 2 ? .mid : .min
    }
  }
}

/// Page turns own horizontal drags inside Scripture. The navigation controller's
/// screen-edge Back gesture remains available, alongside the native Back button.
@MainActor
private final class BibleBookPageController: UIPageViewController {
  var pagePan: UIPanGestureRecognizer?

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if #available(iOS 26.0, *), let pagePan {
      navigationController?.interactiveContentPopGestureRecognizer?.require(toFail: pagePan)
    }
  }
}

@MainActor
private final class BibleBookCurlLeafController: UIHostingController<AnyView> {
  let pageNumber: Int

  init(pageNumber: Int, rootView: AnyView) {
    self.pageNumber = pageNumber
    super.init(rootView: rootView)
    view.backgroundColor = .systemBackground
    view.isOpaque = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("Use init(pageNumber:rootView:)") }
}
#endif

//
//  BeadModelsTests.swift
//  ProsaryTests
//

import XCTest
@testable import Prosary

final class BeadModelsTests: XCTestCase {
  /// Synthesizes a decade-based session with no `Mystery` at all — the shape every one of
  /// Franciscan Crown/Seven Sorrows/Divine Mercy Chaplet's steps has (unlike the Rosary, which
  /// always sets `mystery`). Before the bead-track generalization, `BeadLayout.build` silently
  /// produced zero `groupColumns` for a session like this instead of one ungrouped column.
  private func makeMysteryLessDecadeSteps(decadeCount: Int) -> [RosaryStep] {
    var steps: [RosaryStep] = [RosaryStep(title: "Opening", subtitle: nil, body: "")]
    for d in 0..<decadeCount {
      steps.append(RosaryStep(title: "Our Father", subtitle: nil, body: "", decadeIndex: d))
      for h in 1...10 {
        steps.append(RosaryStep(title: "Hail Mary", subtitle: nil, body: "", decadeIndex: d, hailMaryIndexInDecade: h))
      }
    }
    return steps
  }

  func testMysteryLessDecadeStepsProduceOneUngroupedColumn() {
    let steps = makeMysteryLessDecadeSteps(decadeCount: 3)
    let layout = BeadLayout.build(steps: steps, currentIndex: steps.count / 2, hasClosingCross: false)

    XCTAssertEqual(layout.groupColumns.count, 1)
    XCTAssertNil(layout.groupColumns[0].group)
    XCTAssertEqual(layout.groupColumns[0].beads.count, 3)
  }

  func testMysteryLessDecadeStepsKeepDecadesInOrder() {
    let steps = makeMysteryLessDecadeSteps(decadeCount: 3)
    // Land squarely inside the 2nd decade (index 1)'s Hail Marys.
    let currentIndex = steps.firstIndex { $0.decadeIndex == 1 && $0.hailMaryIndexInDecade == 5 }!
    let layout = BeadLayout.build(steps: steps, currentIndex: currentIndex, hasClosingCross: false)

    let beads = layout.groupColumns[0].beads
    XCTAssertEqual(beads.count, 3)
    XCTAssertEqual(beads[0].state, .completed)
    XCTAssertEqual(beads[1].state, .current)
    XCTAssertEqual(beads[2].state, .upcoming)
  }

  func testMysteryLessDecadeStepsStillPopulateBottomBeads() {
    let steps = makeMysteryLessDecadeSteps(decadeCount: 1)
    let currentIndex = steps.firstIndex { $0.hailMaryIndexInDecade == 4 }!
    let layout = BeadLayout.build(steps: steps, currentIndex: currentIndex, hasClosingCross: false)

    XCTAssertTrue(layout.showBottomBeads)
    XCTAssertEqual(layout.bottomBeads.count, 10)
    XCTAssertEqual(layout.bottomBeads[3].state, .current)
  }

  /// The narrow layout wraps major beads per mystery group — an ungrouped 7-decade session
  /// (Franciscan Crown, Seven Sorrows) must keep every major bead on ONE row (cross + 7
  /// decades), never an arbitrary 5+2 split.
  func testMysteryLessSevenDecadeSessionKeepsMajorBeadsOnOneRow() {
    let steps = makeMysteryLessDecadeSteps(decadeCount: 7)
    let layout = BeadLayout.build(steps: steps, currentIndex: 0, hasClosingCross: false)

    XCTAssertEqual(layout.topRows.count, 1)
    XCTAssertEqual(layout.topRows[0].count, 8)  // opening cross + 7 decade beads
    XCTAssertEqual(layout.topRows[0].filter { $0.kind == .decade }.count, 7)
  }

  /// The real shipped Franciscan Crown (7 decades + antiphon + closing cross) — the full major
  /// strip is one row of 10.
  @MainActor
  func testFranciscanCrownMajorBeadsAreOneRow() {
    let steps = PrayerEngine().buildSteps(for: Prayer(
      kind: .custom, languageCode: "en", customDevotionId: "franciscanCrown"))
    let layout = BeadLayout.build(steps: steps, currentIndex: 0, hasClosingCross: true)

    XCTAssertEqual(layout.topRows.count, 1)
    XCTAssertEqual(layout.topRows[0].count, 10)  // cross + 7 joys + antiphon + closing cross
  }

  /// A multi-group Rosary still wraps one row per mystery group (the rows-of-5 the physical
  /// rosary loops suggest), with the antiphon/closing cross on the last row.
  func testTwentyMysterySessionWrapsOneRowPerGroup() {
    let steps = PrayerEngine().buildSteps(for: Prayer(rosary: RosaryOptions(mysterySelectionMode: .twentyMystery)))
    let layout = BeadLayout.build(steps: steps, currentIndex: 0, hasClosingCross: true)

    XCTAssertEqual(layout.topRows.count, 4)
    XCTAssertEqual(layout.topRows[0].filter { $0.kind == .decade }.count, 5)
    XCTAssertEqual(layout.topRows[3].filter { $0.kind == .decade }.count, 5)
    XCTAssertEqual(layout.topRows[0].first?.kind, .cross)
    XCTAssertEqual(layout.topRows[3].last?.kind, .cross)
  }

  /// Sanity check that the existing Rosary-shaped (mystery-grouped) behavior is unaffected by
  /// the generalization — still one column per distinct `MysteryGroup` in session order.
  func testMysteryGroupedStepsStillGroupByMysteryGroup() {
    let steps = PrayerEngine().buildSteps(for: Prayer(rosary: RosaryOptions(mysterySelectionMode: .twentyMystery)))
    let layout = BeadLayout.build(steps: steps, currentIndex: steps.count / 2, hasClosingCross: true)

    XCTAssertEqual(layout.groupColumns.count, 4)
    XCTAssertEqual(layout.groupColumns.map(\.group), [.joyful, .luminous, .sorrowful, .glorious])
  }

  /// Presenter mode collapses each decade's 10 Hail Marys + Glory Be into one step carrying
  /// `hailMaryIndexInDecade: 10` specifically so the bead track still shows the traditional
  /// 10-bead-per-decade look (beads 1-9 completed, bead 10 current) instead of collapsing to a
  /// single bead — see PrayerEngine.buildRosarySteps' presenter-mode branch. This is the crux of
  /// that design decision, even though BeadLayout itself needed no code changes to support it.
  func testPresenterModeStepStillShowsTenTraditionalBottomBeads() {
    let steps = PrayerEngine().buildSteps(for: Prayer(rosary: RosaryOptions(presenterMode: true)))
    let currentIndex = steps.firstIndex { $0.title == "Hail Mary & Glory Be" && $0.decadeIndex == 0 }!
    let layout = BeadLayout.build(steps: steps, currentIndex: currentIndex, hasClosingCross: true)

    XCTAssertTrue(layout.showBottomBeads)
    XCTAssertEqual(layout.bottomBeads.count, 10)
    for i in 0..<9 {
      XCTAssertEqual(layout.bottomBeads[i].state, .completed)
    }
    XCTAssertEqual(layout.bottomBeads[9].state, .current)
  }
}

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

  /// Sanity check that the existing Rosary-shaped (mystery-grouped) behavior is unaffected by
  /// the generalization — still one column per distinct `MysteryGroup` in session order.
  func testMysteryGroupedStepsStillGroupByMysteryGroup() {
    let steps = PrayerEngine().buildSteps(for: Prayer(rosary: RosaryOptions(mysterySelectionMode: .twentyMystery)))
    let layout = BeadLayout.build(steps: steps, currentIndex: steps.count / 2, hasClosingCross: true)

    XCTAssertEqual(layout.groupColumns.count, 4)
    XCTAssertEqual(layout.groupColumns.map(\.group), [.joyful, .luminous, .sorrowful, .glorious])
  }
}

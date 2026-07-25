//
//  JesusPrayerProgressTests.swift
//  ProsaryTests
//

import XCTest
@testable import Prosary

final class JesusPrayerProgressTests: XCTestCase {
  func testCanGoBack() {
    var progress = JesusPrayerProgress(target: .count(33))
    XCTAssertFalse(progress.canGoBack)
    progress.goNext()
    XCTAssertTrue(progress.canGoBack)
  }

  func testBoundedCompletionAtVariousTargets() {
    for target in [33, 66, 99, 47] {
      var progress = JesusPrayerProgress(target: .count(target))
      for _ in 0..<(target - 1) {
        XCTAssertFalse(progress.isLastRep, "target \(target)")
        progress.goNext()
      }
      XCTAssertTrue(progress.isLastRep, "target \(target)")
      XCTAssertEqual(progress.currentIndex, target - 1)
    }
  }

  func testGoNextDoesNotOvershootBoundedTarget() {
    var progress = JesusPrayerProgress(target: .count(3), currentIndex: 2)
    progress.goNext()
    XCTAssertEqual(progress.currentIndex, 2)
  }

  func testGoBackDoesNotUndershootZero() {
    var progress = JesusPrayerProgress(target: .count(33))
    progress.goBack()
    XCTAssertEqual(progress.currentIndex, 0)
  }

  func testUnboundedNeverCompletes() {
    var progress = JesusPrayerProgress(target: .unbounded)
    for _ in 0..<10_000 {
      progress.goNext()
    }
    XCTAssertFalse(progress.isLastRep)
    XCTAssertNil(progress.targetCount)
    XCTAssertNil(progress.progressFraction)
  }

  func testProgressFraction() {
    let progress = JesusPrayerProgress(target: .count(33))
    XCTAssertEqual(progress.progressFraction, 1.0 / 33.0)
  }
}

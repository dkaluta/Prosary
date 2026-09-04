//
//  AppNavigationTests.swift
//  ProsaryTests
//

import XCTest
@testable import Prosary

final class AppNavigationTests: XCTestCase {
  func testPushingTheCurrentRouteTwiceKeepsOneDestination() {
    var path: [AppRoute] = []

    XCTAssertTrue(path.push(.rosaryPresets))
    XCTAssertFalse(path.push(.rosaryPresets))

    XCTAssertEqual(path, [.rosaryPresets])
  }

  func testDistinctDestinationsStillBuildANestedFlow() {
    var path: [AppRoute] = []

    path.push(.jesusPrayerSetup)
    path.push(.jesusPrayer(target: .count(33)))

    XCTAssertEqual(path.count, 2)
  }

  func testQuickPrayerWithStableScratchIdentityIsDeduplicated() {
    var path: [AppRoute] = []
    let scratchID = UUID()

    XCTAssertTrue(path.push(.rosaryQuickPray(
      prayer: Prayer(id: scratchID, name: "", kind: .rosary, rosary: RosaryOptions()))))
    XCTAssertFalse(path.push(.rosaryQuickPray(
      prayer: Prayer(id: scratchID, name: "", kind: .rosary, rosary: RosaryOptions()))))

    XCTAssertEqual(path.count, 1)
  }

  func testDoubleClickingABasicPrayerKeepsOnePrayerOnTheList() {
    var path: [AppRoute] = [.basicPrayers]

    XCTAssertTrue(path.push(.basicPrayer(id: "signOfCross")))
    XCTAssertFalse(path.push(.basicPrayer(id: "signOfCross")))

    XCTAssertEqual(path, [.basicPrayers, .basicPrayer(id: "signOfCross")])
  }
}

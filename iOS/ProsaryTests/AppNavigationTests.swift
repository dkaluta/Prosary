//
//  AppNavigationTests.swift
//  ProsaryTests
//

import XCTest
@testable import Prosary

final class AppNavigationTests: XCTestCase {
  @MainActor
  func testOnlyTheActiveWindowConsumesAnExternalPrayerRequest() {
    let coordinator = NavigationCoordinator()
    let first = UUID()
    let second = UUID()
    coordinator.activateWindow(first)
    coordinator.pendingRoute = .custom(devotionId: "angelus")
    XCTAssertNil(coordinator.takePendingRoute(for: second))
    XCTAssertEqual(coordinator.takePendingRoute(for: first), .custom(devotionId: "angelus"))
    XCTAssertNil(coordinator.takePendingRoute(for: first))

    coordinator.activateWindow(second)
    coordinator.pendingRoute = .basicPrayer(id: "ourFather")
    coordinator.closeWindow(first)
    XCTAssertNil(coordinator.takePendingRoute(for: first))
    XCTAssertEqual(coordinator.takePendingRoute(for: second), .basicPrayer(id: "ourFather"))
  }

  @MainActor
  func testAnIntentWaitsForAWindowAfterTheLastWindowCloses() {
    let coordinator = NavigationCoordinator()
    let oldWindow = UUID()
    coordinator.activateWindow(oldWindow)
    coordinator.closeWindow(oldWindow)
    coordinator.pendingRoute = .rosaryPresets
    XCTAssertNil(coordinator.takePendingRoute(for: oldWindow))
    let newWindow = UUID()
    coordinator.activateWindow(newWindow)
    XCTAssertEqual(coordinator.takePendingRoute(for: newWindow), .rosaryPresets)
  }

  func testRepeatedOpeningsHaveIndependentRestorableWindowIdentities() throws {
    let route = AppRoute.custom(devotionId: "angelus", languageCode: "he", variantId: "default")
    let first = PrayerWindowRequest(route: route)
    let second = PrayerWindowRequest(route: route)
    XCTAssertNotEqual(first, second)
    XCTAssertEqual(first.route, second.route)
    let restored = try JSONDecoder().decode(PrayerWindowRequest.self, from: JSONEncoder().encode(first))
    XCTAssertEqual(restored, first)
  }

  func testOrdinaryBasicPrayerOpeningsReuseTheirOwnRestorableWindow() throws {
    var identities: Set<UUID> = []
    for prayer in BasicPrayerCatalog.all {
      let route = AppRoute.basicPrayer(id: prayer.id)
      let first = PrayerWindowRequest(route: route)
      let repeated = PrayerWindowRequest(route: route)
      XCTAssertEqual(first, repeated, "Repeated activation should reuse \(prayer.id)'s window")
      XCTAssertTrue(identities.insert(first.id).inserted,
                    "Different basic prayers must not share a window identity")

      let restored = try JSONDecoder().decode(PrayerWindowRequest.self, from: JSONEncoder().encode(first))
      XCTAssertEqual(restored, repeated, "Restoration should preserve the ordinary opening target")
      XCTAssertEqual(restored.route, route)
    }
  }

  func testExplicitBasicPrayerWindowsRemainIndependentOfOrdinaryOpening() throws {
    let route = AppRoute.basicPrayer(id: "ourFather")
    let ordinary = PrayerWindowRequest(route: route)
    let firstSibling = PrayerWindowRequest(route: route, newWindow: true)
    let secondSibling = PrayerWindowRequest(route: route, newWindow: true)
    XCTAssertEqual(Set([ordinary.id, firstSibling.id, secondSibling.id]).count, 3)
    XCTAssertEqual(firstSibling.route, route)
    XCTAssertEqual(secondSibling.route, route)
    XCTAssertEqual(PrayerWindowRequest(route: route), ordinary,
                   "An explicit sibling must not replace the ordinary opening target")

    let restored = try JSONDecoder().decode(PrayerWindowRequest.self, from: JSONEncoder().encode(firstSibling))
    XCTAssertEqual(restored, firstSibling)
    XCTAssertNotEqual(restored, ordinary)
  }

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

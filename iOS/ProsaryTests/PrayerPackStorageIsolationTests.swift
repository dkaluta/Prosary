import XCTest
@testable import Prosary

@MainActor
final class PrayerPackStorageIsolationTests: XCTestCase {
  func testTestPolicyDoesNotResolveProductionDirectoriesOrAllowCloudOperations() {
    let root = URL(fileURLWithPath: "/isolated-test-process", isDirectory: true)
    let policy = PrayerPackStoragePolicy(isTesting: true, testRoot: root)
    var realDirectoryQueries = 0
    let packs = policy.installedDirectory {
      realDirectoryQueries += 1
      return URL(fileURLWithPath: "/real-prayer-packs", isDirectory: true)
    }
    let audio = policy.audioDirectory {
      realDirectoryQueries += 1
      return URL(fileURLWithPath: "/real-audio-cache", isDirectory: true)
    }
    XCTAssertEqual(packs, root.appendingPathComponent("PrayerPacks", isDirectory: true))
    XCTAssertEqual(audio, root.appendingPathComponent("PrayerAudio", isDirectory: true))
    XCTAssertEqual(realDirectoryQueries, 0)
    XCTAssertFalse(policy.allowsUbiquity)
  }

  func testProductionPolicyRetainsItsExistingLocationsAndCloudAvailability() {
    let policy = PrayerPackStoragePolicy(isTesting: false,
      testRoot: URL(fileURLWithPath: "/unused-test-location", isDirectory: true))
    let packs = URL(fileURLWithPath: "/normal-prayer-packs", isDirectory: true)
    let audio = URL(fileURLWithPath: "/normal-audio-cache", isDirectory: true)
    XCTAssertEqual(policy.installedDirectory { packs }, packs)
    XCTAssertEqual(policy.audioDirectory { audio }, audio)
    XCTAssertNil(policy.audioDirectory { nil })
    XCTAssertTrue(policy.allowsUbiquity)
  }

  func testExplicitPackFixtureDirectoryAndRemovalDefaultsRemainOverridable() throws {
    let originalDirectory = PrayerPackStore.installedPacksDirectory
    let originalDefaults = PrayerPackStore.downloadRemovalDefaults
    let suite = "PrayerPackStorageIsolationTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
      PrayerPackStore.installedPacksDirectory = originalDirectory
      PrayerPackStore.downloadRemovalDefaults = originalDefaults
      defaults.removePersistentDomain(forName: suite)
    }
    PrayerPackStore.installedPacksDirectory = directory
    PrayerPackStore.downloadRemovalDefaults = defaults
    XCTAssertEqual(PrayerPackStore.installedPacksDirectory, directory)
    XCTAssertTrue(PrayerPackStore.downloadRemovalDefaults === defaults)
    XCTAssertFalse(PrayerPackStore.downloadRemovalDefaults === UserDefaults.standard)
  }
}

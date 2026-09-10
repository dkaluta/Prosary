import XCTest
@testable import Prosary

@MainActor
final class CloudSyncedListTests: XCTestCase {
  func testTestModeNeverAcquiresCloudForReadsWritesRemovalOrStartup() throws {
    let suite = "CloudSyncedListTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let fakeCloud = FakeCloudStore()
    fakeCloud.values["pins"] = ["real-cloud-value"]
    fakeCloud.values["run"] = Data([99])
    let notifications = NotificationCenter()
    var providerCalls = 0
    var receivedChange = false
    let storage = CloudSyncedListStorage(defaults: defaults, isTesting: true, notifications: notifications) {
      providerCalls += 1
      return fakeCloud
    }
    defaults.set(["local-test-value"], forKey: "pins")
    defaults.set(Data([1]), forKey: "run")
    XCTAssertEqual(storage.read("pins"), ["local-test-value"])
    XCTAssertEqual(storage.readData("run"), Data([1]))
    storage.write(["updated-test-value"], forKey: "pins")
    storage.writeData(Data([2]), forKey: "run")
    XCTAssertEqual(defaults.stringArray(forKey: "pins"), ["updated-test-value"])
    XCTAssertEqual(defaults.data(forKey: "run"), Data([2]))
    storage.startSyncing { receivedChange = true }
    notifications.post(name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
      object: fakeCloud, userInfo: [NSUbiquitousKeyValueStoreChangedKeysKey: ["pins", "run"]])
    storage.remove("pins")
    storage.remove("run")
    XCTAssertNil(storage.read("pins"))
    XCTAssertNil(storage.readData("run"))
    XCTAssertEqual(providerCalls, 0, "Even acquiring NSUbiquitousKeyValueStore.default is forbidden in test mode")
    XCTAssertEqual(fakeCloud.synchronizeCount, 0)
    XCTAssertEqual(fakeCloud.values["pins"] as? [String], ["real-cloud-value"])
    XCTAssertEqual(fakeCloud.values["run"] as? Data, Data([99]))
    XCTAssertFalse(receivedChange)
  }

  func testProductionPolicyStillPrefersCloudAndMirrorsWritesAndRemoval() throws {
    let suite = "CloudSyncedListTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let fakeCloud = FakeCloudStore()
    fakeCloud.values["pins"] = ["cloud"]
    let storage = CloudSyncedListStorage(defaults: defaults, isTesting: false, cloudProvider: { fakeCloud })
    defaults.set(["local"], forKey: "pins")
    defaults.set(["offline"], forKey: "offlinePins")
    XCTAssertEqual(storage.read("pins"), ["cloud"])
    XCTAssertEqual(storage.read("offlinePins"), ["offline"])
    storage.write(["updated"], forKey: "pins")
    storage.writeData(Data([1, 2, 3]), forKey: "run")
    XCTAssertEqual(defaults.stringArray(forKey: "pins"), ["updated"])
    XCTAssertEqual(fakeCloud.values["pins"] as? [String], ["updated"])
    XCTAssertEqual(storage.readData("run"), Data([1, 2, 3]))
    XCTAssertEqual(defaults.data(forKey: "run"), Data([1, 2, 3]))
    storage.remove("pins")
    storage.remove("run")
    XCTAssertNil(defaults.object(forKey: "pins"))
    XCTAssertNil(defaults.object(forKey: "run"))
    XCTAssertNil(fakeCloud.values["pins"])
    XCTAssertNil(fakeCloud.values["run"])
    XCTAssertEqual(fakeCloud.synchronizeCount, 4)
  }

  func testProductionExternalChangesMirrorArraysDataAndDeletionOnce() throws {
    let suite = "CloudSyncedListTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let fakeCloud = FakeCloudStore()
    fakeCloud.values["pins"] = ["from-another-device"]
    fakeCloud.values["run"] = Data([7])
    defaults.set(["old"], forKey: "removed")
    let notifications = NotificationCenter()
    let storage = CloudSyncedListStorage(defaults: defaults, isTesting: false,
      notifications: notifications, cloudProvider: { fakeCloud })
    var changeCount = 0
    storage.startSyncing { changeCount += 1 }
    storage.startSyncing { changeCount += 1 }
    notifications.post(name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
      object: fakeCloud, userInfo: [NSUbiquitousKeyValueStoreChangedKeysKey: ["pins", "run", "removed"]])
    XCTAssertEqual(defaults.stringArray(forKey: "pins"), ["from-another-device"])
    XCTAssertEqual(defaults.data(forKey: "run"), Data([7]))
    XCTAssertNil(defaults.object(forKey: "removed"))
    XCTAssertEqual(changeCount, 1)
    XCTAssertEqual(fakeCloud.synchronizeCount, 1)
  }

  private final class FakeCloudStore: NSObject, CloudSyncedListCloudStore {
    var values: [String: Any] = [:]
    var synchronizeCount = 0
    func array(forKey key: String) -> [Any]? { values[key] as? [Any] }
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func removeObject(forKey key: String) { values.removeValue(forKey: key) }
    func synchronize() -> Bool { synchronizeCount += 1; return true }
  }
}

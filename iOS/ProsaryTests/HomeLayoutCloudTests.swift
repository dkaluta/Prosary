import XCTest
@testable import Prosary

final class HomeLayoutCloudTests: XCTestCase {
  private final class MemoryCloud: CloudSyncedListCloudStore {
    var values: [String: Any] = [:]
    func array(forKey key: String) -> [Any]? { values[key] as? [Any] }
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func removeObject(forKey key: String) { values.removeValue(forKey: key) }
    func synchronize() -> Bool { true }
  }

  func testTwoPreferenceStoresExchangeAnAtomicLayoutWithoutPrivatePhotoPaths() throws {
    let cloud = MemoryCloud()
    let firstName = "HomeLayoutCloud.first.\(UUID())"
    let secondName = "HomeLayoutCloud.second.\(UUID())"
    let firstDefaults = try XCTUnwrap(UserDefaults(suiteName: firstName))
    let secondDefaults = try XCTUnwrap(UserDefaults(suiteName: secondName))
    defer {
      firstDefaults.removePersistentDomain(forName: firstName)
      secondDefaults.removePersistentDomain(forName: secondName)
    }
    secondDefaults.set("private-photo", forKey: "homePhotoPath")
    let first = CloudSyncedListStorage(defaults: firstDefaults, isTesting: false, cloudProvider: { cloud })
    let second = CloudSyncedListStorage(defaults: secondDefaults, isTesting: false, cloudProvider: { cloud })
    let layout = HomeLayoutCloud.normalized(order: "torah\nfeast", collapsed: "feast", colors: "{\"feast\":\"rose\"}")
    first.writeData(try JSONEncoder().encode(layout), forKey: HomeLayoutCloud.key)
    XCTAssertEqual(HomeLayoutCloud.decode(try XCTUnwrap(second.readData(HomeLayoutCloud.key))), layout)
    XCTAssertEqual(secondDefaults.string(forKey: "homePhotoPath"), "private-photo")
    let empty = HomeLayoutCloud.normalized(order: "", collapsed: "", colors: "{}")
    second.writeData(try JSONEncoder().encode(empty), forKey: HomeLayoutCloud.key)
    XCTAssertEqual(HomeLayoutCloud.decode(try XCTUnwrap(first.readData(HomeLayoutCloud.key))), empty)
    XCTAssertEqual(Set(cloud.values.keys), [HomeLayoutCloud.key])
  }

  func testSnapshotKeepsDeliberatelyEmptyLayoutAndNormalizesKnownPreferences() throws {
    let value = HomeLayoutCloud.normalized(order: "", collapsed: "readings\nunknown\nreadings",
      colors: "{\"feast\":\"rose\",\"torah\":\"default\",\"unknown\":\"blue\"}")
    XCTAssertEqual(value.order, "")
    XCTAssertEqual(value.collapsed, "readings")
    XCTAssertEqual(HomeWidgetDisplay.colors(value.colors), [.feast: .rose])
    XCTAssertEqual(HomeLayoutCloud.decode(try JSONEncoder().encode(value)), value)
  }

  func testCloudPayloadHasOnlyPortableLayoutAndRejectsUnsupportedData() throws {
    let value = HomeLayoutCloud.normalized(order: "readings\ntorah\nreadings", collapsed: "torah", colors: "{}")
    let encoded = try JSONEncoder().encode(value)
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    XCTAssertEqual(Set(object.keys), ["version", "order", "collapsed", "colors"])
    XCTAssertEqual(value.order, "readings\ntorah")
    XCTAssertNil(HomeLayoutCloud.decode(Data("{\"version\":2,\"order\":\"\",\"collapsed\":\"\",\"colors\":\"{}\"}".utf8)))
    XCTAssertNil(HomeLayoutCloud.decode(Data("invalid".utf8)))
    XCTAssertNil(HomeLayoutCloud.decode(Data(repeating: 32, count: 16_385)))
  }
}

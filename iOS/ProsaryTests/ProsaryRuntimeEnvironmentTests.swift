import XCTest
@testable import Prosary

@MainActor
final class ProsaryRuntimeEnvironmentTests: XCTestCase {
  func testEverySupportedTestHostSignalSelectsIsolation() {
    for argument in ["-useInMemoryStore", "-resetStore"] {
      XCTAssertTrue(ProsaryRuntimeEnvironment.detectsTesting(arguments: ["Prosary", argument], environment: [:]))
    }
    for environment in [
      ["XCTestConfigurationFilePath": "/tmp/configuration.xctestconfiguration"],
      ["XCTestSessionIdentifier": "a-session"],
      ["XCTestSessionIdentifier": ""],
      ["PROSARY_TEST_MODE": "1"],
    ] {
      XCTAssertTrue(ProsaryRuntimeEnvironment.detectsTesting(arguments: ["Prosary"], environment: environment))
    }
  }

  func testOrdinaryLaunchAndUnrelatedArgumentsDoNotSelectTesting() {
    XCTAssertFalse(ProsaryRuntimeEnvironment.detectsTesting(arguments: ["Prosary"], environment: [:]))
    XCTAssertFalse(ProsaryRuntimeEnvironment.detectsTesting(
      arguments: ["Prosary", "-useInMemoryStoreExtra", "some-resetStore-file"],
      environment: ["PROSARY_TEST_MODE": "0", "OTHER_XCTestSessionIdentifier": "value"]))
  }

  func testInjectedTestSuitesKeepWritesAndRemovalSeparate() throws {
    let firstSuite = "ProsaryRuntimeEnvironmentTests.first.\(UUID().uuidString)"
    let secondSuite = "ProsaryRuntimeEnvironmentTests.second.\(UUID().uuidString)"
    let first = ProsaryRuntimeEnvironment.makeDefaults(isTesting: true, testSuiteName: firstSuite)
    let second = ProsaryRuntimeEnvironment.makeDefaults(isTesting: true, testSuiteName: secondSuite)
    defer {
      first.removePersistentDomain(forName: firstSuite)
      second.removePersistentDomain(forName: secondSuite)
    }
    XCTAssertFalse(first === UserDefaults.standard)
    XCTAssertFalse(second === UserDefaults.standard)
    first.set(["angelus"], forKey: "favoriteDevotionIds")
    second.set(["rosary"], forKey: "favoriteDevotionIds")
    first.removeObject(forKey: "favoriteDevotionIds")
    XCTAssertNil(first.stringArray(forKey: "favoriteDevotionIds"))
    XCTAssertEqual(second.stringArray(forKey: "favoriteDevotionIds"), ["rosary"])
    XCTAssertTrue(ProsaryRuntimeEnvironment.makeDefaults(isTesting: false, testSuiteName: firstSuite) === UserDefaults.standard)
  }
}

import Foundation

/// Decide storage isolation before AppServices or any cloud-backed preference is initialized.
/// Both unit-test hosts and UI-launched test apps must avoid the person's real data.
enum ProsaryRuntimeEnvironment {
  static let isTesting = detectsTesting(arguments: CommandLine.arguments, environment: ProcessInfo.processInfo.environment)

  private static let testSuiteName = "app.prosary.tests.\(ProcessInfo.processInfo.processIdentifier).\(UUID().uuidString)"
  static let defaults = makeDefaults(isTesting: isTesting, testSuiteName: testSuiteName)

  static func detectsTesting(arguments: [String], environment: [String: String]) -> Bool {
    arguments.contains("-useInMemoryStore") || arguments.contains("-resetStore")
      || environment["XCTestConfigurationFilePath"] != nil
      || environment["XCTestSessionIdentifier"] != nil
      || environment["PROSARY_TEST_MODE"] == "1"
  }

  /// Tests can inject their own disposable suite without altering process-global policy.
  static func makeDefaults(isTesting: Bool, testSuiteName: String) -> UserDefaults {
    guard isTesting else { return .standard }
    guard let isolated = UserDefaults(suiteName: testSuiteName) else {
      preconditionFailure("Could not create isolated test preferences")
    }
    return isolated
  }
}

import XCTest
@testable import Prosary

@MainActor
final class PrayerSessionLoaderTests: XCTestCase {
  func testReappearanceSharesInitializationEvenWhenTheOldAppearanceTaskIsCancelled() async {
    let loader = PrayerSessionLoader()
    let entered = expectation(description: "First appearance starts loading")
    let secondRequested = expectation(description: "Second appearance joins loading")
    let (release, continuation) = AsyncStream<Void>.makeStream()
    var operations = 0
    var completed = false

    let first = Task {
      await loader.perform {
        operations += 1
        entered.fulfill()
        for await _ in release { break }
        XCTAssertFalse(Task.isCancelled)
        completed = true
      }
    }
    await fulfillment(of: [entered], timeout: 2)
    let second = Task {
      secondRequested.fulfill()
      await loader.perform { operations += 1 }
    }
    await fulfillment(of: [secondRequested], timeout: 2)
    first.cancel()
    continuation.yield()
    continuation.finish()
    await first.value
    await second.value
    XCTAssertTrue(completed)
    XCTAssertEqual(operations, 1)
  }
}

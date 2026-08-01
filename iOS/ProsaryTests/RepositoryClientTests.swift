//
//  RepositoryClientTests.swift
//  ProsaryTests
//
//  Pins the prayers.prosary.app /index.json contract (prosaryRepository: 1) without a network.
//

import XCTest
@testable import Prosary

final class RepositoryClientTests: XCTestCase {
  private let fixture = Data("""
    {"prosaryRepository": 1, "bundles": [
      {"id": "repo.dkaluta.kyrie", "name": "Kyrie", "author": "dkaluta",
       "languages": ["la", "en"], "tags": ["short"],
       "description": "A one-minute devotion.", "file": "/api/download/repo.dkaluta.kyrie"}
    ]}
    """.utf8)

  func testParsesTheVersionedCatalog() throws {
    let bundles = try RepositoryClient.parseCatalog(fixture)
    XCTAssertEqual(bundles.count, 1)
    XCTAssertEqual(bundles[0].id, "repo.dkaluta.kyrie")
    XCTAssertEqual(bundles[0].author, "dkaluta")
    XCTAssertEqual(bundles[0].languages, ["la", "en"])
    XCTAssertEqual(bundles[0].tags, ["short"])
    XCTAssertEqual(bundles[0].file, "/api/download/repo.dkaluta.kyrie")
  }

  func testRejectsANewerCatalogVersion() {
    let newer = Data(#"{"prosaryRepository": 2, "bundles": []}"#.utf8)
    XCTAssertThrowsError(try RepositoryClient.parseCatalog(newer))
  }
}

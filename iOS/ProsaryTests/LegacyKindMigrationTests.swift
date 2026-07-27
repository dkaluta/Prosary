//
//  LegacyKindMigrationTests.swift
//  ProsaryTests
//
//  Rows written before the generic-devotion migration persist per-devotion kind strings
//  ("angelus", "stationsOfTheCross", ...). PresetEntry.resolvedKind must map them to
//  .custom + the matching bundle id — permanently at read time (not one-shot), because
//  CloudKit can sync rows from old app versions in at any time.
//

import XCTest
@testable import Prosary

final class LegacyKindMigrationTests: XCTestCase {
  private func legacyEntry(kind: String) -> PresetEntry {
    let entry = PresetEntry(prayer: Prayer(name: "Legacy", kind: .rosary))
    entry.kind = kind
    entry.customDevotionId = nil
    return entry
  }

  func testEveryLegacyKindMapsToItsBundleId() {
    for legacy in ["angelus", "stationsOfTheCross", "franciscanCrown", "sevenSorrows", "divineMercyChaplet"] {
      let prayer = legacyEntry(kind: legacy).toPrayer()
      XCTAssertEqual(prayer.kind, .custom, "\(legacy) should migrate to .custom")
      XCTAssertEqual(prayer.customDevotionId, legacy, "\(legacy)'s rawValue doubles as its bundle id")
    }
  }

  func testCurrentKindsPassThroughUnchanged() {
    for kind in PrayerKind.allCases {
      let entry = legacyEntry(kind: kind.rawValue)
      XCTAssertEqual(entry.toPrayer().kind, kind)
    }
  }

  func testExistingCustomDevotionIdWinsOverTheLegacyRawValue() {
    let entry = legacyEntry(kind: "custom")
    entry.customDevotionId = "trisagion"
    let prayer = entry.toPrayer()
    XCTAssertEqual(prayer.kind, .custom)
    XCTAssertEqual(prayer.customDevotionId, "trisagion")
  }

  /// A migrated legacy row and a freshly created .custom favorite must share one default slot.
  func testDefaultScopingTreatsLegacyAndMigratedRowsAsTheSameDevotion() async throws {
    let legacy = legacyEntry(kind: "angelus")
    legacy.isDefault = true
    XCTAssertEqual(legacy.resolvedKind.kind, .custom)
    XCTAssertEqual(legacy.resolvedKind.customDevotionId, "angelus")

    let fresh = PresetEntry(prayer: Prayer(
      name: "Angelus", kind: .custom, customDevotionId: "angelus"))
    XCTAssertTrue(
      legacy.resolvedKind == fresh.resolvedKind,
      "legacy and migrated rows must resolve to the same (kind, devotionId) identity")
  }
}

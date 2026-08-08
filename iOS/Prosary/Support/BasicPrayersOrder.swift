//
//  BasicPrayersOrder.swift
//  Prosary
//
//  The user's personal ordering of the basic-prayers list (Erez, 2026-08-08) — the HomeOrder
//  pattern on a fixed catalog: a persisted list of prayer ids, catalog order for ids it does
//  not name (so a prayer added in an update appears after the ordered ones), an empty list
//  meaning pure catalog order.
//

import Foundation

enum BasicPrayersOrder {
  private static let key = "basicPrayerOrder"

  /// Synced like the Home order — a devotional ordering is the user's own on every device.
  static var saved: [String] {
    CloudSyncedList.read(key) ?? []
  }

  static func save(_ ids: [String]) {
    CloudSyncedList.write(ids, forKey: key)
  }

  static func reset() {
    CloudSyncedList.remove(key)
  }

  /// Stable sort by saved position; unknown ids keep their relative (catalog) order at the
  /// end. Swift's sort isn't stable, so the original index breaks ties explicitly.
  static func apply(_ prayers: [BasicPrayer]) -> [BasicPrayer] {
    let order = saved
    guard !order.isEmpty else { return prayers }
    return prayers.enumerated()
      .sorted { a, b in
        let ia = order.firstIndex(of: a.element.id) ?? Int.max
        let ib = order.firstIndex(of: b.element.id) ?? Int.max
        return ia != ib ? ia < ib : a.offset < b.offset
      }
      .map(\.element)
  }
}

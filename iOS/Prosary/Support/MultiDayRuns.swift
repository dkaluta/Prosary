//
//  MultiDayRuns.swift
//  Prosary
//
//  Where multi-day runs live: one per devotion, keyed by bundle id, carried in the same iCloud
//  key-value store as the pins. A run is small, transient state rather than a record, and
//  putting it here keeps it in step with the pin that shows the devotion — and avoids a
//  SwiftData schema migration on every platform for something that is not a saved document.
//

import Foundation

enum MultiDayRuns {
  private static let key = "multiDayRuns"

  private static var all: [String: MultiDayRun] {
    get {
      guard let data = CloudSyncedList.readData(key),
            let decoded = try? JSONDecoder().decode([String: MultiDayRun].self, from: data) else {
        return [:]
      }
      return decoded
    }
    set {
      guard let data = try? JSONEncoder().encode(newValue) else { return }
      CloudSyncedList.writeData(data, forKey: key)
    }
  }

  static func run(for devotionId: String) -> MultiDayRun? {
    all[devotionId]
  }

  @discardableResult
  static func startFresh(_ devotionId: String, on date: Date = Date()) -> MultiDayRun {
    let run = MultiDayRun(devotionId: devotionId, startedOn: date)
    all[devotionId] = run
    return run
  }

  /// Records a day as prayed, beginning a run if this is the first day of one.
  static func recordPrayed(devotionId: String, day: Int, on date: Date = Date()) {
    var run = all[devotionId] ?? MultiDayRun(devotionId: devotionId, startedOn: date)
    run.recordPrayed(day: day, on: date)
    all[devotionId] = run
  }

  static func clear(_ devotionId: String) {
    all[devotionId] = nil
  }

  static func reset() {
    CloudSyncedList.remove(key)
  }
}

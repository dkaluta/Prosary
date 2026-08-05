//
//  CloudSyncedList.swift
//  Prosary
//
//  A short list of strings that follows the person, not the device: which devotions are pinned
//  to Pray and the order they sit in. Presets sync through SwiftData's CloudKit mirroring, and
//  it would be odd for a favorite to arrive on the iPad while the pin that shows it did not.
//
//  NSUbiquitousKeyValueStore is the right size of tool here — kilobytes of preferences, no
//  schema, free conflict resolution — but it is only *eventually* available, so every value is
//  mirrored into UserDefaults and read from there whenever iCloud has nothing yet. That also
//  keeps the whole thing working with iCloud switched off.
//

import Foundation
import Observation

/// Bumped when iCloud hands us someone else's change, so the views that read these lists in
/// their body re-derive.
@Observable
final class CloudPreferencesGeneration {
  static let shared = CloudPreferencesGeneration()
  private(set) var value = 0
  func bump() { value += 1 }
}

enum CloudSyncedList {
  private static var cloud: NSUbiquitousKeyValueStore { .default }

  static func read(_ key: String) -> [String]? {
    if let cloudValue = cloud.array(forKey: key) as? [String] {
      return cloudValue
    }
    return UserDefaults.standard.stringArray(forKey: key)
  }

  static func write(_ value: [String], forKey key: String) {
    UserDefaults.standard.set(value, forKey: key)
    cloud.set(value, forKey: key)
    cloud.synchronize()
  }

  static func remove(_ key: String) {
    UserDefaults.standard.removeObject(forKey: key)
    cloud.removeObject(forKey: key)
    cloud.synchronize()
  }

  /// Pulls whatever another device wrote into the local mirror. Call once at launch: the
  /// notification only fires for *changes*, so a fresh install needs the initial read.
  static func startSyncing(onChange: @escaping () -> Void = { CloudPreferencesGeneration.shared.bump() }) {
    NotificationCenter.default.addObserver(
      forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
      object: cloud, queue: .main
    ) { notification in
      let changed = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
      for key in changed {
        if let value = cloud.array(forKey: key) as? [String] {
          UserDefaults.standard.set(value, forKey: key)
        } else {
          UserDefaults.standard.removeObject(forKey: key)
        }
      }
      onChange()
    }
    cloud.synchronize()
  }
}

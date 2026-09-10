//
//  CloudSyncedList.swift
//  Prosary
//
//  Small lists and Codable payloads follow the person through iCloud, mirrored locally
//  for offline use. Test hosts use an isolated local suite and never acquire iCloud.
//

import Foundation
import Observation

@Observable
final class CloudPreferencesGeneration {
  static let shared = CloudPreferencesGeneration()
  private(set) var value = 0
  func bump() { value += 1 }
}

/// This seam keeps tests from constructing or mutating a real ubiquitous store.
protocol CloudSyncedListCloudStore: AnyObject {
  func array(forKey key: String) -> [Any]?
  func data(forKey key: String) -> Data?
  func set(_ value: Any?, forKey key: String)
  func removeObject(forKey key: String)
  @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: CloudSyncedListCloudStore {}

final class CloudSyncedListStorage {
  private let defaults: UserDefaults
  private let isTesting: Bool
  private let cloudProvider: () -> any CloudSyncedListCloudStore
  private let notifications: NotificationCenter
  private var observer: NSObjectProtocol?

  init(defaults: UserDefaults, isTesting: Bool,
       notifications: NotificationCenter = .default,
       cloudProvider: @escaping () -> any CloudSyncedListCloudStore) {
    self.defaults = defaults
    self.isTesting = isTesting
    self.notifications = notifications
    self.cloudProvider = cloudProvider
  }

  /// The conditional precedes provider evaluation on every path, including reads and resets.
  private var cloud: (any CloudSyncedListCloudStore)? { isTesting ? nil : cloudProvider() }

  func read(_ key: String) -> [String]? {
    (cloud?.array(forKey: key) as? [String]) ?? defaults.stringArray(forKey: key)
  }

  func write(_ value: [String], forKey key: String) {
    defaults.set(value, forKey: key)
    guard let cloud else { return }
    cloud.set(value, forKey: key)
    cloud.synchronize()
  }

  func readData(_ key: String) -> Data? {
    cloud?.data(forKey: key) ?? defaults.data(forKey: key)
  }

  func writeData(_ value: Data, forKey key: String) {
    defaults.set(value, forKey: key)
    guard let cloud else { return }
    cloud.set(value, forKey: key)
    cloud.synchronize()
  }

  func remove(_ key: String) {
    defaults.removeObject(forKey: key)
    guard let cloud else { return }
    cloud.removeObject(forKey: key)
    cloud.synchronize()
  }

  func startSyncing(onChange: @escaping () -> Void) {
    guard !isTesting, observer == nil, let cloud else { return }
    let defaults = defaults
    observer = notifications.addObserver(
      forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
      object: cloud, queue: .main
    ) { notification in
      let changed = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
      for key in changed {
        if let value = cloud.array(forKey: key) as? [String] {
          defaults.set(value, forKey: key)
        } else if let data = cloud.data(forKey: key) {
          defaults.set(data, forKey: key)
        } else {
          defaults.removeObject(forKey: key)
        }
      }
      onChange()
    }
    cloud.synchronize()
  }
}

enum CloudSyncedList {
  private static let storage = CloudSyncedListStorage(
    defaults: ProsaryRuntimeEnvironment.defaults,
    isTesting: ProsaryRuntimeEnvironment.isTesting,
    cloudProvider: { NSUbiquitousKeyValueStore.default })

  static func read(_ key: String) -> [String]? { storage.read(key) }
  static func write(_ value: [String], forKey key: String) { storage.write(value, forKey: key) }
  static func readData(_ key: String) -> Data? { storage.readData(key) }
  static func writeData(_ value: Data, forKey key: String) { storage.writeData(value, forKey: key) }
  static func remove(_ key: String) { storage.remove(key) }

  /// Calling this in a test is harmless, but production still begins syncing at app launch.
  static func startSyncing(onChange: @escaping () -> Void = { CloudPreferencesGeneration.shared.bump() }) {
    storage.startSyncing(onChange: onChange)
  }
}

import Foundation
import CryptoKit

/// Opening a saved library copy or basic prayer again brings its window forward. The explicit
/// new-window action can still give that prayer a second, independently positioned view.
struct PrayerWindowRequest: Hashable, Codable {
  let id: UUID
  let route: AppRoute

  init(route: AppRoute, newWindow: Bool = false) {
    switch route {
    case .prayer(let prayerID) where !newWindow: id = prayerID
    case .basicPrayer(let prayerID) where !newWindow: id = Self.basicPrayerID(prayerID)
    default: id = UUID()
    }
    self.route = route
  }

  /// A namespaced, deterministic UUID keeps ordinary basic-prayer windows reusable across
  /// all entry points and launches, while retaining the existing restorable UUID shape.
  private static func basicPrayerID(_ prayerID: String) -> UUID {
    var bytes = Array(SHA256.hash(data: Data("com.dkaluta.prosary.basicPrayer.\(prayerID)".utf8)).prefix(16))
    bytes[6] = (bytes[6] & 0x0f) | 0x80 // UUID version 8: application-defined name hash.
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                       bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
  }
}

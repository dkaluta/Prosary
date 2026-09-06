import Foundation

/// The Marian litany's final collect follows where it was opened. Its two forms remain
/// bundle-driven, while other devotions retain their freely selectable saved variants.
enum CustomDevotionLaunch {
  static func allowsVariantChoice(_ devotionId: String) -> Bool {
    devotionId != "litanyOfLoreto"
  }

  static func variantId(devotionId: String, incoming: String?, saved: String?) -> String? {
    guard devotionId == "litanyOfLoreto" else { return incoming ?? saved }
    return incoming == "afterRosary" ? "afterRosary" : "standard"
  }
}

import Foundation

/// Every standalone Litany uses its own collect. The Rosary embeds its invocations directly;
/// old routes and saved variants cannot turn a standalone prayer into that embedded form.
enum CustomDevotionLaunch {
  static func allowsVariantChoice(_ devotionId: String) -> Bool {
    devotionId != "litanyOfLoreto"
  }

  static func variantId(devotionId: String, incoming: String?, saved: String?) -> String? {
    guard devotionId == "litanyOfLoreto" else { return incoming ?? saved }
    return "standard"
  }
}

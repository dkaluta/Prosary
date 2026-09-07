import Foundation

/// An optional local wording applied only after the resolver has selected Vicariate text.
/// The canonical prayer and its source metadata remain unchanged.
enum JaffaHailMaryWording {
  static let defaultsKey = "useJaffaHailMaryWording"

  static var isEnabled: Bool { UserDefaults.standard.bool(forKey: defaultsKey) }

  static func applying(to text: String, contentCode: String, enabled: Bool = isEnabled) -> String {
    guard enabled, contentCode == LanguageCatalog.vicariateContentCode else { return text }
    return text
      .replacingOccurrences(of: "מְלֵאַת הַחֶסֶד", with: "בְּרוּכַת הַחֶסֶד")
      .replacingOccurrences(of: "מלאת החסד", with: "ברוכת החסד")
  }
}

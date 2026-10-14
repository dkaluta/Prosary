import Foundation

/// This community standalone was withdrawn. The built-in Loreto Litany and its sourced
/// Hebrew text remain available, including the Rosary closing.
enum RetiredPrayerBundles {
  static let loretoStandaloneID = "repo.stgamliel-il.litanyOfMaryTheBlessedEverVirgin"

  static func contains(_ bundleID: String?) -> Bool {
    bundleID == loretoStandaloneID
  }

  static func containsDevotionReference(_ value: String) -> Bool {
    contains(value) || value == "custom.\(loretoStandaloneID)"
  }

  static func containsRunKey(_ value: String) -> Bool {
    let fields = value.components(separatedBy: ":")
    guard let customIndex = fields.firstIndex(of: "custom"), customIndex + 1 < fields.count else { return false }
    if contains(fields[customIndex + 1]) { return true }
    return customIndex + 3 < fields.count && fields[customIndex + 1] == "mac"
      && UUID(uuidString: fields[customIndex + 2]) != nil && contains(fields[customIndex + 3])
  }

  static func containsProgressIdentity(_ value: String) -> Bool {
    if contains(value) { return true }
    let fields = value.components(separatedBy: ":")
    return fields.count == 3 && fields[0] == "mac" && UUID(uuidString: fields[1]) != nil
      && contains(fields[2])
  }
}

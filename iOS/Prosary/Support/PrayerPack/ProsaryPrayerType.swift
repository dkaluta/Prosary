import UniformTypeIdentifiers

extension UTType {
  /// The portable devotion archive declared in the app's exported document types. Keep this
  /// identity shared by the Finder/Files association and every native bundle picker.
  static let prosaryPrayer = UTType(exportedAs: "app.prosary.prayer", conformingTo: .zip)
}

import UniformTypeIdentifiers
import XCTest
@testable import Prosary

@MainActor
final class PrayerDocumentTypeTests: XCTestCase {
  func testBuiltAppExportsThePortableDevotionType() throws {
    let declarations = try XCTUnwrap(
      Bundle.main.infoDictionary?["UTExportedTypeDeclarations"] as? [[String: Any]])
    let declaration = try XCTUnwrap(declarations.first {
      $0["UTTypeIdentifier"] as? String == UTType.prosaryPrayer.identifier
    })
    let tags = try XCTUnwrap(declaration["UTTypeTagSpecification"] as? [String: Any])
    XCTAssertEqual(tags["public.filename-extension"] as? [String], ["prosaryprayer"])
    XCTAssertEqual(declaration["UTTypeConformsTo"] as? [String], [UTType.zip.identifier])
    XCTAssertTrue(UTType.prosaryPrayer.conforms(to: .data))
    XCTAssertEqual(UTType.prosaryPrayer.preferredFilenameExtension, "prosaryprayer")
  }

  func testBuiltAppOpensDevotionFilesAsAnImportingViewer() throws {
    let documents = try XCTUnwrap(
      Bundle.main.infoDictionary?["CFBundleDocumentTypes"] as? [[String: Any]])
    let document = try XCTUnwrap(documents.first {
      ($0["LSItemContentTypes"] as? [String])?.contains(UTType.prosaryPrayer.identifier) == true
    })
    XCTAssertEqual(document["CFBundleTypeRole"] as? String, "Viewer")
    XCTAssertEqual(document["LSHandlerRank"] as? String, "Owner")
    // ZIP remains an explicit picker fallback, so opening an unrelated ZIP in Finder should
    // keep going to its ordinary archive app.
    XCTAssertFalse(documents.contains {
      ($0["LSItemContentTypes"] as? [String])?.contains(UTType.zip.identifier) == true
    })
  }

  func testDocumentKindHasEveryInterfaceTranslationInTheBuiltApp() throws {
    for language in UILanguage.all.map(\.code) {
      let resource = UILanguage.resourceLanguage(language)
      let path = try XCTUnwrap(Bundle.main.path(forResource: resource, ofType: "lproj"), language)
      let localizedBundle = try XCTUnwrap(Bundle(path: path), language)
      let description = localizedBundle.localizedString(
        forKey: "Prosary devotion bundle", value: "missing", table: "InfoPlist")
      XCTAssertNotEqual(description, "missing", language)
      XCTAssertFalse(description.isEmpty, language)
      if language != "en" { XCTAssertNotEqual(description, "Prosary devotion bundle", language) }
    }
  }
}

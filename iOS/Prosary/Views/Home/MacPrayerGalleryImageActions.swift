#if os(macOS)
import SwiftUI

enum MacPrayerGalleryImageAction: Int, CaseIterable {
  case chooseFile, searchOnline, restoreDefault, viewSource

  var title: String {
    switch self {
    case .chooseFile: String(localized: "galleryImage.choose", defaultValue: "Choose Image…")
    case .searchOnline: String(localized: "galleryImage.searchOnline", defaultValue: "Search Online…")
    case .restoreDefault: String(localized: "galleryImage.restoreDefault", defaultValue: "Use Default Image")
    case .viewSource: String(localized: "galleryImage.source", defaultValue: "Image Source")
    }
  }
}
#endif

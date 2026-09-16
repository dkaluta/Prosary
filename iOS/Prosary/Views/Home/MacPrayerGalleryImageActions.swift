#if os(macOS)
import SwiftUI

enum MacPrayerGalleryImageAction: Int, CaseIterable {
  case chooseFile, searchOnline, restoreDefault, viewSource

  var title: String {
    switch self {
    case .chooseFile: String(localized: "galleryImage.choose", defaultValue: "Choose Image…", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .searchOnline: String(localized: "galleryImage.searchOnline", defaultValue: "Search Online…", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .restoreDefault: String(localized: "galleryImage.restoreDefault", defaultValue: "Use Default Image", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .viewSource: String(localized: "galleryImage.source", defaultValue: "Image Source", bundle: UILanguage.bundle, locale: UILanguage.locale)
    }
  }
}
#endif

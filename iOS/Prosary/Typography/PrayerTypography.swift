//
//  PrayerTypography.swift
//  Prosary
//
//  Resolves the serif typeface used for prayer/Scripture body text, per language and content
//  type. Scripture quotations (the mystery-announcement step) get a dedicated typeface distinct
//  from ordinary prayer text — Cardo (Latin/English) and Scheherazade New (Arabic) were both
//  designed for classical/Biblical typesetting, the same reasoning behind using Shofar (rather
//  than Frank Ruhl Libre) for Hebrew. Latin/English prayers use Apple's native "New York" serif
//  design rather than a bundled font, since it's not ours to redistribute.
//
//  All sizes are relative to `.body`, so custom fonts still respond to Dynamic Type.
//

import SwiftUI

enum PrayerTypography {
  // macOS's native `.body` runs a good deal smaller than iOS's (~13pt vs. ~17pt). The sizes
  // below were tuned by eye against iOS, so without this correction the same literal point
  // sizes read as oversized next to the rest of a Mac window. Scaling keeps every custom
  // typeface in the same visual proportion to `.body` on both platforms.
  #if os(macOS)
  private static let scale: CGFloat = 0.76
  #else
  private static let scale: CGFloat = 1.0
  #endif

  static func font(languageCode: String?, isScripture: Bool) -> Font {
    switch languageCode {
    case "he":
      return isScripture
        ? .custom(FontRegistration.PostScriptName.shofar, size: 16 * scale, relativeTo: .body)
        : .custom(FontRegistration.PostScriptName.frankRuhlLibre, size: 21 * scale, relativeTo: .body)

    case "ar":
      return isScripture
        ? .custom(FontRegistration.PostScriptName.scheherazadeNew, size: 16 * scale, relativeTo: .body)
        : .custom(FontRegistration.PostScriptName.amiri, size: 18 * scale, relativeTo: .body)

    default: // "la", "en", and any other Latin-script language
      return isScripture
        ? .custom(FontRegistration.PostScriptName.cardo, size: 19 * scale, relativeTo: .body)
        : .system(.body, design: .serif)
    }
  }
}

#Preview("Typography Sample") {
  FontRegistration.registerBundledFontsIfNeeded()

  return ScrollView {
    VStack(alignment: .leading, spacing: 20) {
      ForEach(LanguageCatalog.all) { language in
        VStack(alignment: .leading, spacing: 8) {
          Text(language.nativeName).font(.headline)

          Text(PrayerTranslations.get(languageCode: language.code, key: .aveMaria))
            .font(PrayerTypography.font(languageCode: language.code, isScripture: false))
            .environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)

          Text(MysteryTranslations.get(languageCode: language.code, imageKey: "joyful_01_annunciation").description)
            .font(PrayerTypography.font(languageCode: language.code, isScripture: true))
            .environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)
        }
        Divider()
      }
    }
    .padding()
  }
}
